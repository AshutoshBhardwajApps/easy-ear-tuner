import SwiftUI
#if DEBUG
import GoogleMobileAds
#endif

/// Ported from CoopHockey's SettingsView: purchases, plus the DEBUG tools for
/// consent and ads that CoopHockey relies on when testing.
struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var purchaseManager: PurchaseManager

    var body: some View {
        Form {
            Section("ADS") {
                if settings.hasRemovedAds {
                    Label("Ads removed", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Button {
                        Task { await purchaseManager.buyRemoveAds() }
                    } label: {
                        HStack {
                            if purchaseManager.isLoading { ProgressView() }
                            else { Text("Remove Ads") }
                        }
                    }
                    .disabled(purchaseManager.isLoading)

                    Button("Restore Purchases") {
                        Task { await purchaseManager.restorePurchases() }
                    }
                    .disabled(purchaseManager.isLoading)

                    if let msg = purchaseManager.errorMessage {
                        Text(msg).font(.footnote).foregroundColor(.red)
                    }
                }
            }

            #if DEBUG
            Section("DEBUG") {
                Button("Reset consent (UMP form shows next launch)") {
                    ConsentManager.shared.reset()
                }

                Button("Ad Inspector") {
                    guard let top = AdManager.topmostPresenterVC() else { return }
                    MobileAds.shared.presentAdInspector(from: top) { error in
                        if let error { print("[AdInspector] \(error.localizedDescription)") }
                    }
                }
            }
            #endif

            Section("ABOUT") {
                LabeledContent("Developer", value: "Ashutosh Bhardwaj")
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    LabeledContent("Version", value: version)
                }
            }
        }
        .navigationTitle("Settings")
        .task { await purchaseManager.loadProducts() }
    }
}
