# REA implementation analysis — Hovrly 2.4.5

Analysis date: 2026-10-30. REA CLI: 6.7.0, existing installation in the Coryph research tools.

## Evidence

- Successful evidence ID: `ev_911778eb22a64715306c1dd1a23bdc610863ddfeb578c16a174defcb77925be2`.
- Artifact SHA-256: `5d5f39466228105add8b1f38a09086db149842d3e1eb67c6b7ca51547bb183e8`.
- Selected sources: `app/renderer.js`, `app/clock.js`, `app/window.js`, `app/tray.js`.
- Application graph: 884 nodes, 919 edges.
- Integrity contradictions: 0.
- Other inventoried files outside semantic analysis: 270.

REA parsed inert application sources; it did not run extracted Hovrly code. The original application bundle was not modified. Initial sandboxed attempts failed while compiling REA's process helper; the authorized expanded execution completed successfully. Raw evidence remains in the working analysis directory rather than distributing the original application material.

## Interaction contracts retained

| Original behaviour | Native implementation |
| --- | --- |
| Menu-bar click toggles an anchored, frameless floating panel | NSStatusItem + transparent rounded NSPanel |
| Click away/lose focus hides panel | Global click monitor and key-window handling, with allowance for the opaque child configuration panel |
| Slider input previews all cities; mouse-up calls `current()` | Native NSView tracking; preview and real time are distinct; mouse-up clears preview |
| Drag to sort; name edit saves on Return and cancels on blur | SwiftUI drag/drop, in-place editing, stable city UUIDs |
| Eye controls whether a city appears in the menu bar | Pinned flag, independently persisted from work-hour inclusion |
| Collapsible settings, 12/24-hour clock, compact labels, date | Same settings structure; actual native login item |
| Original yellow/purple time capsules and dark/light backgrounds | Native rendering and SF Symbols; no original visual assets bundled |

## Intentional improvements

1. Day offsets appear alongside time capsules.
2. Selected working schedules intersect in a low-opacity fill inside the full-width timeline, without an extra status row. Right-clicking a briefcase opens a matching opaque child panel directly. Configuration uses local HH:mm strings, avoiding DatePicker/system-time-zone conversion. Overnight intervals are supported; equal endpoints are rejected rather than treated ambiguously as 24 hours.
3. Real astronomical day/night replaces Hovrly's fixed 04:00–21:00 rule. Each city has coordinates; aliases such as Austin and Wuhan do not inherit Chicago/Shanghai coordinates simply because they share a time zone.
4. Offline city search replaces the original database query. Existing city operations use IDs rather than mutable display names.
5. The original theme listener is added inside repeated tray updates; KnoTime does not recreate listeners per tick.
6. A single minute-boundary timer updates the menu bar. Hidden-panel time is not published, breathing stops while hidden, and intersections are cached by selected schedules/reference day/zone.

## Calculation and verification boundaries

Overlap calculations iterate actual instants within the local calendar day (23/24/25 hours), using each target zone's calendar components. This includes both occurrences of a repeated DST hour and does not invent a skipped hour. The timeline's geometric position represents elapsed time through that actual day.

Solar elevation uses NOAA/Meeus-style orbital terms with a solar-centre threshold of −0.833°. This models apparent sunrise/sunset, with standard refraction, and naturally handles polar day/night. Coordinates are city centres, not the user's location; no location permission is required. No claim is made about cloud cover, mountains or weather-specific refraction.

Sources: [NOAA calculation details](https://gml.noaa.gov/grad/solcalc/calcdetails.html), [NOAA solar-position equations](https://gml.noaa.gov/grad/solcalc/solareqns.PDF), bundled system IANA `zone.tab` (public domain).

REA's static graph is evidence of source relationships, not proof of every runtime path. Real UI observations and native tests are recorded separately in `verification.md`.
