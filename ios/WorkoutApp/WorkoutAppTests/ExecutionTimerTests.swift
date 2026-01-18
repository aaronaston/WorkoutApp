import XCTest
@testable import WorkoutApp

final class ExecutionTimerTests: XCTestCase {
    func testIntervalTimerTracksRoundsAndPhase() {
        var timer = ExecutionTimer(
            configuration: TimerConfiguration(
                mode: .interval,
                workSeconds: 60,
                restSeconds: 30,
                rounds: 2,
                totalSeconds: nil
            )
        )
        let start = Date(timeIntervalSince1970: 0)
        timer.start(at: start)

        var snapshot = timer.snapshot(at: start.addingTimeInterval(45))
        XCTAssertEqual(snapshot.phase, .work)
        XCTAssertEqual(snapshot.round, 1)
        XCTAssertEqual(snapshot.remainingSeconds, 15)

        snapshot = timer.snapshot(at: start.addingTimeInterval(70))
        XCTAssertEqual(snapshot.phase, .rest)
        XCTAssertEqual(snapshot.round, 1)
        XCTAssertEqual(snapshot.remainingSeconds, 20)

        snapshot = timer.snapshot(at: start.addingTimeInterval(95))
        XCTAssertEqual(snapshot.phase, .work)
        XCTAssertEqual(snapshot.round, 2)
        XCTAssertEqual(snapshot.remainingSeconds, 55)
    }

    func testPauseResumeSkipsPausedTime() {
        var timer = ExecutionTimer(
            configuration: TimerConfiguration(
                mode: .countdown,
                workSeconds: nil,
                restSeconds: nil,
                rounds: nil,
                totalSeconds: 60
            )
        )
        let start = Date(timeIntervalSince1970: 0)
        timer.start(at: start)
        timer.pause(at: start.addingTimeInterval(10))

        var snapshot = timer.snapshot(at: start.addingTimeInterval(30))
        XCTAssertEqual(snapshot.elapsedSeconds, 10)
        XCTAssertEqual(snapshot.remainingSeconds, 50)

        timer.resume(at: start.addingTimeInterval(30))
        snapshot = timer.snapshot(at: start.addingTimeInterval(50))
        XCTAssertEqual(snapshot.elapsedSeconds, 30)
        XCTAssertEqual(snapshot.remainingSeconds, 30)
    }

    func testEmomDefaultsToSixtySecondIntervals() {
        var timer = ExecutionTimer(
            configuration: TimerConfiguration(
                mode: .emom,
                workSeconds: nil,
                restSeconds: nil,
                rounds: 2,
                totalSeconds: nil
            )
        )
        let start = Date(timeIntervalSince1970: 0)
        timer.start(at: start)

        let snapshot = timer.snapshot(at: start.addingTimeInterval(65))
        XCTAssertEqual(snapshot.round, 2)
        XCTAssertEqual(snapshot.remainingSeconds, 55)
    }

    func testAmrapCountsDownTotalTime() {
        var timer = ExecutionTimer(
            configuration: TimerConfiguration(
                mode: .amrap,
                workSeconds: nil,
                restSeconds: nil,
                rounds: nil,
                totalSeconds: 90
            )
        )
        let start = Date(timeIntervalSince1970: 0)
        timer.start(at: start)

        let snapshot = timer.snapshot(at: start.addingTimeInterval(30))
        XCTAssertEqual(snapshot.remainingSeconds, 60)
        XCTAssertEqual(snapshot.elapsedSeconds, 30)
    }

    func testCountdownCompletesAndClampsElapsed() {
        var timer = ExecutionTimer(
            configuration: TimerConfiguration(
                mode: .countdown,
                workSeconds: nil,
                restSeconds: nil,
                rounds: nil,
                totalSeconds: 30
            )
        )
        let start = Date(timeIntervalSince1970: 0)
        timer.start(at: start)

        let snapshot = timer.snapshot(at: start.addingTimeInterval(50))
        XCTAssertEqual(snapshot.elapsedSeconds, 30)
        XCTAssertEqual(snapshot.remainingSeconds, 0)
        XCTAssertTrue(snapshot.isComplete)
    }
}
