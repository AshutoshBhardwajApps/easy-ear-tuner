import SwiftUI
import AVFoundation
import MediaPlayer

// VolumeManager class for handling volume changes
class VolumeManager: NSObject {
    var maxVolume: Float = 0.7
    var isMaxVolumeEnabled: Bool = false

    func enforceMaxVolume() {
        guard isMaxVolumeEnabled else { return }
        
        let currentVolume = AVAudioSession.sharedInstance().outputVolume
        if currentVolume > maxVolume {
            setSystemVolume(maxVolume)
            print("Volume restricted to: \(maxVolume)")
        }
    }

    private func setSystemVolume(_ volume: Float) {
        let volumeView = MPVolumeView(frame: .zero)
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            DispatchQueue.main.async {
                slider.value = volume
            }
        }
    }
}

// SoundGenerator for generating sine wave audio
class SoundGenerator {
    var audioEngine: AVAudioEngine!
    var audioSourceNode: AVAudioSourceNode!
    var frequency: Double = 1000.0
    var sampleRate: Double = 44100.0
    var phase: Double = 0.0

    init() {
        audioEngine = AVAudioEngine()
        audioSourceNode = AVAudioSourceNode { (_, _, frameCount, audioBufferList) -> OSStatus in
            let bufferPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let phaseIncrement = 2.0 * .pi * self.frequency / self.sampleRate

            for frame in 0..<Int(frameCount) {
                let value = sin(self.phase)
                self.phase += phaseIncrement
                if self.phase >= 2.0 * .pi {
                    self.phase -= 2.0 * .pi
                }
                for buffer in bufferPointer {
                    buffer.mData?.storeBytes(of: Float(value), toByteOffset: frame * MemoryLayout<Float>.stride, as: Float.self)
                }
            }
            return noErr
        }
        audioEngine.attach(audioSourceNode)
        audioEngine.connect(audioSourceNode, to: audioEngine.mainMixerNode, format: nil)
    }

    func setFrequency(_ frequency: Double) {
        self.frequency = frequency
    }

    func startPlaying() {
        do {
            try audioEngine.start()
            print("Sound playing at frequency: \(frequency)")
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    func stopPlaying() {
        audioEngine.stop()
        print("Sound stopped")
    }
}

// Frequency controls view
struct FrequencyControlsView: View {
    @Binding var frequency: Double
    @Binding var isPlaying: Bool
    var soundGenerator: SoundGenerator
    var volumeManager: VolumeManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Frequency: \(frequency, specifier: "%.0f") Hz")
                .font(.title2)

            Slider(value: $frequency, in: 20...20000, step: 1, onEditingChanged: { _ in
                if isPlaying {
                    soundGenerator.setFrequency(frequency)
                }
            })

            Button(isPlaying ? "Stop Sound" : "Play Sound") {
                if isPlaying {
                    soundGenerator.stopPlaying()
                } else {
                    volumeManager.enforceMaxVolume() // Apply max volume
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

// Settings View for adjusting max volume and showing a sound level warning
/*struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("maxVolume") private var maxVolume: Double = 0.7
    @AppStorage("isMaxVolumeEnabled") private var isMaxVolumeEnabled: Bool = false
    let volumeManager: VolumeManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 10)

            Toggle("Enable Max Safe Sound", isOn: $isMaxVolumeEnabled)
                .onChange(of: isMaxVolumeEnabled) { newValue in
                    volumeManager.isMaxVolumeEnabled = newValue
                    volumeManager.enforceMaxVolume() // Apply changes immediately
                }
                .padding()

            Slider(value: $maxVolume, in: 0...1)
                .disabled(!isMaxVolumeEnabled)
                .padding()
                .onChange(of: maxVolume) { newValue in
                    volumeManager.maxVolume = Float(newValue)
                    volumeManager.enforceMaxVolume() // Adjust volume if necessary
                }

            Text("Warning: Listening to sounds at high volumes for extended periods can cause hearing damage. Please keep the volume at a safe level.")
                .font(.body)
                .foregroundColor(.red)
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
}*/

// First Time Instructions View
struct FirstTimeInstructionsView: View {
    @AppStorage("hasSeenInstructions") private var hasSeenInstructions: Bool = false
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
                    hasSeenInstructions = true
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

// General Instructions View
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
        Text(text)
            .font(.body)
            .foregroundColor(.primary)
    }
}

struct WarningText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundColor(.red)
    }
}

struct DisclaimerText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundColor(.gray)
    }
}

// Welcome screen view
struct WelcomeView: View {
    @State private var navigateToInstructions = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "waveform.path.ecg")
                .resizable()
                .scaledToFit()
                .frame(height: 150)
                .foregroundColor(.white)

            Text("Welcome to Easy Ear Tune ")
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
        .background(LinearGradient(gradient: Gradient(colors: [Color.black, Color.gray]), startPoint: .top, endPoint: .bottom))
        .edgesIgnoringSafeArea(.all)
    }
}

// Main ContentView with frequency slider and settings
struct ContentView: View {
    @State private var frequency: Double = 1000.0
    var soundGenerator = SoundGenerator()
    var volumeManager = VolumeManager()
    @State private var isPlaying = false
    @State private var showSettings = false
    @State private var showInstructions = false

    var body: some View {
        VStack(spacing: 20) {
            FrequencyControlsView(frequency: $frequency, isPlaying: $isPlaying, soundGenerator: soundGenerator, volumeManager: volumeManager)

           

            Button("Instructions") {
                showInstructions = true
            }
            .sheet(isPresented: $showInstructions) {
                GeneralInstructionsView()
            }
        }
        .padding()
        .onAppear {
            requestAudioPermissions()
        }
    }
}

// Function to request audio playback permissions and allow sound in silent/vibrate mode
func requestAudioPermissions() {
    let session = AVAudioSession.sharedInstance()
    do {
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
        try session.setActive(true)
        print("Audio session set successfully")
    } catch {
        print("Failed to set audio session: \(error)")
    }
}

@main
struct Freq_TestApp: App {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("hasSeenInstructions") private var hasSeenInstructions = false

    var body: some Scene {
        WindowGroup {
            NavigationView {
                if !hasSeenWelcome {
                    WelcomeView()
                } else if !hasSeenInstructions {
                    FirstTimeInstructionsView()
                } else {
                    ContentView()
                }
            }
        }
    }
}
