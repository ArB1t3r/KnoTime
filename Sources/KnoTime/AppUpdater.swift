import AppKit
import Combine
import Sparkle

/// Sparkle owns scheduling and persisted preferences; no second polling timer.
@MainActor final class AppUpdater: ObservableObject {
    @Published private(set) var canCheck = false
    @Published private(set) var automaticChecks = false
    private var controller: SPUStandardUpdaterController?
    private(set) var configurationError: String?
    var willCheck: (() -> Void)?
    var configured: Bool { controller != nil && configurationError == nil }
    var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—" }

    init() {
        guard let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let url = URL(string: feed), url.scheme == "https", url.host != nil,
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32 else {
            configurationError = "Updates are not configured for this build."
            return
        }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        controller.updater.publisher(for: \.canCheckForUpdates).receive(on: RunLoop.main).assign(to: &$canCheck)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates).receive(on: RunLoop.main).assign(to: &$automaticChecks)
        do { try controller.updater.start() }
        catch { configurationError = error.localizedDescription }
    }

    func toggleAutomaticChecks() {
        guard configured, let updater = controller?.updater else { return }
        updater.automaticallyChecksForUpdates.toggle()
    }

    func check() {
        willCheck?()
        NSApp.activate(ignoringOtherApps: true)
        if let error = configurationError {
            let alert = NSAlert()
            alert.messageText = "Updates unavailable"
            alert.informativeText = error
            alert.runModal()
            return
        }
        guard canCheck else { return }
        controller?.checkForUpdates(nil)
    }
}
