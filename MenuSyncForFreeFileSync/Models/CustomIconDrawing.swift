import Foundation

struct IconPoint: Codable, Equatable {
    let x: Double
    let y: Double
}

enum IconStrokeColor: String, Codable, CaseIterable, Identifiable {
    case white
    case mint
    case butter
    case blush
    case peach
    case sky
    case charcoal

    var id: Self { self }

    var displayName: String {
        switch self {
        case .white: "White"
        case .mint: "Mint"
        case .butter: "Butter"
        case .blush: "Blush"
        case .peach: "Peach"
        case .sky: "Sky"
        case .charcoal: "Charcoal"
        }
    }

    var components: (red: Double, green: Double, blue: Double) {
        switch self {
        case .white: (1.00, 1.00, 1.00)
        case .mint: (0.56, 0.89, 0.71)
        case .butter: (1.00, 0.85, 0.47)
        case .blush: (1.00, 0.62, 0.68)
        case .peach: (1.00, 0.69, 0.47)
        case .sky: (0.56, 0.80, 1.00)
        case .charcoal: (0.17, 0.18, 0.20)
        }
    }
}

struct IconStroke: Codable, Equatable {
    let points: [IconPoint]
    let width: Double
    let color: IconStrokeColor

    init(
        points: [IconPoint],
        width: Double,
        color: IconStrokeColor = .white
    ) {
        self.points = points
        self.width = width
        self.color = color
    }

    private enum CodingKeys: String, CodingKey {
        case points
        case width
        case color
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        points = try container.decode([IconPoint].self, forKey: .points)
        width = try container.decode(Double.self, forKey: .width)
        color = try container.decodeIfPresent(
            IconStrokeColor.self,
            forKey: .color
        ) ?? .white
    }
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
