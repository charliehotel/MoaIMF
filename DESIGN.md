# MoaIMF Design System

## 1. Atmosphere & Identity

MoaIMF is quiet, trustworthy, native, and reversible. It must feel like a macOS system utility rather than a dashboard or branded web app. Its signature is explicit operational state: every action and warning says what is happening, what was not changed, and why.

## 2. Color

- Use SwiftUI semantic system colors only: `primary`, `secondary`, `accentColor`, green, orange, red, and separator.
- Green means actively watching, orange means paused or disconnected, and red means an unresolved collision or permission failure.
- Never rely on color without a matching SF Symbol and text label.
- Respect light mode, dark mode, and Increase Contrast without custom color overrides.

## 3. Typography

- Use SF Pro through SwiftUI system text styles; never bundle a custom font.
- Menu title: `headline`.
- Primary status: `body` with semibold emphasis.
- Paths and timestamps: `caption`; use monospaced digits only where alignment matters.
- Destructive and warning copy remains plain and specific.
- Support Dynamic Type and avoid fixed font sizes.

## 4. Spacing & Layout

- Base spacing unit: 8 points.
- Compact row gaps: 4 points; section gaps: 16 points; window padding: 20 points.
- Use system control sizes, alignment guides, and system corner radii.
- Do not place every section in a card. Prefer native lists, groups, dividers, and window chrome.
- Settings content must remain usable with keyboard focus and enlarged text.

## 5. Components

- `MenuBarExtra` uses menu style for status and frequent commands.
- The menu includes an About MoaIMF command that opens a concise native window with app identity,
  version/build, local-only filename-normalization description, and copyright.
- The menu includes an in-app language selector for System Default, English, and Korean. Manual
  language selection updates menu labels and About copy without requiring a macOS language change.
- The menu bar label repeats the four user-provided Hangul composition frames in `ㅎ`, `ㅏ`,
  `ㄴ`, `한` order while watching, holding each frame for 1.5 seconds. When watching is paused,
  the animation stops and holds `han_frame_0`. The source PNGs remain template images so macOS
  controls their menu-bar contrast.
- Settings uses a native list with folder icon, name, path, status, and per-folder actions.
- Folder-level scans must leave visible feedback in the row: scanned item count, NFC and NFD
  counts, actionable normalization candidates, collisions, deferred items, timestamp, and the first
  few candidate names when work remains.
- The menu status summary uses a stable label plus count, such as `Files fixed: 6` or
  `수정된 파일: 6`; it must open History scoped to today's renamed items rather than forcing users
  to inspect the full log.
- History opens on today's entries by default. Its header includes a concise title, dynamic result
  summary, a primary date-scope segmented control, a lower-emphasis type filter, and a native search
  field before the log list. Search narrows the already scoped/type-filtered results by localized
  title, reason, root, and previous/resulting file paths, treating NFC/NFD spelling variants as the
  same user-visible query.
- The login-at-launch menu control pairs the toggle with a visible registration status label, so
  the user can tell whether the login item is registered, disabled, unavailable, or waiting for
  System Settings approval.
- Plus and minus buttons follow the standard macOS list editing pattern.
- Alerts state what was not changed and why; safe, non-mutating scans require no confirmation.
- Status mapping:
  - Watching: `checkmark.circle` plus visible text.
  - Scanning: `arrow.triangle.2.circlepath` plus visible text.
  - Paused: `pause.circle` plus visible text.
  - Attention: `exclamationmark.triangle` plus visible text.
- Empty, loading, permission, disconnected-volume, collision, and unsupported-filesystem states each require visible text.

## 6. Motion & Interaction

- Prefer native SwiftUI transitions and control feedback.
- Respect Reduce Motion; no operation depends on animation to communicate state.
- Every action is keyboard reachable and exposes an accessibility label when its visible label is insufficient.
- Destructive actions use the system destructive role and never rely on icon color alone.

## 7. Depth & Surface

- Use native window, menu, popover, list, and material surfaces.
- Separate content with spacing, list sections, and system separators before adding elevation.
- Avoid decorative shadows, gradients, glass effects, and custom corner-radius stacks.
- Native focus rings, selection treatments, and disabled states remain visible.
