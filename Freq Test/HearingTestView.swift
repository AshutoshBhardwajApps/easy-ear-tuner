import SwiftUI
import SwiftData

// MARK: - Coordinator

struct HearingTestView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var purchaseManager: PurchaseManager

    @StateObject private var engine = SweepEngine()
    @State private var selectedEar: Ear = .both
    @State private var viewPhase: ViewPhase = .setup
    @State private var result: HearingResult?
    @State private var showWitness = false

    private let generator = SoundGenerator()

    private enum ViewPhase { case setup, active, result }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch viewPhase {
            case .setup:
                TestSetupView(selectedEar: $selectedEar, onStart: startTest)
                    .transition(.opacity)
            case .active:
                TestActiveView(engine: engine, showWitness: $showWitness,
                               onTap: engine.subjectTapped)
                    .transition(.opacity)
            case .result:
                if let r = result {
                    TestResultView(result: r, onRetry: retryTest, onDone: { dismiss() })
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewPhase)
        .onChange(of: engine.phase) { _, newPhase in
            if newPhase == .finished { commitResult() }
        }
        .sheet(isPresented: $showWitness) {
            WitnessSheetView(engine: engine)
        }
        .navigationBarHidden(true)
        .onDisappear {
            if engine.phase == .running { engine.cancel() }
        }
    }

    private func startTest() {
        viewPhase = .active
        engine.start(using: generator)
    }

    private func commitResult() {
        let r = engine.makeResult(ear: selectedEar)
        modelContext.insert(r)
        try? modelContext.save()
        result = r
        viewPhase = .result
    }

    private func retryTest() {
        result = nil
        viewPhase = .setup
    }
}

// MARK: - Setup

private struct TestSetupView: View {
    @Binding var selectedEar: Ear
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "ear")
                .font(.system(size: 64, weight: .thin))
                .foregroundColor(.green)
                .padding(.bottom, 16)

            Text("Hearing Test")
                .font(.system(size: 30, weight: .black))
                .foregroundColor(.white)
                .padding(.bottom, 32)

            // Ear picker
            VStack(spacing: 10) {
                Text("WHICH EAR?")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white.opacity(0.45))
                    .tracking(3)
                HStack(spacing: 10) {
                    ForEach(Ear.allCases, id: \.self) { ear in
                        Button(ear.rawValue) { selectedEar = ear }
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(selectedEar == ear ? Color.green : Color.white.opacity(0.08))
                            .foregroundColor(selectedEar == ear ? .black : .white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding(.bottom, 32)

            // Instructions
            VStack(alignment: .leading, spacing: 14) {
                InstructionRow(icon: "waveform",
                               text: "A tone sweeps from 2,000 Hz up to 20,000 Hz over 45 seconds.")
                InstructionRow(icon: "hand.raised.fill",
                               text: "Tap the big button the moment you can NO LONGER hear it.")
                InstructionRow(icon: "exclamationmark.triangle.fill",
                               text: "Watch out — there are silent gaps. Don't tap during a gap or it counts against you!")
                InstructionRow(icon: "eye.fill",
                               text: "Close your eyes or look away during the test. A witness taps 👁 Witness to monitor — the screen won't show you any hints.")
            }
            .padding(.horizontal, 28)

            Spacer()

            Button(action: onStart) {
                Text("Start Test")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.green)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }
}

private struct InstructionRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Active test

private struct TestActiveView: View {
    @ObservedObject var engine: SweepEngine
    @Binding var showWitness: Bool
    let onTap: () -> Void

    @State private var pulse: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.08))
                    Rectangle().fill(Color.green)
                        .frame(width: geo.size.width * engine.progress)
                        .animation(.linear(duration: 0.08), value: engine.progress)
                }
            }
            .frame(height: 4)

            // Witness button
            HStack {
                Spacer()
                Button { showWitness = true } label: {
                    Label("Witness", systemImage: "eye.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                }
                .padding(.trailing, 20)
                .padding(.top, 14)
            }

            Spacer()

            // Neutral waveform — looks identical whether the tone is playing or silent.
            // Any visual change here would tip off the subject during gap intervals.
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulse)

                Image(systemName: "waveform")
                    .font(.system(size: 72, weight: .thin))
                    .foregroundColor(.green)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulse = 1.12
                }
            }

            Text("Tap when you can no longer hear the tone")
                .font(.caption)
                .foregroundColor(.white.opacity(0.35))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 12)

            Spacer()

            // Main button
            Button(action: onTap) {
                VStack(spacing: 10) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 32))
                    Text("I CAN'T HEAR IT!")
                        .font(.system(size: 22, weight: .black))
                        .tracking(1)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .background(Color.green)
                .cornerRadius(20)
                .shadow(color: .green.opacity(0.35), radius: 24)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 50)
        }
    }
}

// MARK: - Witness sheet

struct WitnessSheetView: View {
    @ObservedObject var engine: SweepEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Status card
                        VStack(spacing: 8) {
                            Image(systemName: engine.isTonePlaying
                                  ? "speaker.wave.3.fill" : "speaker.slash.fill")
                                .font(.system(size: 44))
                                .foregroundColor(engine.isTonePlaying ? .green : .orange)
                                .animation(.easeInOut(duration: 0.2), value: engine.isTonePlaying)

                            Text(engine.isTonePlaying ? "TONE PLAYING" : "SILENT GAP")
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(engine.isTonePlaying ? .green : .orange)
                                .tracking(3)
                                .animation(.none, value: engine.isTonePlaying)

                            Text("\(engine.currentFrequency, specifier: "%.0f") Hz")
                                .font(.title3.monospacedDigit())
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(16)

                        // Tap log
                        VStack(alignment: .leading, spacing: 0) {
                            Text("TAP LOG")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.white.opacity(0.4))
                                .tracking(2)
                                .padding(.bottom, 10)

                            if engine.tapLog.isEmpty {
                                Text("No taps yet…")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.3))
                            } else {
                                ForEach(engine.tapLog.indices, id: \.self) { i in
                                    let tap = engine.tapLog[i]
                                    HStack(spacing: 12) {
                                        Image(systemName: tap.toneWasPlaying
                                              ? "checkmark.circle.fill"
                                              : "exclamationmark.circle.fill")
                                            .foregroundColor(tap.toneWasPlaying ? .green : .orange)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(tap.toneWasPlaying
                                                 ? "Stopped at \(tap.frequency, specifier: "%.0f") Hz"
                                                 : "False tap at \(tap.frequency, specifier: "%.0f") Hz")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundColor(.white)
                                            Text(tap.toneWasPlaying
                                                 ? "✅ Tone was playing — valid stop"
                                                 : "⚠️ Tone was silent — gap tap")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    Divider().background(Color.white.opacity(0.08))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(12)

                        Text("Subject cannot see this screen's details.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.3))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .navigationTitle("Witness View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.green)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Result

private struct TestResultView: View {
    let result: HearingResult
    let onRetry: () -> Void
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 16)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.green)

                Text("Test Complete")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)

                // Frequency card
                VStack(spacing: 6) {
                    Text("MAX FREQUENCY HEARD")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white.opacity(0.45))
                        .tracking(2)
                    Text("\(result.maxFrequency, specifier: "%.0f") Hz")
                        .font(.system(size: 52, weight: .black).monospacedDigit())
                        .foregroundColor(.green)
                    Text(result.ageComparison)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.06))
                .cornerRadius(16)
                .padding(.horizontal)

                // Reliability card
                VStack(spacing: 6) {
                    Text("RELIABILITY")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white.opacity(0.45))
                        .tracking(2)
                    HStack(spacing: 8) {
                        Image(systemName: reliabilityIcon)
                            .foregroundColor(reliabilityColor)
                        Text(result.reliabilityEnum.rawValue)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    Text(result.falseTapCount == 0
                         ? "No false taps — clean result"
                         : "\(result.falseTapCount) tap\(result.falseTapCount == 1 ? "" : "s") during silent gaps")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.06))
                .cornerRadius(16)
                .padding(.horizontal)

                // Meta
                Text("\(result.ear) ear · \(result.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.35))

                // Tap log detail
                if !result.tapLog.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TAP LOG")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(2)
                        ForEach(result.tapLog.indices, id: \.self) { i in
                            let tap = result.tapLog[i]
                            HStack(spacing: 8) {
                                Image(systemName: tap.toneWasPlaying
                                      ? "checkmark.circle" : "exclamationmark.circle")
                                    .foregroundColor(tap.toneWasPlaying ? .green : .orange)
                                Text(tap.toneWasPlaying
                                     ? "Stopped at \(tap.frequency, specifier: "%.0f") Hz"
                                     : "False tap at \(tap.frequency, specifier: "%.0f") Hz")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                HStack(spacing: 12) {
                    Button("Try Again", action: onRetry)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(14)

                    Button("Done", action: onDone)
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
    }

    private var reliabilityIcon: String {
        switch result.reliabilityEnum {
        case .high:   return "checkmark.seal.fill"
        case .medium: return "questionmark.circle.fill"
        case .low:    return "exclamationmark.triangle.fill"
        }
    }

    private var reliabilityColor: Color {
        switch result.reliabilityEnum {
        case .high:   return .green
        case .medium: return .yellow
        case .low:    return .red
        }
    }
}
