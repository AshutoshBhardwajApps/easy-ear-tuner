import Foundation
import SwiftData

enum Ear: String, CaseIterable, Codable {
    case left  = "Left"
    case right = "Right"
    case both  = "Both"
}

enum ReliabilityScore: String, Codable {
    case high   = "High Confidence"
    case medium = "Some Uncertainty"
    case low    = "Questionable"
}

struct TapEvent: Codable {
    let frequency: Double
    let toneWasPlaying: Bool
    let timestamp: Date
}

@Model
final class HearingResult {
    var date: Date
    var ear: String
    var maxFrequency: Double
    var falseTapCount: Int
    var reliability: String
    var tapLogData: Data

    init(date: Date, ear: Ear, maxFrequency: Double,
         falseTapCount: Int, reliability: ReliabilityScore, tapLog: [TapEvent]) {
        self.date         = date
        self.ear          = ear.rawValue
        self.maxFrequency = maxFrequency
        self.falseTapCount = falseTapCount
        self.reliability  = reliability.rawValue
        self.tapLogData   = (try? JSONEncoder().encode(tapLog)) ?? Data()
    }

    var tapLog: [TapEvent] {
        (try? JSONDecoder().decode([TapEvent].self, from: tapLogData)) ?? []
    }

    var earEnum: Ear              { Ear(rawValue: ear)                       ?? .both }
    var reliabilityEnum: ReliabilityScore { ReliabilityScore(rawValue: reliability) ?? .low  }

    var ageComparison: String {
        switch maxFrequency {
        case 18_000...:          return "You hear like a teenager!"
        case 16_000..<18_000:   return "Excellent — typical for your 20s"
        case 14_000..<16_000:   return "Good — typical for your 30s"
        case 12_000..<14_000:   return "Normal — typical for your 40s"
        case 10_000..<12_000:   return "Common for your 50s"
        case  8_000..<10_000:   return "Common for your 60s"
        default:                return "Consider an audiologist checkup"
        }
    }
}
