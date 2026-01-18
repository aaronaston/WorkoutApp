import Foundation

// Shared payloads for WatchConnectivity session messaging.

enum SessionLifecycleState: String, Codable, Hashable {
    case idle
    case preparing
    case active
    case paused
    case completed
    case canceled
}

struct SessionPauseInterval: Codable, Hashable {
    var startedAt: Date
    var endedAt: Date?
}

struct SessionTiming: Codable, Hashable {
    var startedAt: Date?
    var endedAt: Date?
    var pauseIntervals: [SessionPauseInterval]
    var activeDurationSeconds: Int?
}

struct WatchSessionStartRequest: Codable, Hashable {
    var sessionID: UUID
    var workout: WorkoutReference
    var metadata: WorkoutMetadata
    var timerConfiguration: TimerConfiguration?
    var sections: [WorkoutSection]
    var requestedAt: Date
}

enum WatchSessionCommandType: String, Codable, Hashable {
    case start
    case pause
    case resume
    case end
    case cancel
    case syncState
}

struct WatchSessionCommand: Codable, Hashable {
    var sessionID: UUID
    var type: WatchSessionCommandType
    var sentAt: Date
}

struct LiveSessionMetrics: Codable, Hashable {
    var heartRateBpm: Double?
    var activeEnergyBurned: Double?
    var distanceMeters: Double?
}

struct WatchSessionStateUpdate: Codable, Hashable {
    var sessionID: UUID
    var state: SessionLifecycleState
    var timing: SessionTiming
    var currentSectionIndex: Int?
    var currentItemIndex: Int?
    var metrics: LiveSessionMetrics?
    var updatedAt: Date
}

struct WatchSessionErrorReport: Codable, Hashable {
    var sessionID: UUID
    var code: String
    var message: String
    var occurredAt: Date
}
