import SwiftUI
import AVFoundation
import MediaPlayer

// MARK: - VolumeManager

class VolumeManager: NSObject {
    var maxVolume: Float = 0.7
    var isMaxVolumeEnabled: Bool = false

    func enforceMaxVolume() {
        guard isMaxVolumeEnabled else { return }
        let currentVolume = AVAudioSession.sharedInstance().outputVolume
        if currentVolume > maxVolume {
            setSystemVolume(maxVolume)
        }
    }

    private func setSystemVolume(_ volume: Float) {
        let volumeView = MPVolumeView(frame: .zero)
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            DispatchQueue.main.async { slider.value = volume }
        }
    }
}

// MARK: - SoundGenerator

class SoundGenerator {
    var audioEngine: AVAudioEngine!
    var audioSourceNode: AVAudioSourceNode!
    var frequency: Double = 1000.0
    var sampleRate: Double = 44100.0
    var phase: Double = 0.0

    /// 0 = silent, 1 = full volume. Used by SweepEngine to mute during gap intervals
    /// without stopping the audio engine (avoids glitches on rapid stop/start).
    var amplitude: Float = 1.0

    init() {
        audioEngine = AVAudioEngine()
        audioSourceNode = AVAudioSourceNode { (_, _, frameCount, audioBufferList) -> OSStatus in
            let bufferPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let phaseIncrement = 2.0 * .pi * self.frequency / self.sampleRate
            for frame in 0..<Int(frameCount) {
                let value = sin(self.phase) * Double(self.amplitude)
                self.phase += phaseIncrement
                if self.phase >= 2.0 * .pi { self.phase -= 2.0 * .pi }
                for buffer in bufferPointer {
                    buffer.mData?.storeBytes(of: Float(value),
                                             toByteOffset: frame * MemoryLayout<Float>.stride,
                                             as: Float.self)
                }
            }
            return noErr
        }
        audioEngine.attach(audioSourceNode)
        audioEngine.connect(audioSourceNode, to: audioEngine.mainMixerNode, format: nil)
    }

    func setFrequency(_ frequency: Double) { self.frequency = frequency }

    func startPlaying() {
        do { try audioEngine.start() } catch { print("Audio engine start failed: \(error)") }
    }

    func stopPlaying() { audioEngine.stop() }
}

// MARK: - FrequencyControlsView

struct FrequencyControlsView: View {
    @Binding var frequency: Double
    @Binding var isPlaying: Bool
    var soundGenerator: SoundGenerator
    var volumeManager: VolumeManager
    var onStop: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Text("Frequency: \(frequency, specifier: "%.0f") Hz")
                .font(.title2)

            Slider(value: Binding(
                get: { frequency },
                set: { newValue in
                    frequency = newValue
                    if isPlaying { soundGenerator.setFrequency(frequency) }
                }
            ), in: 20...20000, step: 1)

            Button(isPlaying ? "Stop Sound" : "Play Sound") {
                if isPlaying {
                    soundGenerator.stopPlaying()
                    onStop?()
                } else {
                    volumeManager.enforceMaxVolume()
                    soundGenerator.setFrequency(frequency)
                    soundGenerator.startPlaying()
                }
                isPlaying.toggle()
            }
            .font(.title2)
            .padding()
            .background(isPlaying ? Color.red : Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
            .shadow(radius: 5)
        }
        .padding()
    }
}

// MARK: - Instructions views

struct FirstTimeInstructionsView: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var navigateToMain = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Instructions")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 10) {
                    InstructionText(text: "\u{2022} Humans can typically hear sounds in the range of 20 Hz to 20,000 Hz.")
                    InstructionText(text: "\u{2022} Use the slider to select a frequency between 20 Hz and 20,000 Hz.")
                    InstructionText(text: "\u{2022} Tap 'Play Sound' to hear the selected frequency. Tap 'Stop Sound' to stop playback.")
                    WarningText(text: "Warning: Listening to sounds at high volumes for extended periods can cause hearing damage. Please keep the volume at a safe level.")
                    DisclaimerText(text: "Disclaimer: This app is provided for informational purposes only. The developer assumes no responsibility for any injury, hearing damage, or other harm resulting from the use of this app. Use at your own risk.")
                }
                .padding()

                Button("OK") {
                    settings.hasSeenInstructions = true
                    navigateToMain = true
                }
                .font(.title2)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)

                NavigationLink(destination: ContentView(), isActive: $navigateToMain) {
                    EmptyView()
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground).opacity(0.95))
            .cornerRadius(15)
            .shadow(radius: 10)
        }
    }
}

struct GeneralInstructionsView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Instructions")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 10) {
                    InstructionText(text: "\u{2022} Humans can typically hear sounds in the range of 20 Hz to 20,000 Hz.")
                    InstructionText(text: "\u{2022} Use the slider to select a frequency between 20 Hz and 20,000 Hz.")
                    InstructionText(text: "\u{2022} Tap 'Play Sound' to hear the selected frequency. Tap 'Stop Sound' to stop playback.")
                    WarningText(text: "Warning: Listening to sounds at high volumes for extended periods can cause hearing damage. Please keep the volume at a safe level.")
                    DisclaimerText(text: "Disclaimer: This app is provided for informational purposes only. The developer assumes no responsibility for any injury, hearing damage, or other harm resulting from the use of this app. Use at your own risk.")
                }
                .padding()

                Button("Back") {
                    presentationMode.wrappedValue.dismiss()
                }
                .font(.title2)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding()
            .background(Color(UIColor.systemBackground).opacity(0.95))
            .cornerRadius(15)
            .shadow(radius: 10)
        }
    }
}

struct InstructionText: View {
    let text: String
    var body: some View {
        Text(text).font(.body).foregroundColor(.primary)
    }
}

struct WarningText: View {
    let text: String
    var body: some View {
        Text(text).font(.body).foregroundColor(.red)
    }
}

struct DisclaimerText: View {
    let text: String
    var body: some View {
        Text(text).font(.body).foregroundColor(.gray)
    }
}

// MARK: - WelcomeView

struct WelcomeView: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var navigateToInstructions = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "waveform.path.ecg")
                .resizable()
                .scaledToFit()
                .frame(height: 150)
                .foregroundColor(.white)

            Text("Welcome to Easy Ear Tune")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Challenge your ears with interactive sound!")
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding()

            Button("Get Started") {
                settings.hasSeenWelcome = true
                navigateToInstructions = true
            }
            .font(.title2)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)

            NavigationLink(destination: FirstTimeInstructionsView(), isActive: $navigateToInstructions) {
                EmptyView()
            }

            Spacer()
        }
        .padding()
        .background(LinearGradient(gradient: Gradient(colors: [Color.black, Color.gray]),
                                   startPoint: .top, endPoint: .bottom))
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var purchaseManager: PurchaseManager

    @State private var frequency: Double = 1000.0
    @State private var isPlaying = false
    @State private var showInstructions = false
    @State private var showPromo = false
    @State private var showHearingTest = false
    @State private var showHistory = false

    var soundGenerator = SoundGenerator()
    var volumeManager = VolumeManager()

    var body: some View {
        ZStack {
            AdPresenter().frame(width: 0, height: 0)

            VStack(spacing: 20) {
                FrequencyControlsView(
                    frequency: $frequency,
                    isPlaying: $isPlaying,
                    soundGenerator: soundGenerator,
                    volumeManager: volumeManager,
                    onStop: handleStop
                )

                // Hearing test entry points
                HStack(spacing: 12) {
                    NavigationLink(destination: HearingTestView()
                        .environmentObject(settings)
                        .environmentObject(purchaseManager),
                        isActive: $showHearingTest) { EmptyView() }

                    Button {
                        showHearingTest = true
                    } label: {
                        Label("Hearing Test", systemImage: "ear")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .cornerRadius(12)
                    }

                    Button {
                        showHistory = true
                    } label: {
                        Label("History", systemImage: "clock")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(12)
                    }
                    .sheet(isPresented: $showHistory) {
                        HearingHistoryView()
                    }
                }
                .padding(.horizontal, 4)

                if !settings.hasRemovedAds {
                    Button("Remove Ads — \(purchaseManager.localizedPrice ?? "$0.99")") {
                        showPromo = true
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                }

                Button("Instructions") {
                    showInstructions = true
                }
                .sheet(isPresented: $showInstructions) {
                    GeneralInstructionsView()
                }
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showPromo) {
            RemoveAdsPromoView(onDismiss: { showPromo = false })
                .environmentObject(settings)
                .environmentObject(purchaseManager)
        }
    }

    private func handleStop() {
        guard !settings.hasRemovedAds else { return }
        AdManager.shared.noteRoundCompleted()
        if AdManager.shared.shouldShowPromoInsteadOfAd() {
            AdManager.shared.notePromoShown()
            showPromo = true
        } else {
            AdManager.shared.presentIfAllowed()
        }
    }
}
