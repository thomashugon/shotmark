import SwiftUI

/// Draws the image and its annotations. Used both on screen and for export.
struct AnnotatedImage: View {
    let image: CGImage
    let pixelated: CGImage?
    let size: CGSize
    let annotations: [Annotation]

    var body: some View {
        Canvas { context, _ in
            let imageRect = CGRect(origin: .zero, size: size)
            context.draw(Image(decorative: image, scale: 1), in: imageRect)
            for annotation in annotations {
                AnnotationRenderer.draw(annotation, in: &context, imageRect: imageRect, pixelated: pixelated)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

enum AnnotationRenderer {
    static func draw(_ a: Annotation, in context: inout GraphicsContext, imageRect: CGRect, pixelated: CGImage?) {
        let stroke = StrokeStyle(lineWidth: a.lineWidth, lineCap: .round, lineJoin: .round)
        switch a.tool {
        case .rectangle:
            context.stroke(Path(a.rect), with: .color(a.color), style: stroke)

        case .ellipse:
            context.stroke(Path(ellipseIn: a.rect), with: .color(a.color), style: stroke)

        case .line:
            context.stroke(line(from: a.start, to: a.end), with: .color(a.color), style: stroke)

        case .arrow:
            context.stroke(line(from: a.start, to: a.end), with: .color(a.color), style: stroke)
            context.fill(arrowHead(from: a.start, to: a.end, lineWidth: a.lineWidth), with: .color(a.color))

        case .freehand:
            var path = Path()
            path.addLines(a.points)
            context.stroke(path, with: .color(a.color), style: stroke)

        case .text:
            let fontSize = max(14, a.lineWidth * 6)
            let text = Text(a.text)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundColor(a.color)
            context.draw(text, at: a.start, anchor: .topLeading)

        case .highlight:
            var layer = context
            layer.blendMode = .multiply
            layer.fill(Path(a.rect), with: .color(a.color.opacity(0.45)))

        case .obfuscate:
            guard let pixelated else { return }
            context.drawLayer { layer in
                layer.clip(to: Path(a.rect))
                layer.draw(Image(decorative: pixelated, scale: 1), in: imageRect)
            }

        case .counter:
            let radius = max(12, a.lineWidth * 4)
            let circle = CGRect(x: a.start.x - radius, y: a.start.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: circle), with: .color(a.color))
            let label = Text("\(a.number)")
                .font(.system(size: radius * 1.1, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            context.draw(label, at: a.start, anchor: .center)

        case .crop:
            // Only drawn while dragging, as a preview of the crop area.
            context.stroke(Path(a.rect), with: .color(.white),
                           style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        }
    }

    private static func line(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }

    private static func arrowHead(from start: CGPoint, to end: CGPoint, lineWidth: CGFloat) -> Path {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let length = max(14, lineWidth * 4.5)
        let spread = CGFloat.pi / 7
        var path = Path()
        path.move(to: end)
        path.addLine(to: CGPoint(x: end.x - length * cos(angle - spread), y: end.y - length * sin(angle - spread)))
        path.addLine(to: CGPoint(x: end.x - length * cos(angle + spread), y: end.y - length * sin(angle + spread)))
        path.closeSubpath()
        return path
    }
}
