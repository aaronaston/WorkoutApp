import Foundation

enum TimerPhase: String, Codable, Hashable {
    case work
    case rest
}

enum ExecutionTimerStatus: String, Codable, Hashable {
    case idle
    case running
    case paused
    case completed
}

struct ExecutionTimerSnapshot: Hashable {
    let mode: TimerMode
    let phase: TimerPhase
    let remainingSeconds: Int?
    let elapsedSeconds: Int
    let round: Int?
    let totalRounds: Int?
    let isRunning: Bool
    let isComplete: Bool
}

struct ExecutionTimer {
    let configuration: TimerConfiguration
    private(set) var status: ExecutionTimerStatus = .idle
    private(set) var startedAt: Date?
    private(set) var pausedAt: Date?
    private(set) var accumulatedPause: TimeInterval = 0
    private(set) var completedAt: Date?

    init(configuration: TimerConfiguration) {
        self.configuration = configuration
    }

    mutating func start(at date: Date = Date()) {
        guard status == .idle else { return }
        status = .running
        startedAt = date
        pausedAt = nil
        accumulatedPause = 0
        completedAt = nil
    }

    mutating func pause(at date: Date = Date()) {
        guard status == .running else { return }
        status = .paused
        pausedAt = date
    }

    mutating func resume(at date: Date = Date()) {
        guard status == .paused, let pausedAt else { return }
        status = .running
        accumulatedPause += date.timeIntervalSince(pausedAt)
        self.pausedAt = nil
    }

    mutating func stop(at date: Date = Date()) {
        guard status == .running || status == .paused else { return }
        if status == .paused, let pausedAt {
            accumulatedPause += date.timeIntervalSince(pausedAt)
        }
        status = .completed
        pausedAt = nil
        completedAt = date
    }

    func snapshot(at date: Date = Date()) -> ExecutionTimerSnapshot {
        let elapsedSeconds = activeElapsedSeconds(at: date)
        let normalized = configuration.normalized()
        let isCompleted = status == .completed

        switch configuration.mode {
        case .stopwatch:
            return ExecutionTimerSnapshot(
                mode: configuration.mode,
                phase: .work,
                remainingSeconds: nil,
                elapsedSeconds: elapsedSeconds,
                round: nil,
                totalRounds: nil,
                isRunning: status == .running,
                isComplete: isCompleted
            )
        case .countdown:
            let total = normalized.totalSeconds
            let clampedElapsed = min(elapsedSeconds, total)
            let remaining = max(0, total - clampedElapsed)
            let isComplete = isCompleted || elapsedSeconds >= total
            return ExecutionTimerSnapshot(
                mode: configuration.mode,
                phase: .work,
                remainingSeconds: remaining,
                elapsedSeconds: clampedElapsed,
                round: nil,
                totalRounds: nil,
                isRunning: status == .running,
                isComplete: isComplete
            )
        case .amrap:
            let total = normalized.totalSeconds
            let clampedElapsed = min(elapsedSeconds, total)
            let remaining = max(0, total - clampedElapsed)
            let isComplete = isCompleted || elapsedSeconds >= total
            return ExecutionTimerSnapshot(
                mode: configuration.mode,
                phase: .work,
                remainingSeconds: remaining,
                elapsedSeconds: clampedElapsed,
                round: nil,
                totalRounds: nil,
                isRunning: status == .running,
                isComplete: isComplete
            )
        case .emom:
            let intervalSeconds = normalized.emomIntervalSeconds
            let totalRounds = normalized.rounds
            let totalSeconds = intervalSeconds * totalRounds
            let clampedElapsed = min(elapsedSeconds, totalSeconds)
            let roundIndex = min(totalRounds, clampedElapsed / intervalSeconds + 1)
            let roundElapsed = clampedElapsed % intervalSeconds
            let remaining = max(0, intervalSeconds - roundElapsed)
            let isComplete = isCompleted || elapsedSeconds >= totalSeconds
            return ExecutionTimerSnapshot(
                mode: configuration.mode,
                phase: .work,
                remainingSeconds: remaining,
                elapsedSeconds: clampedElapsed,
                round: roundIndex,
                totalRounds: totalRounds,
                isRunning: status == .running,
                isComplete: isComplete
            )
        case .interval:
            let workSeconds = normalized.workSeconds
            let restSeconds = normalized.restSeconds
            let totalRounds = normalized.rounds
            let cycleSeconds = max(1, workSeconds + restSeconds)
            let totalSeconds = cycleSeconds * totalRounds
            let clampedElapsed = min(elapsedSeconds, totalSeconds)
            let roundIndex = min(totalRounds, clampedElapsed / cycleSeconds + 1)
            let roundElapsed = clampedElapsed % cycleSeconds
            let isWork = roundElapsed < workSeconds
            let phase: TimerPhase = isWork ? .work : .rest
            let remaining = isWork
                ? max(0, workSeconds - roundElapsed)
                : max(0, restSeconds - (roundElapsed - workSeconds))
            let isComplete = isCompleted || elapsedSeconds >= totalSeconds
            return ExecutionTimerSnapshot(
                mode: configuration.mode,
                phase: phase,
                remainingSeconds: remaining,
                elapsedSeconds: clampedElapsed,
                round: roundIndex,
                totalRounds: totalRounds,
                isRunning: status == .running,
                isComplete: isComplete
            )
        }
    }

    private func activeElapsedSeconds(at date: Date) -> Int {
        guard let startedAt else { return 0 }
        let effectiveEnd = completedAt ?? pausedAt ?? date
        let activeElapsed = effectiveEnd.timeIntervalSince(startedAt) - accumulatedPause
        return max(0, Int(activeElapsed.rounded(.down)))
    }
}

private struct NormalizedTimerConfiguration {
    let workSeconds: Int
    let restSeconds: Int
    let rounds: Int
    let totalSeconds: Int
    let emomIntervalSeconds: Int
}

private extension TimerConfiguration {
    func normalized() -> NormalizedTimerConfiguration {
        let rounds = max(1, rounds ?? 1)
        let workSeconds = max(0, workSeconds ?? 0)
        let restSeconds = max(0, restSeconds ?? 0)
        let totalSeconds = max(0, totalSeconds ?? 0)
        let emomIntervalSeconds = max(1, workSeconds > 0 ? workSeconds : 60)

        return NormalizedTimerConfiguration(
            workSeconds: workSeconds,
            restSeconds: restSeconds,
            rounds: rounds,
            totalSeconds: totalSeconds,
            emomIntervalSeconds: emomIntervalSeconds
        )
    }
}
