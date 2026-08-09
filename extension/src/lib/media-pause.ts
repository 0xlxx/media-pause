import { execFile, spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

/**
 * Locate the media-pause binary WITHOUT relying on PATH (Raycast runs
 * extensions with a minimal PATH). ~/bin is preferred over Homebrew's stale
 * v3 install. Set MEDIA_PAUSE_REPO to the repo root to also probe its
 * .build/ output (handy during development).
 */
function candidates(): string[] {
  const home = homedir();
  const list = [
    join(home, "bin", "media-pause"),
    join(home, ".local", "bin", "media-pause"),
    "/usr/local/bin/media-pause",
    "/opt/homebrew/bin/media-pause",
  ];
  const repo = process.env.MEDIA_PAUSE_REPO;
  if (repo) {
    list.push(join(repo, ".build", "release", "media-pause"));
    list.push(join(repo, ".build", "debug", "media-pause"));
  }
  return list;
}

export function findBinary(): string | undefined {
  return candidates().find((path) => existsSync(path));
}

export class BinaryNotFoundError extends Error {}

export function requireBinary(): string {
  const bin = findBinary();
  if (!bin) {
    throw new BinaryNotFoundError(
      "media-pause 未安装。请先构建: cd media-pause && swift build -c release && ln -sf \"$PWD/.build/release/media-pause\" ~/bin/media-pause",
    );
  }
  return bin;
}

export interface RunResult {
  code: number;
  stdout: string;
  stderr: string;
}

/** Runs media-pause and resolves when the process exits. */
export function runMediaPause(args: string[], timeoutMs = 60_000): Promise<RunResult> {
  return new Promise((resolve) => {
    const bin = requireBinary();
    execFile(bin, args, { timeout: timeoutMs, maxBuffer: 8 * 1024 * 1024 }, (error, stdout, stderr) => {
      let code = 0;
      if (error) {
        const err = error as NodeJS.ErrnoException & { code?: number | string };
        code = typeof err.code === "number" ? err.code : 1;
      }
      resolve({ code, stdout, stderr });
    });
  });
}

/** Launches a detached background countdown (writes /tmp timer state). */
export function startBackgroundTimer(args: string[]): void {
  const bin = requireBinary();
  const child = spawn(bin, args, { detached: true, stdio: "ignore" });
  child.unref();
}
