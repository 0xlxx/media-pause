import Foundation

/// Registry of all tests. Each entry is (name, closure).
/// The runner reports PASS/FAIL and exits non-zero on any failure.
let tests: [(String, () throws -> Void)] = [
    // Duration
    ("duration plain seconds", testDurationPlainSeconds),
    ("duration human formats", testDurationHumanFormats),
    ("duration whitespace tolerated", testDurationWhitespaceTolerated),
    ("duration invalid inputs", testDurationInvalidInputs),
    ("duration non-positive rejected", testDurationNonPositiveRejected),
    ("formatHMS", testFormatHMS),

    // Arguments
    ("special commands", testSpecialCommands),
    ("default action", testDefaultAction),
    ("duration positional", testDurationPositional),
    ("modes", testModes),
    ("now flag", testNowFlag),
    ("browser flags", testBrowserFlags),
    ("missing browser value fails", testMissingBrowserValueFails),
    ("unknown option fails", testUnknownOptionFails),
    ("duplicate duration fails", testDuplicateDurationFails),

    // Browser
    ("browser by key", testBrowserByKey),
    ("browser resolve single", testBrowserResolveSingle),
    ("browser resolve comma/dedupe", testBrowserResolveCommaAndDedupe),
    ("browser resolve all", testBrowserResolveAll),
    ("browser resolve unknown", testBrowserResolveUnknownReturnsNil),

    // MediaJS
    ("js expressions embeddable", testExpressionsAreAppleScriptEmbeddable),
    ("js action expression selection", testActionExpressionSelection),
    ("pause expression targets", testPauseExpressionTargetsMediaElements),
    ("resume expression targets", testResumeExpressionTargetsMarkedElements),
    ("parse counters simple", testParseCountersSimple),
    ("parse counters accumulated", testParseCountersAccumulated),
    ("parse counters skips errors", testParseCountersSkipsErrors),
    ("parse counters malformed", testParseCountersMalformedIgnored),
    ("parse counters empty", testParseCountersEmpty),

    // AppleScript
    ("probe script targets browser", testProbeScriptTargetsBrowser),
    ("action script embeds expression", testActionScriptEmbedsExpressionAndUsesMultilineIf),
    ("action script resume", testActionScriptResumeUsesResumeExpression),
    ("mute script", testMuteScript),
    ("probe enabled then pause succeeds", testProbeEnabledThenPauseSucceeds),
    ("probe disabled reports setup hint", testProbeDisabledReportsSetupHint),
    ("pause counts media elements", testPauseCountsMediaElements),
    ("resume counts", testResumeCounts),
    ("no media found is not success", testNoMediaFoundIsNotSuccess),
    ("javascript error reported", testJavaScriptErrorReported),
    ("probe cached", testProbeCached),
    ("mute succeeds", testMuteSucceeds),
    ("mute nothing muted", testMuteNothingMuted),
    ("mute failure surfaces error", testMuteFailureSurfacesError),

    // Engine
    ("first success stops fallback", testFirstSuccessStopsFallback),
    ("all fail then fallback fires", testAllFailThenFallbackFires),
    ("fallback fails appends honest failure", testFallbackFailsAppendsHonestFailure),
    ("no fallback appends honest failure", testNoFallbackAppendsHonestFailure),
    ("resume failure message", testResumeFailureMessage),
    ("all channels run", testAllChannelsRun),
    ("resume flag propagated", testResumeFlagPropagated),

    // Countdown timer
    ("before start shows full remaining", testBeforeStartShowsFullRemaining),
    ("progress advances", testProgressAdvances),
    ("pause freezes countdown", testPauseFreezesCountdown),
    ("resume continues from paused", testResumeContinuesFromWherePaused),
    ("multiple pause cycles", testMultiplePauseCycles),
    ("finished", testFinished),
    ("finish during pause", testFinishDuringPauseStillFinishedByElapsedTime),
    ("cancel flag", testCancelFlag),
    ("start is idempotent", testStartIsIdempotent),

    // CDP
    ("evaluate request shape", testEvaluateRequestShape),
    ("parse evaluate value", testParseEvaluateValue),
    ("parse evaluate value missing", testParseEvaluateValueMissing),
    ("parse targets", testParseTargets),
    ("parse targets invalid json", testParseTargetsInvalidJSON),
    ("first open port", testFirstOpenPort),
    ("cdp pauses across pages", testCDPPausesMediaAcrossPages),
    ("cdp resume uses resume expression", testCDPResumeUsesResumeExpression),
    ("cdp no targets fails", testCDPNoTargetsFails),
    ("cdp non-page targets ignored", testCDPNonPageTargetsIgnored),
    ("cdp no media found", testCDPNoMediaFoundIsNotSuccess),

    // IPC
    ("timer status roundtrip", testTimerStatusRoundtrip),
    ("timer status decode label with spaces", testTimerStatusDecodeLabelWithSpaces),
    ("timer status decode malformed", testTimerStatusDecodeMalformed),
    ("pid record roundtrip", testPidRecordRoundtrip),
    ("pid record decode malformed", testPidRecordDecodeMalformed),
    ("timer state store lifecycle", testTimerStateStoreLifecycle),
    ("instance id uniqueness", testInstanceIDUniqueness),

    // Setup
    ("preferences enable flag", testPreferencesEnablesFlagInAllProfiles),
    ("preferences already enabled skipped", testPreferencesAlreadyEnabledSkipped),
    ("preferences missing ignored", testPreferencesMissingIgnored),
    ("preferences nonexistent dir", testPreferencesNonexistentDirReturnsZero),
    ("preferences non-profile dirs ignored", testPreferencesNonProfileDirectoriesIgnored),
    ("custom user data dirs extraction", testCustomUserDataDirsExtraction),
    ("custom user data dirs empty", testCustomUserDataDirsNoChromeLines),
    ("automation args detection", testAutomationArgsDetection),

    // Report
    ("report title per mode", testReportTitlePerMode),
    ("report line formats", testReportLineFormats),
    ("report summary success", testReportSummarySuccess),
    ("report summary failure", testReportSummaryFailure),

    // Completion notification
    ("notification default off", testNotificationDefaultOff),
    ("notification flags", testNotificationFlags),
    ("notification titles", testNotificationTitles),
    ("notification bodies", testNotificationBodies),
    ("notification script", testNotificationScript),
    ("notification script escapes quotes", testNotificationScriptEscapesQuotes),
]

var failures: [String] = []
for (name, body) in tests {
    do {
        try body()
        print("PASS  \(name)")
    } catch {
        failures.append("\(name): \(error)")
        print("FAIL  \(name): \(error)")
    }
}

print("")
if failures.isEmpty {
    print("All \(tests.count) tests passed ✅")
    exit(0)
} else {
    print("\(failures.count) of \(tests.count) tests failed ❌")
    exit(1)
}
