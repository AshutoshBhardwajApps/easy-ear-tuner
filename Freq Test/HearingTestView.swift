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
                SaboteurActiveView(engine: engine, onTap: engine.subjectTapped)
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
                .padding(.bottom, 4)

            Text("Saboteur Mode")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.green.opacity(0.7))
                .tracking(3)
                .padding(.bottom, 28)

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
            .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 14) {
                InstructionRow(icon: "waveform",
                               text: "A tone sweeps from 2,000 Hz → 20,000 Hz over 45 seconds.")
                InstructionRow(icon: "eyes.inverse",
                               text: "TESTER: Close your eyes. Tap the button whenever you hear silence.")
                InstructionRow(icon: "hand.point.up.left.fill",
                               text: "SABOTEUR: Hold the top panel to mute — create as many silent gaps as you like.")
                InstructionRow(icon: "checkmark.circle.fill",
                               text: "Tap during a silence = correct detection. Tap during tone = your hearing cutoff.")
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

// MARK: - Saboteur active screen

private struct SaboteurActiveView: View {
    @ObservedObject var engine: SweepEngine
    let onTap: () -> Void

    // GestureState resets to false automatically when finger lifts —
    // no explicit onEnded needed to restore the tone.
    @GestureState private var isSaboteurHolding = false

    var body: some View {
        VStack(spacing: 0) {

            // ── Progress bar ──────────────────────────────────────────
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.08))
                    Rectangle().fill(Color.green)
                        .frame(width: geo.size.width * engine.progress)
                        .animation(.linear(duration: 0.08), value: engine.progress)
                }
            }
            .frame(height: 4)

            // ── SABOTEUR panel (top) ───────────────────────────────────
            SaboteurPanel(isHolding: isSaboteurHolding)
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($isSaboteurHolding) { _, state, _ in state = true }
                )
                .onChange(of: isSaboteurHolding) { _, holding in
                    engine.setWitnessMute(holding)
                }

            // ── Sine wave visualisation ────────────────────────────────
            SineWaveView(
                frequency:  engine.currentFrequency,
                isMuted:    !engine.isTonePlaying
            )
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .padding(.vertical, 8)

            // ── TESTER panel (bottom) ──────────────────────────────────
            TesterPanel(onTap: onTap)
                .frame(maxWidth: .infinity)
                .frame(height: 190)
        }
        .background(Color.black)
    }
}

// MARK: - Saboteur panel

private struct SaboteurPanel: View {
    let isHolding: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0)
                .fill(isHolding
                      ? Color.orange.opacity(0.18)
                      : Color.white.opacity(0.04))
                .animation(.easeInOut(duration: 0.12), value: isHolding)

            VStack(spacing: 10) {
                Label("SABOTEUR", systemImage: "theatermasks.fill")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.orange.opacity(0.7))
                    .tracking(3)

                Spacer()

                Image(systemName: isHolding ? "speaker.slash.fill" : "hand.point.up.left.fill")
                    .font(.system(size: 36, weight: .thin))
                    .foregroundColor(isHolding ? .orange : .white.opacity(0.4))
                    .animation(.easeInOut(duration: 0.12), value: isHolding)

                Text(isHolding ? "MUTED" : "Hold here to silence the tone")
                    .font(.system(size: isHolding ? 20 : 14, weight: isHolding ? .black : .regular))
                    .foregroundColor(isHolding ? .orange : .white.opacity(0.4))
                    .animation(.easeInOut(duration: 0.12), value: isHolding)

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Tester panel

private struct TesterPanel: View {
    let onTap: () -> Void
    @State private var pulse: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.white.opacity(0.03)

            VStack(spacing: 8) {
                Label("TESTER — EYES CLOSED", systemImage: "eye.slash.fill")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.green.opacity(0.6))
                    .tracking(2)

                Spacer()

                Button(action: onTap) {
                    VStack(spacing: 8) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 28))
                        Text("I HEAR SILENCE!")
                            .font(.system(size: 20, weight: .black))
                            .tracking(1)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
                    .background(Color.green)
                    .cornerRadius(16)
                    .shadow(color: .green.opacity(0.3), radius: 20)
                    .scaleEffect(pulse)
                }
                .padding(.horizontal, 24)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                        pulse = 1.03
                    }
                }

                Spacer()
            }
            .padding(.top, 10)
        }
    }
}

// MARK: - Sine wave visualisation

struct SineWaveView: View {
    let frequency: Double   // 2000…20000 Hz
    let isMuted: Bool

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t      = tl.date.timeIntervalSinceReferenceDate
                // Animation speed scales with frequency (higher pitch = faster scroll)
                let speed  = 1.0 + (frequency - 2_000) / 18_000 * 3.5
                let midY   = size.height / 2
                let amp    = size.height * 0.42
                let cycles = 3.5

                var path = Path()
                for i in 0...Int(size.width) {
                    let x     = Double(i)
                    let phase = (x / size.width) * .pi * 2 * cycles - t * speed * .pi * 2
                    let y     = midY + amp * sin(phase)
                    if i == 0 { path.move(to: .init(x: x, y: y)) }
                    else       { path.addLine(to: .init(x: x, y: y)) }
                }

                ctx.stroke(
                    path,
                    with: .color(.green.opacity(0.9)),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
            }
        }
        // Scaling Y to 0 flatlines the wave when muted — SwiftUI handles the animation.
        .scaleEffect(y: isMuted ? 0.0 : 1.0, anchor: .center)
        .animation(.easeInOut(duration: 0.18), value: isMuted)
        .background(Color.black)
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

                // Max frequency
                VStack(spacing: 6) {
                    Text("HEARING CUTOFF")
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

                // Silence detections
                let detections = result.tapLog.filter { !$0.toneWasPlaying }.count
                VStack(spacing: 6) {
                    Text("SABOTEUR GAPS CAUGHT")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white.opacity(0.45))
                        .tracking(2)
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(detections > 0 ? .green : .white.opacity(0.3))
                        Text(detections == 0 ? "None detected" : "\(detections) silence\(detections == 1 ? "" : "s") caught")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    Text("Saboteur can verify against how many gaps they actually created.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.06))
                .cornerRadius(16)
                .padding(.horizontal)

                // Ear + date
                Text("\(result.ear) ear · \(result.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.35))

                // Tap log
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
                                      ? "flag.checkered" : "checkmark.circle")
                                    .foregroundColor(tap.toneWasPlaying ? .green : .cyan)
                                Text(tap.toneWasPlaying
                                     ? "Cutoff at \(tap.frequency, specifier: "%.0f") Hz"
                                     : "Silence detected at \(tap.frequency, specifier: "%.0f") Hz")
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
}
