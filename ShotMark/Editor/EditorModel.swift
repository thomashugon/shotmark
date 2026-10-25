import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

@MainActor
final class EditorModel: ObservableObject {
    private struct State {
        var image: CGImage
        var annotations: [Annotation]
    }

    @Published private(set) var image: CGImage
    @Published private(set) var pixelated: CGImage?
    @Published var annotations: [Annotation] = []
    @Published var tool: Tool = .arrow
    @Published var color: Color = .red
    @Published var lineWidth: CGFloat = 3
    @Published var statusMessage: String?
    @Published var recognizedText: String?
    @Published private(set) var isRecognizingText = false

    /// Pixels per point of the captured image (2 on Retina displays).
    let scale: CGFloat

    private var undoStack: [State] = []
    private var redoStack: [State] = []

    init(image: CGImage, scale: CGFloat) {
        self.image = image
        self.scale = scale
        pixelated = Self.pixelate(image, blockSize: 10 * scale)
    }

    var size: CGSize {
        CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var nextCounter: Int { (annotations.filter { $0.tool == .counter }.map(\.number).max() ?? 0) + 1 }

    // MARK: Editing

    func add(_ annotation: Annotation) {
        pushUndo()
        annotations.append(annotation)
    }

    func crop(to rect: CGRect) {
        let bounds = CGRect(origin: .zero, size: size)
        let clipped = rect.intersection(bounds).integral
        guard clipped.width >= 4, clipped.height >= 4 else { return }
        let pixels = CGRect(x: clipped.minX * scale, y: clipped.minY * scale,
                            width: clipped.width * scale, height: clipped.height * scale)
        guard let cropped = image.cropping(to: pixels) else { return }
        pushUndo()
        annotations = annotations.map { $0.offsetBy(dx: -clipped.minX, dy: -clipped.minY) }
        setImage(cropped)
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(State(image: image, annotations: annotations))
        restore(previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(State(image: image, annotations: annotations))
        restore(next)
    }

    // MARK: Output

    func renderedImage() -> CGImage? {
        let renderer = ImageRenderer(content: AnnotatedImage(image: image, pixelated: pixelated,
                                                             size: size, annotations: annotations))
        renderer.scale = scale
        return renderer.cgImage
    }

    func copyToClipboard() {
        guard let output = renderedImage() else { return }
        ImageExporter.copyToClipboard(output)
        flash("Copié dans le presse-papiers")
    }

    func quickSave() {
        guard let output = renderedImage() else { return }
        do {
            let url = try ImageExporter.quickSave(output)
            flash("Enregistré : \(url.lastPathComponent)")
        } catch {
            flash("Erreur : \(error.localizedDescription)")
        }
    }

    func saveAs() {
        guard let output = renderedImage() else { return }
        if let url = ImageExporter.saveWithPanel(output) {
            flash("Enregistré : \(url.lastPathComponent)")
        }
    }

    /// OCR on the original capture (annotations excluded).
    func recognizeText() {
        guard !isRecognizingText else { return }
        isRecognizingText = true
        Task {
            defer { isRecognizingText = false }
            do {
                let text = try await TextRecognizer.recognizeText(in: image)
                if text.isEmpty {
                    flash("Aucun texte détecté")
                } else {
                    recognizedText = text
                }
            } catch {
                flash("Erreur OCR : \(error.localizedDescription)")
            }
        }
    }

    // MARK: Private

    private func pushUndo() {
        undoStack.append(State(image: image, annotations: annotations))
        redoStack.removeAll()
    }

    private func restore(_ state: State) {
        annotations = state.annotations
        if state.image !== image { setImage(state.image) }
    }

    private func setImage(_ newImage: CGImage) {
        image = newImage
        pixelated = Self.pixelate(newImage, blockSize: 10 * scale)
    }

    private func flash(_ message: String) {
        statusMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if statusMessage == message { statusMessage = nil }
        }
    }

    private static func pixelate(_ image: CGImage, blockSize: CGFloat) -> CGImage? {
        let input = CIImage(cgImage: image)
        let filter = CIFilter.pixellate()
        filter.inputImage = input.clampedToExtent()
        filter.scale = Float(blockSize)
        filter.center = .zero
        guard let output = filter.outputImage?.cropped(to: input.extent) else { return nil }
        return CIContext().createCGImage(output, from: input.extent)
    }
}
