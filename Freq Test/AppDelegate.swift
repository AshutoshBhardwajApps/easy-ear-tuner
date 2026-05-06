import UIKit
import GoogleMobileAds
import AVFAudio
import AppTrackingTransparency

final class AppDelegate: NSObject, UIApplicationDelegate {
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

        // Paste your device's hashed ID here (from Xcode console after first ad request)
        // so your device serves test ads while real devices see real ads.
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
            "8db75299912f34924228c6d5e577456a",
        ]

        MobileAds.shared.start()

        // ATT prompt is triggered from the first visible view via requestATTIfNeeded()
        // rather than here — calling it in didFinishLaunching fires before the window
        // is active on iOS 17+ and the prompt silently never appears.

        return true
    }
}
