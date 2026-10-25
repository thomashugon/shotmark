import SwiftUI

struct EditorView: View {
    @ObservedObject var model: EditorModel

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            ScrollView([.horizontal, .vertical]) {
                AnnotationCanvas(model: model)
                    .shadow(radius: 4)
                    .padding(20)
            }
            .background(Color(nsColor: .underPageBackgroundColor))
            .overlay(alignment: .bottom) {
                if let message = model.statusMessage {
                    Text(message)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 12)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: model.statusMessage)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            ForEach(Tool.allCases) { tool in
                Button {
                    model.tool = tool
                } label: {
                    Image(systemName: tool.symbol)
                        .frame(width: 26, height: 22)
                }
                .buttonStyle(.borderless)
                .background(model.tool == tool ? Color.accentColor.opacity(0.25) : .clear,
                            in: RoundedRectangle(cornerRadius: 5))
                .help("\(tool.label) (\(String(tool.shortcut.character).uppercased()))")
                .keyboardShortcut(tool.shortcut, modifiers: [])
            }

            Divider().frame(height: 20).padding(.horizontal, 6)

            ColorPicker("Couleur", selection: $model.color)
                .labelsHidden()
            Picker("Épaisseur", selection: $model.lineWidth) {
                ForEach([1, 2, 3, 5, 8, 12] as [CGFloat], id: \.self) { width in
                    Text("\(Int(width)) px").tag(width)
                }
            }
            .labelsHidden()
            .frame(width: 80)

            Divider().frame(height: 20).padding(.horizontal, 6)

            Button(action: model.undo) { Image(systemName: "arrow.uturn.backward") }
                .disabled(!model.canUndo)
                .keyboardShortcut("z")
                .help("Annuler (⌘Z)")
            Button(action: model.redo) { Image(systemName: "arrow.uturn.forward") }
                .disabled(!model.canRedo)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .help("Rétablir (⇧⌘Z)")

            Spacer()

            Button(action: model.copyToClipboard) { Label("Copier", systemImage: "doc.on.doc") }
                .keyboardShortcut("c")
            Button(action: model.quickSave) { Label("Enregistrer", systemImage: "square.and.arrow.down") }
                .keyboardShortcut("s")
            Button(action: model.saveAs) { Label("Enregistrer sous…", systemImage: "folder") }
                .keyboardShortcut("s", modifiers: [.command, .shift])
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

/// The interactive drawing surface.
private struct AnnotationCanvas: View {
    @ObservedObject var model: EditorModel
    @State private var draft: Annotation?
    @State private var pendingTextPoint: CGPoint?
    @State private var textInput = ""

    var body: some View {
        AnnotatedImage(image: model.image,
                       pixelated: model.pixelated,
                       size: model.size,
                       annotations: model.annotations + (draft.map { [$0] } ?? []))
            .contentShape(Rectangle())
            .gesture(drawGesture)
            .onHover { inside in
                if inside { NSCursor.crosshair.push() } else { NSCursor.pop() }
            }
            .alert("Ajouter du texte", isPresented: textAlertBinding) {
                TextField("Texte", text: $textInput)
                Button("Ajouter") { commitText() }
                Button("Annuler", role: .cancel) { pendingTextPoint = nil }
            }
    }

    private var textAlertBinding: Binding<Bool> {
        Binding(get: { pendingTextPoint != nil },
                set: { if !$0 { pendingTextPoint = nil } })
    }

    private var drawGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if draft == nil {
                    draft = Annotation(tool: model.tool, start: value.startLocation, end: value.location,
                                       points: [value.startLocation], color: model.color,
                                       lineWidth: model.lineWidth)
                }
                draft?.end = value.location
                if model.tool == .freehand { draft?.points.append(value.location) }
            }
            .onEnded { value in
                defer { draft = nil }
                guard var annotation = draft else { return }
                switch annotation.tool {
                case .text:
                    textInput = ""
                    pendingTextPoint = value.location
                case .counter:
                    annotation.start = value.location
                    annotation.number = model.nextCounter
                    model.add(annotation)
                case .crop:
                    model.crop(to: annotation.rect)
                case .freehand:
                    if annotation.points.count > 1 { model.add(annotation) }
                default:
                    let rect = annotation.rect
                    if rect.width > 2 || rect.height > 2 { model.add(annotation) }
                }
            }
    }

    private func commitText() {
        guard let point = pendingTextPoint, !textInput.isEmpty else { return }
        model.add(Annotation(tool: .text, start: point, end: point, color: model.color,
                             lineWidth: model.lineWidth, text: textInput))
        pendingTextPoint = nil
    }
}
