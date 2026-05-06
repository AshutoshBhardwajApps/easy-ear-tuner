import Foundation
import SwiftUI

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private static let p = Constants.userDefaultsPrefix

    @Published var hasRemovedAds: Bool      { didSet { save() } }

    // App-specific
    @Published var hasSeenWelcome: Bool     { didSet { save() } }
    @Published var hasSeenInstructions: Bool { didSet { save() } }

    private init() {
        let d = UserDefaults.standard
        hasRemovedAds       = d.bool(forKey: Self.p + "removeAds")
        hasSeenWelcome      = d.bool(forKey: Self.p + "hasSeenWelcome")
        hasSeenInstructions = d.bool(forKey: Self.p + "hasSeenInstructions")
    }

    func markRemoveAdsPurchased() { hasRemovedAds = true }

    private func save() {
        let d = UserDefaults.standard
        d.set(hasRemovedAds,       forKey: Self.p + "removeAds")
        d.set(hasSeenWelcome,      forKey: Self.p + "hasSeenWelcome")
        d.set(hasSeenInstructions, forKey: Self.p + "hasSeenInstructions")
    }
}
