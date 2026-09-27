# Verification — 2026-09-20

## Larger controls and Calendar permission recovery — 0.2.1

- Navigation targets: 44×44pt (previously 36×30); settings/collapse/playback/file/memo icon targets: at least 40×40pt. Text action buttons have a 40pt minimum height and 14pt labels.
- Visually inspected the enlarged navigation on the running Release app. Collapsed physical notch height remains unchanged; expanded modules reserve slightly more height for the controls.
- Found the Calendars entitlement absent from the previous bundle. Added com.apple.security.personal-information.calendars and verified it in the signed Release binary, with the full-access usage string retained.
- Permission flow now distinguishes undetermined, denied, restricted, write-only and full access; includes visible progress and a delayed explanation, error codes/retry, and a System Settings shortcut.
- System dialogs temporarily lower panel level and suspend outside-click collapse; app activation refreshes changed permissions. No system permission was granted/reset during testing.
- XCTest: 25 Core + 20 service/interaction tests = 45 passed. Added grant, denial, restriction, no-prompt response, retry after error, revoke/return, and write-only upgrade coverage using mock EventKit boundaries. Actual TCC consent remains for the user to grant.
- Apple reference: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.personal-information.calendars
- 0.2.1 DMG checksum and read-only mount: PASS. Mounted app version, signature, Calendars entitlement and Applications symlink verified before ejecting the test mount.

## Settings continuity and app icon — 0.2.0 / 2026-09-24

- AppSettings uses field-by-field backward-compatible decoding: preserve saved values; fill missing fields only. Wrong types still reject decoding.
- Existing narrow widths remain valid. Data directory, filenames and bundle ID stay stable across releases.
- Settings are copied byte-for-byte once before a new build's first write; subsequent writes/restarts preserve this backup.
- Tests cover legacy partial settings, unknown keys, wrong types, update + editing + relaunch with preserved values/backup, and damaged file preservation.
- XCTest: 25 Core + 13 service/interaction tests = 38 passed, 0 failures.
- Original transparent app icon created using built-in imagegen; sizes 16 through 1024 packaged with Apple's iconutil. ICNS included via the Xcode resources phase and CFBundleIconFile.
- No existing user settings or permission grants were changed during verification; tests use temporary stores.
- Release app build and codesign verification: PASS. Built bundle reports version 0.2.0 / build 2 and the unchanged local.NotchFlow identifier.
- DMG: checksum verification and read-only mount passed; contains NotchFlow.app and Applications symlink. Packaged app signature verified and its icon matched Resources/AppIcon.icns byte-for-byte. ZIP archive also passed integrity verification.

## Hover stabilization — 2026-09-24

- Release build: PASS. XCTest: 22 Core + 11 service/interaction tests = 33 passed, 0 failures.
- Deduplicated hover entry events so panel resizing does not restart the entry delay.
- Added a 160ms exit grace period, cancelled on re-entry, to absorb transient tracking exits while resizing.
- Explicit close cancels pending opening; explicit expansion cancels pending hover collapse.
- Identical target frames no longer restart window animations. Window ordering and keyboard focus changes now happen only when needed.
- Replaced the content's independent spring/scale transition with an opacity transition using the same ease-in-out duration as the window.
- Automated regression coverage: brief exit/re-entry, duplicate entry, close before hover delay completes, and opening while hover collapse is pending.
- Physical pointer behavior on the user's installed app still needs confirmation after installing this build; no measured CPU performance claim is made.

## Automated

- Xcode 27.0 / Swift 6.4, macOS 14 deployment target.
- Swift Package integrated application build: PASS.
- Xcode Debug app bundle, arm64 + x86_64 compilation/linking, local ad-hoc signing: PASS.
- XCTest: 22 pure Core tests + 7 mocked service/persistence/playback tests = **29 passed, 0 failures**.
- Native app launch: PASS.
- Native app UI inspection: dashboard cards, module navigation to memo, editor controls, Escape collapse: PASS.
- No Calendar or Automation consent was granted by the developer agent. No login item was registered.

The app was visually inspected on the available notched display. Actual calendar/player behavior, other displays, and login relaunch are not certified by these tests. Tests use temporary directories and mock system boundaries, not the user's files/calendar.

## Manual release checklist

- [ ] Move the pointer onto the lower edge of the notch → delayed preview; leave → collapse.
- [ ] Click → expand; type in Memo → pointer exit does not close it; outside click/Escape → save and collapse.
- [ ] Physically press Option+Space → toggle; choose another shortcut and check conflicts.
- [ ] Disable Hover/Click and verify each entry path; menu/shortcut remain available.
- [ ] Music absent / stopped / playing / paused; connect, deny consent, allow consent, previous/next, Apple Music artwork; Spotify desktop compatibility.
- [ ] Switch Music provider while an asynchronous request is in flight; old response must not replace the new provider.
- [ ] Calendar denied, granted, revoked; empty day, all-day event, ongoing event, tomorrow rollover, wake before/after meeting.
- [ ] Drag one file, multiple files, folder; cancel drag; drag over while expanded; drag out to Finder.
- [ ] Quick Look / reveal; renamed/moved/deleted original; external disk detach; remove shelf entry must preserve original.
- [ ] Relaunch with bookmarks and memos; corrupt copied test stores; low-disk/write failure; keep unsaved changes visible.
- [ ] Notification burst: calendar has priority; file/music updates do not close an editing memo.
- [ ] Switch display, disconnect selected display, connect an external screen without notch, negative screen origin, resolution scaling.
- [ ] Native full-screen, Spaces, Stage Manager, menu bar auto-hide; no interference with system security UI.
- [ ] Reduce Motion, Light/Dark/System, VoiceOver and keyboard focus.
- [ ] Signed installed app: enable login, grant system approval if requested, log out/in, disable login.

## Build environment note

The default Command Line Tools compiler and SDK did not match. Using the installed Xcode toolchain resolved this. The execution sandbox also blocked nested Swift macro sandboxing; verification used `OTHER_SWIFT_FLAGS=-disable-sandbox`. No global `xcode-select`, system privacy setting, or Gatekeeper setting was changed.

## Compact layout update

- Dashboard cards are a single horizontal row; default expanded width is 720pt (saved narrow widths normalize to at least 600pt).
- Dashboard height is notch height + 214pt instead of the former fixed 620pt. Detail modules choose a compact height; content remains scrollable.
- Active playback adds album art only beside the physical notch. The center remains clear of content for the camera cutout. Pausing removes the wings without changing the open/editing state.
- Automated tests verify playback updates do not interrupt expanded editing or repeatedly request window layout for unchanged playback state.
- Actual player integration still requires the user-authorized Music/Spotify connection. The waveform was removed.
- Relaunched the updated app and visually verified all four dashboard cards in one row at a restored 600pt width and roughly 250pt total height, with no vertical card stacking or clipped labels.

## Notch height correction

- Removed the waveform view and its animation entirely.
- Removed the extra 7pt from the collapsed window. Its bottom edge now equals the detected cutout bottom, during both playback and idle.
- Removed the extra collapsed SwiftUI body below the header; the header itself remains an accessible clickable button.
- Regression test checks height, top/bottom edges and centering on an offset display, with and without playback.
- Live NSScreen measurement: built-in display 1800×1169pt at 2× scale, safeAreaInsets.top = 38pt; auxiliary areas leave a 220pt center cutout. External DELL display reports top inset 0.
- Relaunched the corrected app and inspected the collapsed screenshot: 232×38pt (previously 232×45pt). No lower 7pt strip or waveform remains.
