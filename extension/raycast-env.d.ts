/// <reference types="@raycast/api">

/* 🚧 🚧 🚧
 * This file is auto-generated from the extension's manifest.
 * Do not modify manually. Instead, update the `package.json` file.
 * 🚧 🚧 🚧 */

/* eslint-disable @typescript-eslint/ban-types */

type ExtensionPreferences = {}

/** Preferences accessible in all the extension's commands */
declare type Preferences = ExtensionPreferences

declare namespace Preferences {
  /** Preferences accessible in the `pause-media` command */
  export type PauseMedia = ExtensionPreferences & {}
  /** Preferences accessible in the `resume-media` command */
  export type ResumeMedia = ExtensionPreferences & {}
  /** Preferences accessible in the `mute-tabs` command */
  export type MuteTabs = ExtensionPreferences & {}
  /** Preferences accessible in the `quit-browser` command */
  export type QuitBrowser = ExtensionPreferences & {}
  /** Preferences accessible in the `timer-status` command */
  export type TimerStatus = ExtensionPreferences & {}
  /** Preferences accessible in the `timer-stop` command */
  export type TimerStop = ExtensionPreferences & {}
}

declare namespace Arguments {
  /** Arguments passed to the `pause-media` command */
  export type PauseMedia = {
  /** Duration (e.g. 30m), empty = now */
  "duration": string,
  /** Browser */
  "browser": "chrome" | "brave" | "edge" | "arc" | "chromium" | "opera" | "vivaldi" | "all"
}
  /** Arguments passed to the `resume-media` command */
  export type ResumeMedia = {
  /** Duration (e.g. 10s), empty = resume now */
  "duration": string,
  /** Browser */
  "browser": "chrome" | "brave" | "edge" | "arc" | "chromium" | "opera" | "vivaldi" | "all"
}
  /** Arguments passed to the `mute-tabs` command */
  export type MuteTabs = {
  /** Duration (e.g. 30m), empty = now */
  "duration": string,
  /** Browser */
  "browser": "chrome" | "brave" | "edge" | "arc" | "chromium" | "opera" | "vivaldi" | "all"
}
  /** Arguments passed to the `quit-browser` command */
  export type QuitBrowser = {
  /** Duration (e.g. 1h), empty = now */
  "duration": string,
  /** Browser */
  "browser": "chrome" | "brave" | "edge" | "arc" | "chromium" | "opera" | "vivaldi" | "all"
}
  /** Arguments passed to the `timer-status` command */
  export type TimerStatus = {}
  /** Arguments passed to the `timer-stop` command */
  export type TimerStop = {}
}

