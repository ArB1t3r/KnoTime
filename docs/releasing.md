# Releasing KnoTime

## Distribution contract

Public stable installers must be Developer ID signed, notarized by Apple, and stapled. Do not tell users to disable Gatekeeper or remove quarantine attributes. Ad-hoc builds are for local development only. Release assets live in `ArB1t3r/KnoTime`; source is public in the same repository.

The updater reads `https://github.com/ArB1t3r/KnoTime/releases/latest/download/appcast.xml`. The feed must be attached to every stable release. Do not mark a release latest until all artifacts are uploaded. Pre-releases do not become the stable update channel. Install a version with Sparkle manually once if upgrading from the original 1.0 preview.

## One-time maintainer setup

1. Accept any pending Apple Developer Program agreement as the Account Holder. Xcode cannot issue certificates while this is pending.
2. Xcode → Settings → Apple Accounts → your team → Manage Certificates → Developer ID Application. Keep the private key in Keychain. Apple requires the Account Holder role to create local Developer ID certificates; an Admin role alone is insufficient. Cloud-managed Developer ID access is a separate distribution route. See [Apple’s role requirement](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/).
3. Configure `xcrun notarytool store-credentials KnoTime-notary` interactively using your Apple account/team and an app-specific password, or an App Store Connect API key. Do not paste secrets into issues, chat, scripts or shell history. The saved profile belongs in the login Keychain.
4. Sparkle's Ed25519 signing key uses Keychain account `app.knotime.mac`. The repository contains only its public key. On the original release machine this key has already been generated. Back it up securely outside the repository; never regenerate it as routine release preparation.
5. Other contributors building forks must use their own feed and signing public key. They cannot publish compatible official updates without the release key.

## Prepare and ship

1. Update both `CFBundleShortVersionString` and monotonically increasing `CFBundleVersion` in `Resources/Info.plist`. Update CHANGELOG and release notes. Never overwrite a published version's assets.
2. Run `KNOTIME_UNIVERSAL=1 ./build.sh --test`. Verify architecture with `lipo -archs dist/KnoTime.app/Contents/MacOS/KnoTime`.
3. Export non-secret environment variables `KNOTIME_SIGN_IDENTITY='Developer ID Application: … (TEAMID)'` and `KNOTIME_NOTARY_PROFILE=KnoTime-notary`.
4. Run `./scripts/notarize.sh`. It signs Sparkle helpers inside-out, enables hardened runtime, submits to Apple, checks acceptance, staples, and evaluates Gatekeeper.
5. Run `./scripts/publish-release.sh path/to/release-notes.md`. It refuses unstapled/non-Developer-ID apps, makes and notarizes a DMG, signs the update ZIP with Sparkle, creates a draft release, uploads all files, then publishes it. This command publishes publicly; inspect everything first.
6. Fetch `/releases/latest/download/appcast.xml` anonymously and confirm version, HTTPS URLs, byte length and signature. Test a copied previous version upgrading, relaunching, preserving cities/schedules and checking again with no update available. A changed or truncated archive must fail signature validation.
7. On a clean Mac (or clean user account with normal quarantine), download the DMG through a browser, drag to Applications, launch, and verify no security bypass is needed. Exercise sleep/wake, menu-bar UI, and Open at Login. Test Intel hardware before claiming full Intel QA.

`prepare-release.sh OUTPUT_DIRECTORY` only creates locally signed ZIP/appcast artifacts; it does not publish. The private key stays in Keychain. Official update signing is distinct from Apple's Developer ID signing and notarization; all are required by our public release workflow.

If publishing fails after draft creation, inspect the draft and upload missing assets before publishing; do not delete a stable version to retry. Never publish a smaller build number as a rollback—issue a new higher build containing the fix.

## References

- [Sparkle setup](https://sparkle-project.org/documentation/)
- [Sparkle helper signing](https://sparkle-project.org/documentation/sandboxing/#code-signing)
- [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

## Current verification boundary

Version 1.1.0 is published. The universal application and DMG both received Apple notarization acceptance, were stapled, and passed validation. Gatekeeper accepts the application as Notarized Developer ID. The public GitHub appcast is accessible without authentication. A separate signed 1.0.9 test copy discovered, downloaded, installed and automatically relaunched as 1.1.0; user preferences were preserved. A subsequent check reports the latest version. Intel hardware execution and a fresh-user-account installation remain untested.
