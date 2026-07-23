import SwiftUI

struct IconDrawingCanvas: View {
    @Binding var drawing: CustomIconDrawing
    @Binding var lineWidth: Double
    @State private var activePoints: [IconPoint] = []

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                drawGrid(context: &context, size: size)
                for stroke in drawing.strokes {
                    draw(stroke, context: &context, size: size)
                }
                if !activePoints.isEmpty {
                    draw(
                        IconStroke(points: activePoints, width: lineWidth),
                        context: &context,
                        size: size
                    )
                }
            }
            .background(Color.black.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.45))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        activePoints.append(
                            normalizedPoint(value.location, in: geometry.size)
                        )
                    }
                    .onEnded { _ in
                        guard !activePoints.isEmpty else { return }
                        drawing.strokes.append(
                            IconStroke(points: activePoints, width: lineWidth)
                        )
                        activePoints.removeAll(keepingCapacity: true)
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func normalizedPoint(_ point: CGPoint, in size: CGSize) -> IconPoint {
        IconPoint(
            x: min(max(point.x / max(size.width, 1), 0), 1),
            y: min(max(point.y / max(size.height, 1), 0), 1)
        )
    }

    private func draw(
        _ stroke: IconStroke,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        guard let first = stroke.points.first else { return }
        var path = Path()
        path.move(to: position(first, in: size))
        for point in stroke.points.dropFirst() {
            path.addLine(to: position(point, in: size))
        }

        context.stroke(
            path,
            with: .color(.white),
            style: StrokeStyle(
                lineWidth: max(stroke.width * size.width, 1),
                lineCap: .round,
                lineJoin: .round
            )
        )

        if stroke.points.count == 1 {
            let radius = max(stroke.width * size.width, 1) / 2
            let center = position(first, in: size)
            context.fill(
                Path(
                    ellipseIn: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                ),
                with: .color(.white)
            )
        }
    }

    private func drawGrid(context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        for fraction in [0.25, 0.5, 0.75] {
            path.move(to: CGPoint(x: size.width * fraction, y: 0))
            path.addLine(to: CGPoint(x: size.width * fraction, y: size.height))
            path.move(to: CGPoint(x: 0, y: size.height * fraction))
            path.addLine(to: CGPoint(x: size.width, y: size.height * fraction))
        }
        context.stroke(path, with: .color(.white.opacity(0.08)), lineWidth: 1)
    }

    private func position(_ point: IconPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }
}

struct DrawingThumbnail: View {
    let drawing: CustomIconDrawing

    var body: some View {
        Canvas { context, size in
            for stroke in drawing.strokes where !stroke.points.isEmpty {
                var path = Path()
                if let first = stroke.points.first {
                    path.move(to: position(first, in: size))
                }
                for point in stroke.points.dropFirst() {
                    path.addLine(to: position(point, in: size))
                }
                context.stroke(
                    path,
                    with: .color(.primary),
                    style: StrokeStyle(
                        lineWidth: max(stroke.width * size.width, 1),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
        }
        .frame(width: 28, height: 28)
    }

    private func position(_ point: IconPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }
}
