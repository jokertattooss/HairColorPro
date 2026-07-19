import SwiftUI
import PhotosUI

// Design language matches the approved desktop mockup:
// dark slate background, teal pill buttons, ANALYSIS RESULT panel with
// DETECTED COLOR SWATCH bar and the five labeled fields, full chart list.

let teal = Color(red: 0.18, green: 0.55, blue: 0.55)
let panelDark = Color(red: 0.11, green: 0.16, blue: 0.21)

struct ContentView: View {
    @State private var image: UIImage?
    @State private var analysis: HairAnalysis?
    @State private var match: PaletteMatch?
    @State private var formulation: Formulation?
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showChart = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    previewPanel
                    buttonBar
                    if let a = analysis, let m = match, let f = formulation {
                        resultPanel(a: a, m: m, f: f)
                    }
                }
                .padding(14)
            }
            .background(
                LinearGradient(colors: [Color(red: 0.29, green: 0.33, blue: 0.38),
                                        Color(red: 0.22, green: 0.26, blue: 0.30)],
                               startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea())
            .navigationTitle("HairColorPro")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCamera) {
                CameraPicker { img in self.setImage(img) }
            }
            .sheet(isPresented: $showChart) {
                ChartListView(highlightID: match?.best.id)
            }
            .onChange(of: photoItem) { _ in
                Task {
                    if let data = try? await photoItem?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) { setImage(img) }
                }
            }
            .alert("Analysis", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    // MARK: pieces

    var previewPanel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(panelDark)
            if let img = image {
                Image(uiImage: img)
                    .resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(8)
            } else {
                VStack(spacing: 10) {
                    Text("🎞️").font(.system(size: 64))
                    Text("WELCOME TO HAIRCOLORPRO")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(.white)
                    Text("Unlock the precise formula for your perfect color.\nTake or upload a photo to begin.")
                        .multilineTextAlignment(.center)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.65))
                    Text("📁   📷   ⚗️").font(.title2).foregroundColor(teal)
                }.padding(24)
            }
        }
        .frame(minHeight: 300)
    }

    var buttonBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    pill("📁 Upload Picture")
                }
                Button { showCamera = true } label: { pill("📷 Camera") }
            }
            HStack(spacing: 10) {
                Button { analyze() } label: { pill("🎨 Analyze Hair Color") }
                    .disabled(image == nil)
                    .opacity(image == nil ? 0.5 : 1)
                Button { showChart = true } label: { pill("🗂 Color Chart") }
            }
        }
    }

    func pill(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Capsule().fill(teal))
    }

    func resultPanel(a: HairAnalysis, m: PaletteMatch, f: Formulation) -> some View {
        VStack(spacing: 10) {
            Text("ANALYSIS RESULT")
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 9).fill(teal))

            Text("\(m.best.code). \(m.best.name_fr)  /  \(m.best.name_en)")
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(a.level >= 6 ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(13)
                .background(RoundedRectangle(cornerRadius: 9)
                    .fill(Color(UIColor(hex: a.dominantHex))))

            VStack(alignment: .leading, spacing: 10) {
                field("PRIMARY COLOR TONES", f.primaryTones)
                field("TONER ADDITIONS", f.tonerAdditions)
                field("MIXING RATIO", f.mixingRatio)
                field("APPLICATION GUIDE (HOW TO)", f.applicationGuide)
                field("NOTES", f.notes)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(.white))
        }
    }

    func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12, weight: .heavy))
                .foregroundColor(.black)
            Text(value).font(.system(size: 13)).foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(9)
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.gray.opacity(0.7), lineWidth: 1.4))
        }
    }

    // MARK: actions

    func setImage(_ img: UIImage) {
        image = img
        analysis = nil; match = nil; formulation = nil
    }

    func analyze() {
        guard let img = image else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let a = HairAnalyzer.analyze(img)
            DispatchQueue.main.async {
                guard let a = a, let m = Palette.match(rgb: a.dominantRGB) else {
                    errorMessage = "Hair not detected. Use a clear photo with visible hair in good, natural light."
                    return
                }
                analysis = a
                match = m
                formulation = FormulationEngine.build(analysis: a, match: m)
            }
        }
    }
}

// MARK: - Camera picker

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera)
            ? .camera : .photoLibrary
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ c: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coord { Coord(self) }

    class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ p: CameraPicker) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onImage(img) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Full chart list (from the reference picture), match highlighted

struct ChartListView: View {
    let highlightID: String?

    var body: some View {
        NavigationStack {
            List {
                Section("BASE NATURALS & BLONDES (1-12)") {
                    ForEach(Palette.shades.filter { $0.group == "base" }) { row($0) }
                }
                Section("REDS, COPPERS & SPECIALTY SHADES (13+)") {
                    ForEach(Palette.shades.filter { $0.group != "base" }) { row($0) }
                }
            }
            .navigationTitle("Color Chart")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    func row(_ s: Shade) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(s.uiColor))
                .frame(width: 52, height: 26)
                .overlay(RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.gray.opacity(0.5)))
            VStack(alignment: .leading, spacing: 1) {
                Text("\(s.code). \(s.name_fr)")
                    .font(.system(size: 14, weight: .semibold))
                Text(s.name_en).font(.system(size: 12)).foregroundColor(.secondary)
            }
            Spacer()
            if s.id == highlightID {
                Text("MATCH").font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(teal))
            }
        }
        .listRowBackground(s.id == highlightID ? teal.opacity(0.22) : nil)
    }
}
