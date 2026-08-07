@testable import MediaPauseCore
import Foundation

private func makeTimer(total: TimeInterval = 100) -> (CountdownTimer, FakeClock) {
    let clock = FakeClock()
    return (CountdownTimer(total: total, clock: clock), clock)
}

func testBeforeStartShowsFullRemaining() throws {
    let (timer, _) = makeTimer()
    let snap = timer.snapshot()
    try checkEqual(snap.remaining, 100, "remaining")
    try checkEqual(snap.elapsed, 0, "elapsed")
    try checkEqual(snap.progress, 0, "progress")
    try checkFalse(snap.finished)
}

func testProgressAdvances() throws {
    let (timer, clock) = makeTimer()
    timer.start()
    clock.time += 30
    let snap = timer.snapshot()
    try check(abs(snap.remaining - 70) < 0.001, "remaining")
    try check(abs(snap.elapsed - 30) < 0.001, "elapsed")
    try check(abs(snap.progress - 0.3) < 0.001, "progress")
    try checkFalse(snap.finished)
}

func testPauseFreezesCountdown() throws {
    let (timer, clock) = makeTimer()
    timer.start()
    clock.time += 20
    try checkTrue(timer.togglePause())
    clock.time += 50
    let snap = timer.snapshot()
    try checkTrue(snap.isPaused)
    try check(abs(snap.remaining - 80) < 0.001, "remaining")
    try check(abs(snap.elapsed - 20) < 0.001, "elapsed")
}

func testResumeContinuesFromWherePaused() throws {
    let (timer, clock) = makeTimer()
    timer.start()
    clock.time += 20
    _ = timer.togglePause()
    clock.time += 50
    try checkFalse(timer.togglePause())   // resume
    clock.time += 10
    let snap = timer.snapshot()
    try checkFalse(snap.isPaused)
    try check(abs(snap.remaining - 70) < 0.001, "remaining")
    try check(abs(snap.elapsed - 30) < 0.001, "elapsed")
}

func testMultiplePauseCycles() throws {
    let (timer, clock) = makeTimer(total: 1000)
    timer.start()
    clock.time += 100
    _ = timer.togglePause()
    clock.time += 200
    _ = timer.togglePause()
    clock.time += 100
    _ = timer.togglePause()
    clock.time += 100
    _ = timer.togglePause()
    clock.time += 50
    let snap = timer.snapshot()
    // elapsed = 100 + 100 + 50 = 250; paused 200+100 = 300 excluded
    try check(abs(snap.elapsed - 250) < 0.001, "elapsed")
    try check(abs(snap.remaining - 750) < 0.001, "remaining")
}

func testFinished() throws {
    let (timer, clock) = makeTimer(total: 10)
    timer.start()
    clock.time += 10
    let snap = timer.snapshot()
    try checkTrue(snap.finished)
    try check(abs(snap.remaining - 0) < 0.001, "remaining")
    try check(abs(snap.progress - 1.0) < 0.001, "progress")
}

func testFinishDuringPauseStillFinishedByElapsedTime() throws {
    let (timer, clock) = makeTimer(total: 10)
    timer.start()
    clock.time += 10
    _ = timer.togglePause()
    clock.time += 999
    let snap = timer.snapshot()
    try checkTrue(snap.finished)
}

func testCancelFlag() throws {
    let (timer, _) = makeTimer()
    try checkFalse(timer.isCancelled)
    timer.cancel()
    try checkTrue(timer.isCancelled)
}

func testStartIsIdempotent() throws {
    let (timer, clock) = makeTimer()
    timer.start()
    clock.time += 5
    timer.start()
    clock.time += 5
    let snap = timer.snapshot()
    try check(abs(snap.elapsed - 10) < 0.001, "elapsed")
}
