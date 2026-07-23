import Foundation

struct IconPoint: Codable, Equatable {
    let x: Double
    let y: Double
}

struct IconStroke: Codable, Equatable {
    let points: [IconPoint]
    let width: Double
}

struct CustomIconDrawing: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    var strokes: [IconStroke]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        strokes: [IconStroke] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.strokes = strokes
    }

    var isEmpty: Bool {
        strokes.allSatisfy { $0.points.isEmpty }
    }
}

