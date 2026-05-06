import Foundation

@MainActor
final class SweepEngine: ObservableObject {

    enum Phase: Equatable { case idle, running, finished }

    @Published private(set) var currentFrequency: Double = 2_000
    @Published private(set) var isTonePlaying: Bool = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var tapLog: [TapEvent] = []

    let startFreq: Double     = 2_000
    let endFreq: Double       = 20_000
    let totalDuration: Double = 45

    private let tickInterval: Double = 0.05
    private var elapsed: Double = 0
    private var timer: Timer?
    private weak var generator: SoundGenerator?

    // MARK: - Control

    func start(using generator: SoundGenerator) {
        self.generator = generator
        elapsed  = 0
        tapLog   = []
        progress = 0
        currentFrequency = startFreq
        phase = .running
        isTonePlaying = true

        generator.amplitude = 1.0
        generator.setFrequency(startFreq)
        generator.startPlaying()

        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func cancel() {
        teardown()
        phase = .idle
    }

    // MARK: - Saboteur control
    // Witness holds a button to mute; releasing restores the tone.
    // No pre-programmed gaps — timing is entirely up to the Saboteur.

    func setWitnessMute(_ muted: Bool) {
        guard phase == .running else { return }
        isTonePlaying = !muted
        generator?.amplitude = muted ? 0.0 : 1.0
    }

    // MARK: - Tester interaction
    // Tester taps whenever they detect silence.
    //   • toneWasPlaying == false → correct gap detection, sweep continues
    //   • toneWasPlaying == true  → genuine hearing cutoff, test ends

    func subjectTapped() {
        guard phase == .running else { return }
        tapLog.append(TapEvent(
            frequency:      currentFrequency,
            toneWasPlaying: isTonePlaying,
            timestamp:      Date()
        ))
        if isTonePlaying { finish() }
    }

    // MARK: - Result

    func makeResult(ear: Ear) -> HearingResult {
        HearingResult(
            date:             Date(),
            ear:              ear,
            maxFrequency:     tapLog.first { $0.toneWasPlaying }?.frequency ?? endFreq,
            falseTapCount:    silencesDetected,
            reliability:      reliabilityScore,
            tapLog:           tapLog
        )
    }

    /// Number of correct silence detections (taps during witness-muted gaps).
    var silencesDetected: Int { tapLog.filter { !$0.toneWasPlaying }.count }

    var reliabilityScore: ReliabilityScore { .high }   // scoring is now witness-driven

    // MARK: - Private

    private func tick() {
        elapsed += tickInterval
        guard elapsed < totalDuration else { finish(); return }

        progress = elapsed / totalDuration
        // Logarithmic sweep — perceived pitch changes linearly
        currentFrequency = exp(
            log(startFreq) + log(endFreq / startFreq) * (elapsed / totalDuration)
        )
        // Update frequency only while tone is playing (witness may have muted it)
        if isTonePlaying {
            generator?.setFrequency(currentFrequency)
        }
    }

    private func finish() {
        teardown()
        phase = .finished
    }

    private func teardown() {
        timer?.invalidate()
        timer  = nil
        generator?.amplitude = 0.0
        generator?.stopPlaying()
        isTonePlaying = false
    }
}
