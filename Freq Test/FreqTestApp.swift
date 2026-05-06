import SwiftUI

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
    }
}

private struct RootView: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        if !settings.hasSeenWelcome {
            WelcomeView()
        } else if !settings.hasSeenInstructions {
            FirstTimeInstructionsView()
        } else {
            ContentView()
        }
    }
}
