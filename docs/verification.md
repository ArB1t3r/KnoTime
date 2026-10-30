# Verification — 2026-10-30

## Build and automated tests

- macOS Apple Silicon build using Swift 6.4, deployment target macOS 14.
- Release build succeeded. Application bundle approximately 1.1 MiB, one native executable, no downloaded dependencies.
- 22 XCTest tests passed with zero failures. The separate Swift Testing runner reports zero tests because this project uses XCTest; that is not the total test count.
- Covered half-open working hours, overnight schedules, no selection, actual intersections, no overlap, midnight-split bands, Kathmandu's 45-minute offset, 23-hour/25-hour DST days, repeated and nonexistent hours, date/year boundaries, slider clamps, stable IDs, offline search, invalid times, every minute's HH:mm round trip, independent city coordinates, backward-compatible preference decoding, seasonal solar changes, polar day/night, date-line equivalence and finite values at the poles.
- `codesign --verify --deep --strict` and `plutil -lint` passed for the built app. Signing is ad-hoc, not Developer ID notarization.

## Real application checks

Performed through macOS accessibility and screenshots on the actual running app:

- Open and reopen from Finder, show the menu-bar panel, dismiss on leaving it.
- Dark appearance, original yellow/purple capsule direction, settings expansion, full 24-hour and 12-hour time strings. A discovered time truncation was fixed and visually rechecked.
- One selected city fills its working interval; two incompatible cities produce no fill. Changing Austin to 00:00–08:00 produced the expected common interval with Wuhan; that temporary time range was restored to 09:00–18:00.
- Work-hour inputs read and save exact local HH:mm values. A system DatePicker time-zone conversion problem was removed by using validated wall-clock text inputs.
- Final right-click on the briefcase opened the opaque, matching configuration card in one step, with no intermediate menu. Cancel returned to the main panel.
- The final timeline uses its full width and height with faint work-hour fill and has no separate "Shared working hours" row.
- A live preview showed previous-day markers and the expected mix of day/night colours. Date markers were subsequently moved into an overlay below the fixed-height time capsule so they do not change its vertical layout.
- Settings persisted across development app restarts. No original Hovrly data was imported or modified.

## Performance sample

See `performance-sample.json` for six samples at two-second intervals. Both panels were hidden. KnoTime: one process, mean summed RSS 120.9 MiB, sampled CPU 0.0%. Hovrly: four processes, mean summed RSS 390.7 MiB, sampled CPU 0.0%. This sample preceded the last UI-only refinement to the work-hours card and timeline.

This is a brief smoke measurement, not a controlled energy benchmark. Summing RSS can count shared pages more than once. No claim is made about measured battery life, long-term leaks or physical footprint. The implementation uses one minute-boundary timer; hidden-panel time is not published, overlap calculations are cached, and pulse animations stop when hidden.

## Release boundaries

- Supplied binary targets Apple Silicon. Intel can be built from the same source but was not tested here.
- Developer ID signing/notarization requires the owner's signing identity; neither was available or attempted.
- Open at Login uses ServiceManagement, but a full logout/login cycle was not performed and the user's login setting was not enabled during testing.
- Light appearance and multi-monitor movement have implementation support but were not covered by a full visual test matrix on this session.
- Sunrise/sunset is computed for city-centre coordinates and standard atmospheric refraction, not measured weather or terrain-specific sunrise.

## Automatic updates and open-source release preparation

- Sparkle 2.10.1 is pinned in Package.resolved. Native framework embedding and runtime paths verified; 22 core tests still pass.
- Universal arm64 + x86_64 binary builds and deep code-signature verification pass (local ad-hoc signing). Intel execution is not yet tested.
- Update configuration uses HTTPS, a dedicated Ed25519 public key, 24-hour checking, profiling disabled and verification before archive extraction. Installation is not silent.
- Signed ZIP/appcast generation succeeded using the private key stored in Keychain account app.knotime.mac; no private key is exported.
- Public release scripts require Developer ID signing, Apple acceptance, stapling and Gatekeeper checks before publishing.
- The Program License Agreement has been accepted. A Developer ID Application certificate was created through Apple Developer and paired with the private key generated in the local Keychain. The universal app and Sparkle helpers now pass deep Developer ID signature verification with hardened runtime and secure timestamps. Apple notarization is pending a notarytool authentication profile; public distribution and end-to-end update/relaunch remain pending.

- GitHub Actions build/test/signature validation passed: https://github.com/ArB1t3r/KnoTime/actions/runs/41047176069 .
- Native UI inspection confirmed Automatic Updates and Check for Updates entries in the matching settings layout. With no public stable release yet, a manual check reports a retrieval error; this is not counted as a successful end-to-end update test.
- The generated archive's Ed25519 signature was independently checked using CryptoKit and the embedded public key. Flipping one byte in a copy caused verification to fail as expected.
