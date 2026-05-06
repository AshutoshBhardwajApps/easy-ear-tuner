import SwiftUI
import SwiftData

@main
struct FreqTestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var settings        = SettingsStore.shared
    @StateObject private var purchaseManager = PurchaseManager.shared

    var body: some Scene {
        WindowGroup {
            NavigationView {
                RootView()
            }
            .environmentObject(settings)
            .environmentObject(purchaseManager)
            .task {
                await purchaseManager.loadProducts()
                await purchaseManager.restorePurchases()
            }
        }
        .modelContainer(for: HearingResult.self)
    }
}

private struct RootView: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        Group {
            if !settings.hasSeenWelcome {
                WelcomeView()
            } else if !settings.hasSeenInstructions {
                FirstTimeInstructionsView()
            } else {
                ContentView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: settings.hasSeenWelcome)
        .animation(.easeInOut(duration: 0.35), value: settings.hasSeenInstructions)
    }
}
