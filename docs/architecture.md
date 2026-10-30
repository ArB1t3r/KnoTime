# Architecture

- `TimeCore`: city models, IANA locations, calendar-aware wall-clock calculations, work-hour intersections and solar position. No UI or network dependencies.
- `ClockStore`: preferences, cached formatting/intersections, minute-boundary refresh and sleep/time-zone lifecycle handling.
- `PanelView`: SwiftUI cities, search, work-hour configuration and collapsed settings.
- `TimeSlider` / `WorkButton`: native AppKit input behavior and direct right-click configuration.
- `main.swift`: accessory application lifecycle, status item, panel placement and focus.
- `AppUpdater`: one Sparkle controller. Sparkle owns scheduling and preferences; no custom polling loop. Feed and Ed25519 public key are embedded in Info.plist. Private signing material is never included.
- `KnoTimeMark`: cached vector menu-bar template image.

Preferences remain local in `app.knotime.mac`. No city data is sent to a server. Update checks contact GitHub; standard HTTP and Sparkle version/platform metadata can be visible to the host. System profiling is disabled.

Schedules repeat daily, including weekends. Daylight is a city-coordinate estimate with standard refraction, not a terrain/weather observation. Availability means configured working hours, not calendar free/busy.
