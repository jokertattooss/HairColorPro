import Foundation
import UIKit

// MARK: - Palette (same chart as the Windows version: data from the
// "Hair Color Palette Reference Chart" picture)

struct Shade: Codable, Identifiable {
    let id: String
    let code: String
    let name_fr: String
    let name_en: String
    let hex: String
    let level: Int
    let tone: String
    let group: String
    let is_mixer: Bool?

    var uiColor: UIColor { UIColor(hex: hex) }
}

struct PaletteFile: Codable {
    let chart_name: String
    let shades: [Shade]
}

struct PaletteMatch {
    let best: Shade
    let distance: Double
    let alternatives: [Shade]
}

enum Palette {
    static let shades: [Shade] = {
        guard let url = Bundle.main.url(forResource: "palette_chart",
                                        withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(PaletteFile.self, from: data)
        else { return [] }
        return file.shades
    }()

    static func match(rgb: (Double, Double, Double), topN: Int = 3) -> PaletteMatch? {
        let target = Lab.from(r: rgb.0, g: rgb.1, b: rgb.2)
        let candidates = shades.filter { $0.is_mixer != true }
        let scored = candidates.map { shade -> (Double, Shade) in
            let c = shade.uiColor.rgb255
            let lab = Lab.from(r: c.0, g: c.1, b: c.2)
            let dL = (target.l - lab.l) * 1.2      // level (depth) weighted most
            let dA = target.a - lab.a
            let dB = target.b - lab.b
            return (sqrt(dL*dL + dA*dA + dB*dB), shade)
        }.sorted { $0.0 < $1.0 }

        guard let first = scored.first else { return nil }
        return PaletteMatch(best: first.1,
                            distance: first.0,
                            alternatives: scored.dropFirst().prefix(topN).map { $0.1 })
    }
}

// MARK: - CIE-LAB conversion

struct Lab { let l, a, b: Double

    static func from(r: Double, g: Double, b: Double) -> Lab {
        func inv(_ c: Double) -> Double {
            let s = c / 255.0
            return s > 0.04045 ? pow((s + 0.055) / 1.055, 2.4) : s / 12.92
        }
        let R = inv(r), G = inv(g), B = inv(b)
        // sRGB D65
        var x = (R * 0.4124 + G * 0.3576 + B * 0.1805) / 0.95047
        var y = (R * 0.2126 + G * 0.7152 + B * 0.0722)
        var z = (R * 0.0193 + G * 0.1192 + B * 0.9505) / 1.08883
        func f(_ t: Double) -> Double {
            t > 0.008856 ? pow(t, 1.0/3.0) : (7.787 * t) + 16.0/116.0
        }
        x = f(x); y = f(y); z = f(z)
        return Lab(l: 116.0 * y - 16.0, a: 500.0 * (x - y), b: 200.0 * (y - z))
    }
}

extension UIColor {
    convenience init(hex: String) {
        var h = hex.trimmingCharacters(in: .alphanumerics.inverted)
        if h.count == 6 { h = "FF" + h }
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        self.init(red: CGFloat((int >> 16) & 0xFF) / 255,
                  green: CGFloat((int >> 8) & 0xFF) / 255,
                  blue: CGFloat(int & 0xFF) / 255,
                  alpha: CGFloat((int >> 24) & 0xFF) / 255)
    }
    var rgb255: (Double, Double, Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r * 255), Double(g * 255), Double(b * 255))
    }
}
