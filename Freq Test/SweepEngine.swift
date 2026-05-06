import Foundation

private struct GapInterval {
    let start: Double
    let duration: Double
    func active(at t: Double) -> Bool { t >= start && t < start + duration }
}

@MainActor
final class SweepEngine: ObservableObject {

    enum Phase: Equatable { case idle, running, finished }

    @Published private(set) var currentFrequency: Double = 2_000
    @Published private(set) var isTonePlaying: Bool = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var tapLog: [TapEvent] = []

    let startFreq: Double  = 2_000
    let endFreq: Double    = 20_000
    let totalDuration: Double = 45

    private let tickInterval: Double = 0.05
    private var elapsed: Double = 0
    private var timer: Timer?
    private var gaps: [GapInterval] = []
    private weak var generator: SoundGenerator?

    // MARK: - Control

    func start(using generator: SoundGenerator) {
        self.generator = generator
        elapsed = 0
        tapLog  = []
        progress = 0
        currentFrequency = startFreq
        gaps  = makeGaps()
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

    // MARK: - Subject interaction

    func subjectTapped() {
        guard phase == .running else { return }
        tapLog.append(TapEvent(
            frequency:      currentFrequency,
            toneWasPlaying: isTonePlaying,
            timestamp:      Date()
        ))
        // Only a tap while the tone is audible counts as the real cutoff.
        // A tap during a silent gap is a false alarm — log it, keep going.
        if isTonePlaying { finish() }
    }

    // MARK: - Result

    func makeResult(ear: Ear) -> HearingResult {
        HearingResult(
            date:          Date(),
            ear:           ear,
            maxFrequency:  tapLog.first { $0.toneWasPlaying }?.frequency ?? endFreq,
            falseTapCount: falseTapCount,
            reliability:   reliabilityScore,
            tapLog:        tapLog
        )
    }

    var falseTapCount: Int { tapLog.filter { !$0.toneWasPlaying }.count }

    var reliabilityScore: ReliabilityScore {
        switch falseTapCount {
        case 0:  return .high
        case 1:  return .medium
        default: return .low
        }
    }

    // MARK: - Private

    private func tick() {
        elapsed += tickInterval
        guard elapsed < totalDuration else { finish(); return }

        progress = elapsed / totalDuration

        // Logarithmic sweep — matches how humans perceive pitch
        currentFrequency = exp(
            log(startFreq) + log(endFreq / startFreq) * (elapsed / totalDuration)
        )

        let inGap     = gaps.contains { $0.active(at: elapsed) }
        let shouldPlay = !inGap

        if shouldPlay != isTonePlaying {
            isTonePlaying = shouldPlay
            generator?.amplitude = shouldPlay ? 1.0 : 0.0
        }
        if shouldPlay {
            generator?.setFrequency(currentFrequency)
        }
    }

    private func finish() {
        teardown()
        phase = .finished
    }

    private func teardown() {
        timer?.invalidate()
        timer = nil
        generator?.amplitude = 0.0
        generator?.stopPlaying()
        isTonePlaying = false
    }

    // Three gaps at roughly 30 %, 55 %, 78 % of the sweep — jittered so the
    // subject can't learn the pattern across repeated tests.
    private func makeGaps() -> [GapInterval] {
        [0.30, 0.55, 0.78].map { anchor in
            GapInterval(
                start:    max(4, (anchor + Double.random(in: -0.06...0.06)) * totalDuration),
                duration: Double.random(in: 1.3...2.0)
            )
        }
    }
}
