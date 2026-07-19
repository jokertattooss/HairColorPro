import Foundation
import UIKit
import Vision
import CoreImage

// MARK: - Analysis result (mirrors the Windows core/color_analysis.py)

struct HairAnalysis {
    let dominantRGB: (Double, Double, Double)
    let dominantHex: String
    let level: Int
    let levelName: String
    let toneKey: String
    let toneName: String
    let grayPercent: Int
    let underlyingPigment: String
}

enum HairAnalyzer {

    static let levelNames = [1: "Black", 2: "Darkest Brown", 3: "Dark Brown",
                             4: "Medium Brown", 5: "Light Brown", 6: "Dark Blonde",
                             7: "Medium Blonde", 8: "Light Blonde",
                             9: "Very Light Blonde", 10: "Lightest Blonde"]

    static let underlying = [1: "Blue-black", 2: "Blue", 3: "Blue-red", 4: "Red",
                             5: "Red-orange", 6: "Orange", 7: "Orange-yellow",
                             8: "Yellow", 9: "Pale yellow", 10: "Palest yellow"]

    /// Full pipeline: segment person → take hair band → dominant color → level/tone.
    static func analyze(_ image: UIImage) -> HairAnalysis? {
        guard let cg = image.fixedOrientation().cgImage else { return nil }

        // 1) Person segmentation (Vision, on-device). Hair = top region of mask.
        let maskPixels = personMask(cg)

        // 2) Collect candidate hair pixels
        let pixels = hairPixels(cg, personMask: maskPixels)
        guard pixels.count > 300 else { return nil }

        // 3) Dominant color: simple k-means (k = 4)
        let dom = kmeansDominant(pixels, k: 4)

        // 4) LAB stats → level + tone
        let labs = pixels.map { Lab.from(r: $0.0, g: $0.1, b: $0.2) }
        let L = median(labs.map { $0.l })
        let A = median(labs.map { $0.a })
        let B = median(labs.map { $0.b })

        let level = levelFrom(L: L)
        let (toneKey, toneName) = toneFrom(a: A, b: B)

        // 5) gray %: bright + low-chroma pixels
        let grayCount = labs.filter { $0.l > 60 && abs($0.a) < 8 && abs($0.b) < 10 }.count
        let grayPct = Int(round(100.0 * Double(grayCount) / Double(labs.count)))

        let hex = String(format: "#%02X%02X%02X",
                         Int(dom.0), Int(dom.1), Int(dom.2))

        return HairAnalysis(dominantRGB: dom, dominantHex: hex,
                            level: level, levelName: levelNames[level] ?? "",
                            toneKey: toneKey, toneName: toneName,
                            grayPercent: grayPct,
                            underlyingPigment: underlying[level] ?? "")
    }

    // MARK: segmentation

    private static func personMask(_ cg: CGImage) -> CVPixelBuffer? {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        try? handler.perform([request])
        return request.results?.first?.pixelBuffer
    }

    /// Sample pixels likely to be hair: inside the person mask, in the upper
    /// part of the person's silhouette (head band). If no mask is available,
    /// fall back to the top-center third of the photo.
    private static func hairPixels(_ cg: CGImage,
                                   personMask: CVPixelBuffer?) -> [(Double, Double, Double)] {
        let target = 220
        let scale = Double(target) / Double(max(cg.width, cg.height))
        let w = max(1, Int(Double(cg.width) * scale))
        let h = max(1, Int(Double(cg.height) * scale))

        guard let ctx = CGContext(data: nil, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let _ = { ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h)); return ctx.data }()
        else { return [] }
        let buf = ctx.data!.bindMemory(to: UInt8.self, capacity: w * h * 4)

        // read mask (resized nearest-neighbor)
        var maskAt: ((Int, Int) -> Bool) = { _, y in y < h / 2 }   // fallback: top half
        var topOfPerson = 0
        if let mb = personMask {
            CVPixelBufferLockBaseAddress(mb, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(mb, .readOnly) }
            let mw = CVPixelBufferGetWidth(mb)
            let mh = CVPixelBufferGetHeight(mb)
            let rowBytes = CVPixelBufferGetBytesPerRow(mb)
            let base = CVPixelBufferGetBaseAddress(mb)!.bindMemory(
                to: UInt8.self, capacity: rowBytes * mh)
            func maskVal(_ x: Int, _ y: Int) -> UInt8 {
                let mx = min(mw - 1, x * mw / w)
                let my = min(mh - 1, y * mh / h)
                return base[my * rowBytes + mx]
            }
            // find the top of the person
            outer: for y in 0..<h {
                for x in 0..<w where maskVal(x, y) > 128 {
                    topOfPerson = y; break outer
                }
            }
            let headBandEnd = topOfPerson + max(6, h / 4)   // hair ≈ upper quarter
            maskAt = { x, y in
                y >= topOfPerson && y <= headBandEnd && maskVal(x, y) > 128
            }
        }

        var out: [(Double, Double, Double)] = []
        for y in 0..<h {
            for x in 0..<w where maskAt(x, y) {
                let i = (y * w + x) * 4
                let r = Double(buf[i]), g = Double(buf[i+1]), b = Double(buf[i+2])
                // skip skin-like pixels (simple rule) and near-white background
                let isSkin = r > 95 && g > 40 && b > 20 && r > g && g > b &&
                             (r - min(g, b)) > 15 && (r - b) < 110 && r < 250
                let isWhiteBg = r > 235 && g > 235 && b > 235
                if !isSkin && !isWhiteBg { out.append((r, g, b)) }
            }
        }
        return out
    }

    // MARK: math helpers

    private static func kmeansDominant(_ px: [(Double, Double, Double)],
                                       k: Int) -> (Double, Double, Double) {
        var samples = px
        if samples.count > 8000 { samples = (0..<8000).map { _ in px.randomElement()! } }
        var centers = (0..<k).map { _ in samples.randomElement()! }
        for _ in 0..<12 {
            var sums = Array(repeating: (0.0, 0.0, 0.0, 0.0), count: k)
            for p in samples {
                var bi = 0; var bd = Double.greatestFiniteMagnitude
                for (i, c) in centers.enumerated() {
                    let d = pow(p.0-c.0,2) + pow(p.1-c.1,2) + pow(p.2-c.2,2)
                    if d < bd { bd = d; bi = i }
                }
                sums[bi].0 += p.0; sums[bi].1 += p.1
                sums[bi].2 += p.2; sums[bi].3 += 1
            }
            for i in 0..<k where sums[i].3 > 0 {
                centers[i] = (sums[i].0/sums[i].3, sums[i].1/sums[i].3, sums[i].2/sums[i].3)
            }
        }
        // biggest cluster
        var counts = Array(repeating: 0, count: k)
        for p in samples {
            var bi = 0; var bd = Double.greatestFiniteMagnitude
            for (i, c) in centers.enumerated() {
                let d = pow(p.0-c.0,2) + pow(p.1-c.1,2) + pow(p.2-c.2,2)
                if d < bd { bd = d; bi = i }
            }
            counts[bi] += 1
        }
        return centers[counts.firstIndex(of: counts.max()!)!]
    }

    private static func median(_ v: [Double]) -> Double {
        let s = v.sorted(); return s.isEmpty ? 0 : s[s.count / 2]
    }

    private static func levelFrom(L: Double) -> Int {
        let bounds: [Double] = [8, 14, 20, 27, 34, 42, 51, 61, 72]
        for (i, b) in bounds.enumerated() where L <= b { return i + 1 }
        return 10
    }

    private static func toneFrom(a: Double, b: Double) -> (String, String) {
        if b < 8 && a < 8 { return ("ash", "Ash (cool)") }
        if a >= 18 && b >= 18 { return ("copper", "Copper (warm orange)") }
        if a >= 18 { return ("red", "Red") }
        if a >= 12 && b >= 10 { return ("mahogany", "Mahogany (red-violet warm)") }
        if b >= 16 { return ("gold", "Gold (warm)") }
        return ("neutral", "Neutral")
    }
}

extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let img = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return img
    }
}
