# Security

Report vulnerabilities privately using GitHub's Security → Report a vulnerability. Do not include credentials or private keys in issues or pull requests.

The latest stable release is the supported version. Update archives are signed with Ed25519 and verified by Sparkle before extraction. Developer ID signing and Apple notarization are required by our public release workflow. The feed uses HTTPS. GitHub hosting still receives normal request metadata; system profiling is disabled.

Private update-signing keys stay in the maintainer's Keychain. Release credentials must never be committed. If a key is lost or suspected compromised, stop publishing and follow Sparkle's key-rotation guidance before resuming.
