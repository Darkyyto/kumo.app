import Foundation

enum FocusMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case flight
    case orbit
    case bloom
    case tide

    var id: String { rawValue }

    /// The scenes that are polished enough to offer. Bloom and Tide stay readable in old sessions but aren't picked any more.
    static let offered: [FocusMode] = [.flight, .orbit]

    var title: String {
        switch self {
        case .flight: "Flight"
        case .orbit: "Orbit"
        case .bloom: "Bloom"
        case .tide: "Tide"
        }
    }

    var tagline: String {
        switch self {
        case .flight: "Cross the map, one task at a time."
        case .orbit: "Deep work in a long, quiet loop."
        case .bloom: "Grow something while you study."
        case .tide: "Let the water rise as you read."
        }
    }

    var symbol: String {
        switch self {
        case .flight: "airplane"
        case .orbit: "moon.stars.fill"
        case .bloom: "leaf.fill"
        case .tide: "water.waves"
        }
    }

    var suggestedMinutes: Int {
        switch self {
        case .flight: 45
        case .orbit: 90
        case .bloom: 25
        case .tide: 50
        }
    }
}
