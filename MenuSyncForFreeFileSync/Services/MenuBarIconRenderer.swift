import AppKit

enum MenuBarIconRenderer {
    static func systemImage(
        named symbolName: String,
        accessibilityDescription: String
    ) -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: accessibilityDescription
        )?.withSymbolConfiguration(configuration)
            ?? NSImage(size: NSSize(width: 16, height: 16))
        image.isTemplate = true
        return image
    }

    static func customImage(
        from drawing: CustomIconDrawing,
        accessibilityDescription: String
    ) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            for stroke in drawing.strokes where !stroke.points.isEmpty {
                let path = NSBezierPath()
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.lineWidth = max(stroke.width * rect.width, 1)

                for (index, point) in stroke.points.enumerated() {
                    let target = NSPoint(
                        x: rect.minX + point.x * rect.width,
                        y: rect.maxY - point.y * rect.height
                    )
                    if index == 0 {
                        path.move(to: target)
                    } else {
                        path.line(to: target)
                    }
                }

                if stroke.points.count == 1, let point = stroke.points.first {
                    let radius = path.lineWidth / 2
                    let dotRect = NSRect(
                        x: rect.minX + point.x * rect.width - radius,
                        y: rect.maxY - point.y * rect.height - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    NSBezierPath(ovalIn: dotRect).fill()
                } else {
                    path.stroke()
                }
            }
            return true
        }
        image.accessibilityDescription = accessibilityDescription
        image.isTemplate = true
        return image
    }
}
