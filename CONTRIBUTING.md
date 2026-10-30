# Contributing

Use macOS 14+, Xcode and Swift 6+. Run `./build.sh --test` before submitting a pull request. Keep TimeCore independent of AppKit and network access. Add meaningful regression tests for time arithmetic, DST, persistence migrations or updater configuration changes.

UI changes should preserve the compact menu-bar layout, keyboard accessibility, fixed-position time capsules and snap-to-now behavior. Include light/dark screenshots and describe manual verification. Check that animations stop when the panel is hidden and that Reduce Motion is respected.

Performance claims need a method, baseline, hardware/software context and raw measurements. Never infer battery life from one CPU sample. Avoid adding polling timers or network dependencies to clock calculations.

Keep changes focused. Explain the problem, resulting behavior and validation in the PR. Do not include `.build`, signing keys, credentials, local user settings, compiled apps or private test data. Contributions are licensed under the MIT license.

Be respectful and constructive. Disagreements should focus on evidence and implementation, not people. Maintainers may remove abusive content.
