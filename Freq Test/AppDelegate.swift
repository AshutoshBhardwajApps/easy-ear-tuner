import UIKit
import GoogleMobileAds
import AVFAudio
import AppTrackingTransparency
import FBAudienceNetwork

final class AppDelegate: NSObject, UIApplicationDelegate {

    /// One-shot guard so we only request ATT once per launch even if
    /// didBecomeActive fires multiple times (e.g. user toggled Control
    /// Center, returned to app, etc.).
    private var attRequested = false
    private var didBecomeActiveObserver: NSObjectProtocol?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        // .playback lets sound play even in silent mode — required for a frequency tuner.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }

        // Register test devices so real ad-unit IDs serve TEST ads on these devices.
        // Find your device's hashed ID in the Xcode console after the first ad request:
        //   "To get test ads on this device, set: Mobile Ads SDK ... testDeviceIdentifiers = @[ @"ABC123..." ]"
        // The hash follows the device's advertising identifier, so it changes if
        // that identifier is reset — at which point the device silently starts
        // serving REAL ads to you. Re-read it from the console when that happens.
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
            "8db75299912f34924228c6d5e577456a",
            "c18f2644337b99f078c7f88f6136a82f", // as re-read by CoopHockey 2026-10-05
        ]

        // Meta Audience Network (mediation bidding) needs its Advertiser
        // Tracking Enabled flag set before the Google Mobile Ads SDK
        // initializes its adapters. On first launch ATT is .notDetermined so
        // this starts false; requestATTThenPreloadAds() updates it once the
        // user answers the prompt.
        FBAdSettings.setAdvertiserTrackingEnabled(
            ATTrackingManager.trackingAuthorizationStatus == .authorized
        )

        MobileAds.shared.start()

        // ATT must be requested when the app is in the .active state. Calling
        // it from didFinishLaunching is too early — iOS silently no-ops the
        // request (App Store review rejected CoopHockey 1.3(14) for exactly
        // this). It used to fire from ContentView.onAppear, which meant it
        // never appeared until onboarding was finished; didBecomeActive + 0.4s
        // is the CoopHockey timing and works from the first screen.
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.requestATTIfNeeded()
        }

        return true
    }

    private func requestATTIfNeeded() {
        guard !attRequested else { return }
        attRequested = true

        if let token = didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(token)
            didBecomeActiveObserver = nil
        }

        // 0.4s delay lets the launch transition finish before a system alert.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // UMP consent runs BEFORE ATT. In the EEA/UK/Switzerland a
            // Google-certified CMP has to gather GDPR consent or those users
            // can only ever be served non-personalised ads. Everywhere else
            // UMP reports "no form required" and this falls straight through.
            ConsentManager.shared.gather(from: Self.keyWindowRoot()) { [weak self] in
                self?.requestATTThenPreloadAds()
            }
        }
    }

    private func requestATTThenPreloadAds() {
        ATTrackingManager.requestTrackingAuthorization { status in
            FBAdSettings.setAdvertiserTrackingEnabled(status == .authorized)
            Task { @MainActor in AdManager.shared.preload() }
        }
    }

    /// Root controller of the active scene's key window — where the UMP
    /// consent form presents from.
    private static func keyWindowRoot() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .first?
            .windows.first(where: { $0.isKeyWindow })?
            .rootViewController
    }
}
