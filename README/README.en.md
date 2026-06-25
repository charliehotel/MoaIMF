| [🇰🇷 한국어](README.md) | [🇺🇸 English](README.en.md) | [🇯🇵 日本語](README.ja.md) | [🇨🇳 简体中文](README.zh-Hans.md) | [🇹🇼 繁體中文](README.zh-Hant.md) | [🇻🇳 Tiếng Việt](README.vi.md) | [🇫🇷 Français](README.fr.md) | [🇩🇪 Deutsch](README.de.md) | [🇪🇸 Español](README.es.md) | [🇵🇹 Português](README.pt.md) | [🇹🇭 ไทย](README.th.md) | [🇸🇦 العربية](README.ar.md) |
|---|---|---|---|---|---|---|---|---|---|---|---|

<p align="center">
  <img src="../Assets.xcassets/MoaIMF_icon.png" width="128" height="128" alt="MoaIMF icon">
</p>

<h1 align="center">MoaIMF</h1>

<p align="center">
  <strong>Initial. Medial. Final. Composed.</strong><br>
  A macOS menu bar app that safely normalizes decomposed Unicode filenames to NFC composed names
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#usage">Usage</a> ·
  <a href="#installation-and-build">Installation and Build</a> ·
  <a href="#safety-and-privacy">Safety</a> ·
  <a href="#development">Development</a>
</p>

## Introduction

MoaIMF is a macOS menu bar app that normalizes file and folder names in user-selected folders to Unicode NFC. The name refers to combining the initial, medial, and final components of a Hangul syllable into its composed form.

On macOS, Korean filenames can be stored in a decomposed form similar to NFD after passing through file systems, apps, download tools, archive extractors, external drives, NAS devices, or cloud sync tools. In those cases, Finder may show a file as `한글.txt`, while Alfred, terminal search, and some automation scripts may see it as `ㅎㅏㄴㄱㅡㄹ.txt` and fail to find it.

MoaIMF does not treat this as a one-time cleanup script problem. It is a local-only utility that continuously monitors user-approved folders and fixes filename issues in newly created or downloaded files.

## Screenshots

This is the main menu bar app screen. While folder monitoring is active, the menu bar icon cycles through `ㅎ`, `ㅏ`, `ㄴ`, and `한`. When monitoring is paused, the icon stops at `ㅎ`.

<table>
  <tr>
    <td align="center" width="50%">
      <kbd><img src="../Screenshots/MoaIMF_main_ko.gif" alt="MoaIMF Korean menu bar animation" width="100%"></kbd>
    </td>
    <td align="center" width="50%">
      <kbd><img src="../Screenshots/MoaIMF_main_en.png" alt="MoaIMF English menu bar screen" width="100%"></kbd>
    </td>
  </tr>
</table>

### Watched Folder Settings

<kbd><img src="../Screenshots/MoaIMF_monitoring_folders_en.png" alt="Monitoring folders" width="100%"></kbd>

Watched folder settings start with `Downloads` as the default folder. You can add or remove watched folders with the `+` and `-` buttons. Each folder can be enabled or disabled independently, and folders with broken permissions can be selected again.

Pressing `Scan Now` for a folder immediately scans that folder. The scan result shows NFC items, NFD candidates, conflicts, and pending items, so you can see exactly what was checked.

### Download Stability Exceptions

<kbd><img src="../Screenshots/MoaIMF_exceptions_en.png" alt="Download stability exceptions" width="100%"></kbd>

Files that are still downloading may not have their final names yet, or their file size and modification time may still be changing. MoaIMF provides built-in locked rules for patterns such as `.crdownload`, `.download`, `.part`, `.partial`, and `.tmp`, and lets users add their own exception rules.

Supported custom rules are:

- Exact filename
- Suffix or extension
- `*` and `?` globs for the last path component

Items matched by an exception rule are not processed until the rule is removed or the item disappears. Parent folders containing exception items are also held back so that a folder still involved in a download is not renamed too early.

### Recent History

<kbd><img src="../Screenshots/MoaIMF_recent_history_en.png" alt="Recent history" width="100%"></kbd>

Recent history can be viewed by today, 7 days, 30 days, or all time, and filtered by rename, conflict, permission, or error events. The search field looks at file paths, processing reasons, event titles, and root identifiers. It also compares normalized variants so that NFC/NFD spelling differences are treated as the same user input.

History is stored as a local JSONL file.

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/history.jsonl
```

History is kept for 30 days by default. Old entries past the retention period are cleaned up when new history is added.

### About

<kbd><img src="../Screenshots/MoaIMF_about_en.png" alt="About MoaIMF" width="100%"></kbd>

The About window shows the app name, version, short description, and copyright notice. The image at the top illustrates decomposed jamo being combined into a composed character, as in `ㅎㅏㄴ -> 한`.

## Features

- Check watching status from the menu bar, pause, resume, and quit
- Use Downloads as the default watched location
- Add and remove multiple watched folders with `+` and `-`
- Recursively scan watched folders and their subfolders
- Access only folders selected by the user through security-scoped bookmarks
- Detect new files and changed paths with FSEvents
- Process files only after file size and modification time have stabilized
- Hold back partial downloads and user-defined exception rules
- Normalize file and folder names to Unicode NFC
- Never overwrite automatically when a conflict is possible
- Use a recoverable temporary-name strategy if direct rename verification fails
- Store rename, conflict, permission, disconnected, and filesystem error events in recent history
- Show the number of files renamed today and link to recent history
- Show a first-run hint for finding the menu bar icon
- Show login-at-launch registration status
- Support in-app language selection
- No external server communication, account login, or telemetry

## How It Works

MoaIMF does not change file contents. It only handles the Unicode normalization form of file and folder names.

The processing flow is:

1. The user selects a folder to watch.
2. The app stores folder access permission as a security-scoped bookmark.
3. FSEvents reports changes such as new files, new folders, renames, and completed downloads.
4. The scan service checks the path and its child items.
5. It checks exception rules, packages, symbolic link targets, permission issues, and file stability.
6. When it finds a non-NFC name such as an NFD name, it calculates the NFC target name.
7. It checks whether another item in the same folder would have the same name after normalization.
8. Only stable items without conflicts become rename candidates.
9. Right before renaming, it verifies file identity again and performs the rename.
10. After renaming, it verifies that the actual filename is preserved as NFC bytes.
11. It stores the result in recent history and updates today's rename count in the menu.

Because of this structure, MoaIMF does not arbitrarily merge files that might conflict, and it does not automatically create names such as `-1`, `copy`, or `복사본`. Cases that require user judgment are left in recent history and notifications.

## Usage

### 1. Launch the App

When you launch `MoaIMF.app`, it does not stay in the Dock like a regular app. Instead, an icon appears in the menu bar. If the menu bar has many icons or the icon may be hidden behind the MacBook notch, MoaIMF shows a first-run hint window.

### 2. Configure Watched Folders

Open `Watched Folder Settings...` from the menu. The default folder is Downloads. Add other folders with the `+` button if needed.

Recommended usage:

- Add locations where new files are often created, such as the Downloads folder.
- Add sensitive locations such as project source folders, photo libraries, or app bundles only when necessary.
- Test external drives or NAS sync folders with a small number of files first.

### 3. Choose How to Handle Existing Items

When adding a folder for the first time, choose whether to normalize existing items immediately or only watch new items from that point on.

- `Normalize Existing Items`: scans existing Non-NFC names in the current folder and renames approved candidates.
- `Watch New Items Only`: leaves existing filenames unchanged and processes only newly created or changed items afterward.

For folders with many existing files, it is safer to inspect the scan result before processing.

### 4. Pause and Resume

Selecting `Pause Watching` stops watching and automatic renaming. Settings, history, and the folder list remain intact. While paused, the menu bar icon animation also stops and shows the initial frame.

Select `Resume Watching` to start processing again.

### 5. Scan Now

`Scan All Now` scans all registered watched folders again. The `Scan Now` button in each row of the watched folder settings scans only that folder.

Manual scans are useful when:

- Files were added while the app was not running
- An external drive was reconnected
- You changed exception rules and want to check pending items again
- You want to compare recent history with the actual folder state

### 6. Change Language

Choose the app display language directly from `Language` in the menu. The currently available manual language choices are:

- System Default
- English
- Korean
- Japanese
- Simplified Chinese
- Traditional Chinese
- Vietnamese
- French
- German
- Spanish
- Portuguese
- Thai
- Arabic

The provided languages are AI translations for convenience. If you find an incorrect translation or want another language to be added, please let us know through `Issues`.

### 7. Launch at Login

Turn on `Launch at Login` from the menu to register MoaIMF as a macOS login item. The menu also shows whether it is currently registered. If macOS requires user approval, open System Settings and approve it there.

### 8. Quit

Selecting `Quit MoaIMF` cleans up monitoring tasks and security-scoped access, then quits the app. It does not leave a separate daemon or helper process behind.

## Installation and Build

MoaIMF currently assumes source-based installation. A Developer ID signed and Apple-notarized distribution package is not provided yet.

### Requirements

- macOS 13 Ventura or later
- Xcode 16 or compatible Xcode Command Line Tools
- Swift 6 toolchain
- Git

The build scripts also use standard macOS tools:

- `swift`
- `xcrun swift-format`
- `sips`
- `python3`
- `codesign`
- `ditto`

At runtime, MoaIMF does not require a separate server, database, or network API.

### Clone the Repository

```sh
git clone https://github.com/charliehotel/MoaIMF.git
cd MoaIMF
```

The repository URL may be adjusted to match the actual public location.

### Check and Build

Run the full checks, tests, and app bundle build with:

```sh
scripts/check.sh
```

To build only the app bundle:

```sh
scripts/build-app.sh
```

The generated app is created at:

```text
.build/MoaIMF.app
```

To run it locally:

```sh
open .build/MoaIMF.app
```

The app created by `scripts/build-app.sh` is an ad-hoc signed app for local testing. To distribute it to other Macs, configure Developer ID signing and notarization separately.

## Local Data Location

MoaIMF stores app state and history in Application Support inside the macOS app sandbox container.

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/
```

`<app bundle identifier>` depends on the bundle identifier included in the installed app build.

Main files:

| File | Description |
|---|---|
| `watched-folders.json` | Monitored folder list, enabled state, and security-scoped bookmarks |
| `stability-rules.json` | Built-in download stability rules and custom exception rules |
| `history.jsonl` | Recent processing history |
| `recovery/` | Journal used to recover from failures during rename operations |

Some app settings are also stored in `UserDefaults`, such as pause state, language selection, and whether the first-run hint is hidden.

## Safety and Privacy

MoaIMF's basic principle is: safely change only names, and stop when unsure.

- It does not read or modify file contents.
- It accesses only folders selected by the user.
- It follows the macOS permission model through security-scoped bookmarks.
- It does not scan inside packages such as `.app`, `.bundle`, `.framework`, or `.photoslibrary`.
- It does not follow symbolic link targets.
- It does not rename when sibling items would have the same name after normalization.
- It verifies file identity before and after renaming.
- If the filesystem does not preserve the verified NFC name, it records the situation as an error.
- All processing happens locally.
- There is no network communication, account login, analytics event, or telemetry.

## Limitations

- MoaIMF does not change how macOS stores filenames system-wide.
- It does not force every app to save filenames as NFC.
- It does not automatically merge conflicting files or resolve them with new names.
- It does not rebuild Spotlight or Alfred indexes directly.
- If a filesystem, sync tool, or external storage device rewrites filename bytes again, the app cannot automatically recover every case.
- It currently focuses on source builds and local testing app bundles.
- Automatic updates, App Store distribution, and notarized DMG distribution are not available yet.

## Uninstall

1. Turn off `Launch at Login` from the menu.
2. Select `Quit MoaIMF` from the menu.
3. Delete the installed `MoaIMF.app`.
4. To remove local state as well, delete the MoaIMF Application Support folder inside the app container.

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/
```

`<app bundle identifier>` depends on the bundle identifier included in the installed app build.

This does not revert filenames that were already changed to NFC back to NFD.

## Development

The project is based on Swift Package Manager.

```text
Sources/
  MoaIMFCore/   normalization, scanning, monitoring, stores, safe rename engine
  MoaIMFUI/     AppController, menu, settings, history, About, localization
  MoaIMFApp/    macOS app entry point and menu bar label
Tests/
  MoaIMFCoreTests/
  MoaIMFUITests/
```

Common commands:

```sh
xcrun swift-format lint --strict --recursive Sources Tests Package.swift
swift test
swift build
scripts/build-app.sh
```

To reduce sandbox or cache permission issues, use `scripts/check.sh`. The script places SwiftPM and module caches under `.build/`.

See these design documents:

- [v0.1 design spec](../docs/superpowers/specs/2026-06-21-moaimf-v0.1-design.md)
- [v0.1 implementation plan](../docs/superpowers/plans/2026-06-21-moaimf-v0.1.md)
- [Contributing guide](../CONTRIBUTING.md)
- [Security policy](../SECURITY.md)

## License

MoaIMF is distributed under the [MIT License](../LICENSE).
