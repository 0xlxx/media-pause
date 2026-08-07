#!/usr/bin/env python3
"""Custom mutation testing runner (no Xcode/XCTest needed).

Applies one source mutation at a time to a throwaway copy of the package,
runs the unit-test executable, and reports which mutants were killed by the
tests (compile errors count as killed) and which survived.

Usage: python3 scripts/mutate.py [--keep]
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = tempfile.mkdtemp(prefix="media-pause-mut-")


def run(cmd, cwd=None, timeout=180):
    return subprocess.run(cmd, shell=True, cwd=cwd,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                          timeout=timeout)


def setup_workspace():
    shutil.copytree(os.path.join(ROOT, "Sources", "MediaPauseCore"),
                    os.path.join(WORK, "Sources", "MediaPauseCore"))
    shutil.copytree(os.path.join(ROOT, "Sources", "media-pause"),
                    os.path.join(WORK, "Sources", "media-pause"))
    shutil.copytree(os.path.join(ROOT, "Tests", "MediaPauseCoreTests"),
                    os.path.join(WORK, "Tests", "MediaPauseCoreTests"))
    shutil.copy(os.path.join(ROOT, "Package.swift"), WORK)


# (name, file, old, new)
MUTATIONS = [
    # Duration
    ("duration: seconds guard > 0 -> >= 0", "Duration.swift",
     "guard seconds > 0 else", "guard seconds >= 0 else"),
    ("duration: total > 0 -> >= 0", "Duration.swift",
     "guard matched, total > 0, remaining.isEmpty", "guard matched, total >= 0, remaining.isEmpty"),
    ("duration: max(0, seconds) removed", "Duration.swift",
     "let s = max(0, seconds)", "let s = seconds"),
    ("duration: empty guard inverted", "Duration.swift",
     "guard !trimmed.isEmpty else", "guard trimmed.isEmpty else"),
    # Arguments
    ("args: -b bound < -> <=", "Arguments.swift",
     "guard i < args.count else { return .failure(ArgumentError(\"-b requires a browser name\")) }",
     "guard i <= args.count else { return .failure(ArgumentError(\"-b requires a browser name\")) }"),
    ("args: duration nil check != nil", "Arguments.swift",
     "guard duration == nil else", "guard duration != nil else"),
    ("args: unknown option prefix negated", "Arguments.swift",
     "if arg.hasPrefix(\"-\")", "if !arg.hasPrefix(\"-\")"),
    # Browser
    ("browser: token all == -> !=", "Browser.swift",
     "if token == \"all\"", "if token != \"all\""),
    ("browser: empty guard inverted", "Browser.swift",
     "guard !trimmed.isEmpty else { return nil }", "guard trimmed.isEmpty else { return nil }"),
    ("browser: dedupe condition negated", "Browser.swift",
     "if seen.insert(b.key).inserted { result.append(b) }",
     "if !seen.insert(b.key).inserted { result.append(b) }"),
    # MediaJS
    ("mediajs: ERR skip negated", "MediaJS.swift",
     "where !part.contains(\"ERR\")", "where part.contains(\"ERR\")"),
    ("mediajs: kv.count == 2 -> != 2", "MediaJS.swift",
     "if kv.count == 2 {", "if kv.count != 2 {"),
    # Engine
    ("engine: success flag negated", "Channels.swift",
     "if result.ok { anySuccess = true }", "if !result.ok { anySuccess = true }"),
    ("engine: fallback fires on success", "Channels.swift",
     "if !anySuccess, let fallback {", "if anySuccess, let fallback {"),
    ("engine: honest failure on success", "Channels.swift",
     "if !anySuccess {\n            results.append(ChannelResult(",
     "if anySuccess {\n            results.append(ChannelResult("),
    ("engine: anySuccess inverted", "Channels.swift",
     "results.contains { $0.ok }", "results.contains { !$0.ok }"),
    # AppleScript channel
    ("js: ERR check && -> ||", "AppleScriptChannel.swift",
     "if out.contains(\"ERR\") && !out.contains(\":\")",
     "if out.contains(\"ERR\") || !out.contains(\":\")"),
    ("js: affected > 0 -> >= 0", "AppleScriptChannel.swift",
     "if affected > 0 {", "if affected >= 0 {"),
    ("js: probe && -> ||", "AppleScriptChannel.swift",
     "return out.contains(\"2\") && !out.contains(\"ERR\")",
     "return out.contains(\"2\") || !out.contains(\"ERR\")"),
    ("js: script if/else -> is not", "AppleScriptChannel.swift",
     "if acc is \"\" then", "if acc is not \"\" then"),
    ("js: probe 1+1 -> 1+2", "AppleScriptChannel.swift",
     "javascript \"1+1\"", "javascript \"1+2\""),
    ("mute: ok muted > 0 -> >= 0", "AppleScriptChannel.swift",
     "ok: muted > 0", "ok: muted >= 0"),
    # CDP
    ("cdp: page filter == -> !=", "CDPChannel.swift",
     ".filter { $0.type == \"page\" }", ".filter { $0.type != \"page\" }"),
    ("cdp: affected += -> -=", "CDPChannel.swift",
     "affected += MediaJS.parseCounters(value).affected",
     "affected -= MediaJS.parseCounters(value).affected"),
    ("cdp: affected > 0 -> >= 0", "CDPChannel.swift",
     "if affected > 0 {", "if affected >= 0 {"),
    ("cdp: parseEvaluateValue outer missing", "CDPChannel.swift",
     "guard let outer = message[\"result\"] as? [String: Any],",
     "guard let outer = message[\"id\"] as? [String: Any],"),
    # CountdownTimer
    ("timer: elapsed clamp removed", "CountdownTimer.swift",
     "let elapsed = max(0, now - startAt - pausedTime)",
     "let elapsed = now - startAt - pausedTime"),
    ("timer: remaining clamp removed", "CountdownTimer.swift",
     "let remaining = max(0, total - elapsed)",
     "let remaining = total - elapsed"),
    ("timer: finished <= -> <", "CountdownTimer.swift",
     "finished: remaining <= 0", "finished: remaining < 0"),
    ("timer: accumulatedPause += -> -=", "CountdownTimer.swift",
     "accumulatedPause += clock.now() - pauseStartedAt",
     "accumulatedPause -= clock.now() - pauseStartedAt"),
    ("timer: pausedTime += -> -=", "CountdownTimer.swift",
     "pausedTime += now - pauseStartedAt", "pausedTime -= now - pauseStartedAt"),
    ("timer: progress min -> max", "CountdownTimer.swift",
     "progress: total > 0 ? min(elapsed / total, 1.0) : 1.0",
     "progress: total > 0 ? max(elapsed / total, 1.0) : 1.0"),
    # IPC
    ("ipc: status parts >= 5 -> > 5", "IPC.swift",
     "guard parts.count >= 5,", "guard parts.count > 5,"),
    ("ipc: pid parts >= 2 -> > 2", "IPC.swift",
     "guard parts.count >= 2, let pid = Int32(parts[0])",
     "guard parts.count > 2, let pid = Int32(parts[0])"),
    ("ipc: label slice end removed", "IPC.swift",
     "let label = parts[3..<(parts.count - 1)].joined(separator: \" \")",
     "let label = parts[3...].joined(separator: \" \")"),
    # Setup
    ("setup: already-enabled check != true", "Setup.swift",
     "as? Bool == true { continue }", "as? Bool != true { continue }"),
    ("setup: profile filter || -> &&", "Setup.swift",
     "items.filter { $0 == \"Default\" || $0.hasPrefix(\"Profile\") }",
     "items.filter { $0 == \"Default\" && $0.hasPrefix(\"Profile\") }"),
    # Report
    ("report: summary SUCCESS/FAILED swapped", "Report.swift",
     "\"\\\\(ok ? \\\"SUCCESS\\\" : \\\"FAILED\\\") \\(detail)\"",
     "\"\\\\(ok ? \\\"FAILED\\\" : \\\"SUCCESS\\\") \\(detail)\""),
    ("report: js line ok negated", "Report.swift",
     "case \"cdp\", \"js\":\n            if result.ok {", "case \"cdp\", \"js\":\n            if !result.ok {"),
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--keep", action="store_true", help="keep workspace")
    args = parser.parse_args()

    setup_workspace()
    print(f"workspace: {WORK}")

    baseline = run("swift run media-pause-tests", cwd=WORK)
    if baseline.returncode != 0:
        print("BASELINE TESTS FAILED")
        print(baseline.stdout[-4000:])
        sys.exit(1)
    print(f"baseline: {baseline.stdout.strip().splitlines()[-1]}")

    killed, survived, skipped = [], [], []
    for name, rel, old, new in MUTATIONS:
        path = os.path.join(WORK, "Sources", "MediaPauseCore", rel)
        src = open(path).read()
        if old not in src:
            skipped.append(name)
            continue
        open(path, "w").write(src.replace(old, new))
        result = run("swift run media-pause-tests", cwd=WORK)
        open(path, "w").write(src)
        if result.returncode == 0:
            survived.append(name)
            print(f"SURVIVED  {name}")
        else:
            killed.append(name)
            print(f"killed    {name}")

    print("")
    print(f"mutants: {len(killed) + len(survived) + len(skipped)} "
          f"(killed {len(killed)}, survived {len(survived)}, skipped {len(skipped)})")
    if survived:
        print("SURVIVED:")
        for s in survived:
            print(f"  - {s}")
    rate = len(killed) / max(1, len(killed) + len(survived)) * 100
    print(f"kill rate: {rate:.1f}%")
    if not args.keep:
        shutil.rmtree(WORK, ignore_errors=True)


if __name__ == "__main__":
    main()
