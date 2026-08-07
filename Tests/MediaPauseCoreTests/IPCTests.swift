@testable import MediaPauseCore
import Foundation

func testTimerStatusRoundtrip() throws {
    let status = TimerStatus(startTs: 1_700_000_000, totalSeconds: 1800, mode: "pause", label: "Chrome, Brave", instanceID: "abc-123")
    try checkEqual(TimerStatus.decode(status.encode()), status)
}

func testTimerStatusDecodeLabelWithSpaces() throws {
    let raw = "1700000000 3600 mute 2 browsers inst-1"
    let status = try checkNotNil(TimerStatus.decode(raw))
    try checkEqual(status.startTs, 1_700_000_000)
    try checkEqual(status.totalSeconds, 3600)
    try checkEqual(status.mode, "mute")
    try checkEqual(status.label, "2 browsers")
    try checkEqual(status.instanceID, "inst-1")
}

func testTimerStatusDecodeMalformed() throws {
    try checkNil(TimerStatus.decode(""))
    try checkNil(TimerStatus.decode("1700000000"))
    try checkNil(TimerStatus.decode("abc 3600 pause label inst"))
    try checkNil(TimerStatus.decode("1700000000 abc pause label inst"))
    try checkNil(TimerStatus.decode("1700000000 3600 pause"))
}

func testPidRecordRoundtrip() throws {
    let record = PidRecord(pid: 42, instanceID: "inst-9")
    try checkEqual(PidRecord.decode(record.encode()), record)
}

func testPidRecordDecodeMalformed() throws {
    try checkNil(PidRecord.decode(""))
    try checkNil(PidRecord.decode("42"))
    try checkNil(PidRecord.decode("abc inst"))
}

func testTimerStateStoreLifecycle() throws {
    try withTempDir { dir in
        let store = TimerStateStore(paths: TimerStatePaths(
            pidPath: dir.appendingPathComponent("pid").path,
            statusPath: dir.appendingPathComponent("status").path,
            lastResultPath: dir.appendingPathComponent("last").path
        ), instanceID: "test-instance")

        let status = TimerStatus(startTs: 1, totalSeconds: 60, mode: "pause", label: "Chrome", instanceID: "test-instance")
        store.start(pid: 123, status: status)

        try checkEqual(store.readPid(), PidRecord(pid: 123, instanceID: "test-instance"))
        try checkEqual(store.readStatus(), status)

        let pidRaw = try String(contentsOfFile: store.paths.pidPath, encoding: .utf8)
        try checkEqual(pidRaw, "123 test-instance")
        let statusRaw = try String(contentsOfFile: store.paths.statusPath, encoding: .utf8)
        try checkEqual(statusRaw, "1 60 pause Chrome test-instance")

        store.writeLastResult("SUCCESS OK js:Chrome")
        let lastRaw = try String(contentsOfFile: store.paths.lastResultPath, encoding: .utf8)
        try checkEqual(lastRaw, "SUCCESS OK js:Chrome")

        store.clear()
        try checkNil(store.readPid())
        try checkNil(store.readStatus())
        try checkFalse(FileManager.default.fileExists(atPath: store.paths.pidPath))
        try checkFalse(FileManager.default.fileExists(atPath: store.paths.statusPath))
    }
}

func testInstanceIDUniqueness() throws {
    try checkTrue(TimerStateStore.makeInstanceID() != TimerStateStore.makeInstanceID())
}
