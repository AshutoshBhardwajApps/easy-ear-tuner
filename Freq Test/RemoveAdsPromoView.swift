import SwiftUI

struct RemoveAdsPromoView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var purchaseManager: PurchaseManager

    let onDismiss: () -> Void

    @State private var purchasing = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.6), radius: 18)

                VStack(spacing: 10) {
                    Text("ENJOYING")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.55))
                        .tracking(3)
                    Text(Constants.appName.uppercased() + "?")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 14) {
                    Text("Skip the ads forever.")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))
                    Text("One-time purchase. Supports the developer.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    Button(action: buy) {
                        HStack(spacing: 10) {
                            if purchasing {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "nosign")
                                Text(buyButtonTitle)
                            }
                        }
                        .font(.system(size: 19, weight: .black))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.green)
                        .cornerRadius(16)
                    }
                    .disabled(purchasing)

                    Button(action: onDismiss) {
                        Text("Continue with ads")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.55))
                            .padding(.vertical, 10)
                    }

                    if let msg = purchaseManager.errorMessage {
                        Text(msg)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.45))
                            .padding(16)
                    }
                }
                Spacer()
            }
        }
        .task { await purchaseManager.loadProducts() }
        .onChange(of: settings.hasRemovedAds) { hasRemoved in
            if hasRemoved { onDismiss() }
        }
    }

    private var buyButtonTitle: String {
        if let price = purchaseManager.localizedPrice {
            return "Remove Ads — \(price)"
        }
        return "Remove Ads — $0.99"
    }

    private func buy() {
        purchasing = true
        Task {
            await purchaseManager.buyRemoveAds()
            purchasing = false
        }
    }
}
