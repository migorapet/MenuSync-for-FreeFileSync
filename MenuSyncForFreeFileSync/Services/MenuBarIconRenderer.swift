import AppKit

enum MenuBarIconRenderer {
    static let animationFrameCount = 24

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
            for stroke in drawing.strokes where !stroke.points.isEmpty {
                let components = stroke.color.components
                let color = NSColor(
                    red: components.red,
                    green: components.green,
                    blue: components.blue,
                    alpha: 1
                )
                color.setStroke()
                color.setFill()

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
        image.isTemplate = false
        return image
    }

    static func animationFrames(
        from source: NSImage,
        configuration: IconAnimationConfiguration
    ) -> [NSImage] {
        guard configuration.effect != .none,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        else {
            return [source]
        }

        let frames = (0..<animationFrameCount).map { index in
            transformedImage(
                from: source,
                effect: configuration.effect,
                progress: Double(index) / Double(animationFrameCount)
            )
        }
        return frames
    }

    static func frame(
        at date: Date,
        animationStartedAt: Date,
        from frames: [NSImage],
        animationDurationSeconds: Int
    ) -> NSImage {
        guard frames.count > 1 else {
            return frames.first ?? NSImage(size: NSSize(width: 18, height: 18))
        }
        let elapsed = date.timeIntervalSince(animationStartedAt)
        let duration = Double(min(max(animationDurationSeconds, 1), 5))
        guard elapsed >= 0, elapsed < duration else {
            return frames[0]
        }
        let progress = elapsed
            .truncatingRemainder(dividingBy: 1)
        let index = min(Int(progress * Double(frames.count)), frames.count - 1)
        return frames[index]
    }

    private static func transformedImage(
        from source: NSImage,
        effect: IconAnimationEffect,
        progress: Double
    ) -> NSImage {
        var rotationDegrees = 0.0
        var translationX = 0.0
        var translationY = 0.0
        var opacity = 1.0
        var usesBottomAnchor = false

        switch effect {
        case .none:
            break
        case .spin:
            rotationDegrees = -cubicBezierEaseInOut(progress) * 360
        case .shake:
            let offset = shakeOffset(at: progress)
            translationX = offset.x
            translationY = offset.y
        case .sway:
            rotationDegrees = swayPosition(at: progress) * 4
            usesBottomAnchor = true
        case .breathe:
            let pulse = progress < 0.5
                ? cubicBezierEaseInOut(progress * 2)
                : cubicBezierEaseInOut((1 - progress) * 2)
            opacity = 1 - pulse * 0.35
        }

        let size = source.size
        let pixelScale = 4
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: max(Int(size.width) * pixelScale, 1),
            pixelsHigh: max(Int(size.height) * pixelScale, 1),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: representation) else {
            return source
        }
        representation.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(
            x: CGFloat(pixelScale),
            y: CGFloat(pixelScale)
        )
        let rect = NSRect(origin: .zero, size: size)
        let interpolation: NSImageInterpolation = switch effect {
        case .shake: .none
        case .sway: .medium
        default: .high
        }
        context.shouldAntialias = true
        context.imageInterpolation = interpolation
        context.compositingOperation = .copy
        NSColor.clear.setFill()
        rect.fill()
        context.compositingOperation = .sourceOver

        let transform = NSAffineTransform()
        let anchorY = usesBottomAnchor ? rect.minY + 1 : rect.midY
        transform.translateX(
            by: rect.midX + translationX,
            yBy: anchorY + translationY
        )
        transform.rotate(byDegrees: rotationDegrees)
        transform.translateX(by: -rect.midX, yBy: -anchorY)
        transform.concat()

        source.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: opacity,
            respectFlipped: true,
            hints: [.interpolation: interpolation]
        )
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(representation)
        image.accessibilityDescription = source.accessibilityDescription
        image.isTemplate = source.isTemplate
        return image
    }

    private static func shakeOffset(at progress: Double) -> NSPoint {
        // A short pager/phone-like vibration surrounded by stillness.
        // Half-point offsets align to whole pixels in the 4x frame while
        // keeping the short vibration crisp and visually compact.
        let keyframes: [(time: Double, x: CGFloat, y: CGFloat)] = [
            (0.00,  0,  0),
            (0.28,  0,  0),
            (0.32, -0.5,  0),
            (0.36,  0.5,  0.5),
            (0.40, -0.5, -0.5),
            (0.44,  0.5,  0),
            (0.48, -0.5,  0.5),
            (0.52,  0.5, -0.5),
            (0.56, -0.5,  0),
            (0.60,  0.5,  0),
            (0.64,  0,  0),
            (1.00,  0,  0)
        ]
        let clampedProgress = min(max(progress, 0), 1)
        guard let nextIndex = keyframes.indices.dropFirst().first(
            where: { clampedProgress < keyframes[$0].time }
        ) else {
            return .zero
        }
        let previous = keyframes[nextIndex - 1]
        return NSPoint(x: previous.x, y: previous.y)
    }

    private static func swayPosition(at progress: Double) -> Double {
        let keyframes = [0.0, 1.0, 0.0, -1.0, 0.0]
        let position = min(max(progress, 0), 0.999_999) * 4
        let segment = min(Int(position), 3)
        let localProgress = position - Double(segment)
        let easedProgress = cubicBezierEaseInOut(localProgress)
        return keyframes[segment]
            + (keyframes[segment + 1] - keyframes[segment]) * easedProgress
    }

    private static func cubicBezierEaseInOut(_ progress: Double) -> Double {
        let targetX = min(max(progress, 0), 1)
        let x1 = 0.42
        let x2 = 0.58
        var parameter = targetX

        for _ in 0..<6 {
            let currentX = cubicBezierValue(
                parameter,
                control1: x1,
                control2: x2
            )
            let derivative = cubicBezierDerivative(
                parameter,
                control1: x1,
                control2: x2
            )
            guard abs(derivative) > 0.000_001 else { break }
            parameter = min(
                max(parameter - (currentX - targetX) / derivative, 0),
                1
            )
        }

        return cubicBezierValue(
            parameter,
            control1: 0,
            control2: 1
        )
    }

    private static func cubicBezierValue(
        _ parameter: Double,
        control1: Double,
        control2: Double
    ) -> Double {
        let inverse = 1 - parameter
        return 3 * inverse * inverse * parameter * control1
            + 3 * inverse * parameter * parameter * control2
            + parameter * parameter * parameter
    }

    private static func cubicBezierDerivative(
        _ parameter: Double,
        control1: Double,
        control2: Double
    ) -> Double {
        let inverse = 1 - parameter
        return 3 * inverse * inverse * control1
            + 6 * inverse * parameter * (control2 - control1)
            + 3 * parameter * parameter * (1 - control2)
    }
}
