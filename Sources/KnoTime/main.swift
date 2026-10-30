import AppKit
import SwiftUI
import TimeCore

final class ClockPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var panel: ClockPanel!
    private var store: ClockStore!
    private var updater: AppUpdater!
    private var editor: ClockPanel?
    private var outsideMonitor: Any?
    private var localMonitor: Any?
    private var resizePending = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "app.knotime.mac").filter({ $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }).count > 0 {
            NSApp.terminate(nil); return
        }
        NSApp.setActivationPolicy(.accessory)
        let menu = NSMenu()
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        for (title, action, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            editMenu.addItem(NSMenuItem(title: title, action: Selector(action), keyEquivalent: key))
        }
        editItem.submenu = editMenu; menu.addItem(editItem); NSApp.mainMenu = menu
        store = ClockStore()
        updater = AppUpdater()
        updater.willCheck = { [weak self] in self?.hidePanel() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self; statusItem.button?.action = #selector(togglePanel)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.setAccessibilityLabel("KnoTime")
        statusItem.button?.toolTip = "KnoTime — compare time, find overlap"
        panel = ClockPanel(contentRect: NSRect(x: 0, y: 0, width: 325, height: store.height), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "KnoTime"; panel.isReleasedWhenClosed = false; panel.isOpaque = false
        panel.backgroundColor = .clear; panel.hasShadow = true; panel.level = .popUpMenu
        panel.hidesOnDeactivate = false; panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: PanelView(store: store, updater: updater))
        store.showWorkingHours = { [weak self] city, anchor in self?.showEditor(city: city, anchor: anchor) }
        store.statusChanged = { [weak self] in self?.updateStatus() }
        store.sizeChanged = { [weak self] in self?.scheduleResize() }
        updateStatus()
        if !UserDefaults.standard.bool(forKey: "hasLaunched") {
            UserDefaults.standard.set(true, forKey: "hasLaunched")
            DispatchQueue.main.async { [weak self] in self?.showPanel() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in if self?.panel.isVisible == true { self?.positionPanel() } }
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel(); return false
    }
    private func updateStatus() {
        guard let button = statusItem.button else { return }
        let title = store.statusTitle()
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        if title.isEmpty {
            button.title = ""; button.image = KnoTimeMark.image
        } else { button.image = nil; button.title = " " + title + " " }
        button.setAccessibilityValue(title.isEmpty ? "Open clocks" : title)
    }
    private func scheduleResize() {
        guard !resizePending else { return }; resizePending = true
        DispatchQueue.main.async { [weak self] in self?.resizePending = false; self?.positionPanel() }
    }
    private func positionPanel() {
        guard let button = statusItem.button, let window = button.window else { return }
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = window.screen ?? NSScreen.main!
        let frame = screen.visibleFrame
        store.availableHeight = frame.height - 16
        let height = min(store.height, frame.height - 16)
        let x = min(max(anchor.minX - 7, frame.minX + 8), frame.maxX - 325 - 8)
        panel.setFrame(NSRect(x: x, y: max(frame.minY + 8, anchor.minY - height - 7), width: 325, height: height), display: true)
    }
    @objc private func togglePanel() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            let open = NSMenuItem(title: "Open KnoTime", action: #selector(showPanel), keyEquivalent: ""); open.target = self; menu.addItem(open)
            let check = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
            check.target = self; menu.addItem(check)
            menu.addItem(.separator())
            menu.addItem(NSMenuItem(title: "Quit KnoTime", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem.menu = menu; statusItem.button?.performClick(nil); statusItem.menu = nil
            return
        }
        if panel.isVisible { hidePanel() } else { showPanel() }
    }
    @objc private func checkForUpdates() { updater.check() }
    @objc private func showPanel() {
        store.open(); positionPanel()
        panel.makeKeyAndOrderFront(nil)
        // Focus the panel, not the city search field, so opening is always glance-first.
        panel.makeFirstResponder(panel)
        installMonitors()
    }
    private func showEditor(city: City, anchor: NSRect) {
        closeEditor()
        let child = ClockPanel(contentRect: NSRect(x: 0, y: 0, width: 250, height: 186), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        child.title = "Working Hours — \(city.name)"
        child.isReleasedWhenClosed = false; child.isOpaque = false; child.backgroundColor = .clear
        child.hasShadow = true; child.level = .popUpMenu; child.hidesOnDeactivate = false
        child.contentView = NSHostingView(rootView: WorkHoursView(store: store, city: city, dismiss: { [weak self] in self?.closeEditor() }))
        let screen = panel.screen ?? NSScreen.main!
        let visible = screen.visibleFrame
        let reference = anchor == .zero ? panel.frame : anchor
        var x = panel.frame.maxX + 8
        if x + 250 > visible.maxX - 8 { x = panel.frame.minX - 258 }
        x = max(visible.minX + 8, min(visible.maxX - 258, x))
        let y = max(visible.minY + 8, min(visible.maxY - 194, reference.midY - 93))
        child.setFrameOrigin(NSPoint(x: x, y: y))
        editor = child; panel.addChildWindow(child, ordered: .above)
        child.makeKeyAndOrderFront(nil)
    }
    private func closeEditor() {
        guard let editor else { return }
        panel.removeChildWindow(editor); editor.orderOut(nil); self.editor = nil
        if panel.isVisible { panel.makeKey(); panel.makeFirstResponder(panel) }
    }
    private func installMonitors() {
        removeMonitors()
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in self?.hidePanel() }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .leftMouseDown && event.window == self.panel && self.editor != nil { self.closeEditor() }
            if event.type == .keyDown && event.keyCode == 53 && self.editor != nil { self.closeEditor(); return nil }
            if event.type == .keyDown && event.keyCode == 53 && self.panel.childWindows?.isEmpty != false && self.store.query.isEmpty && !(self.panel.firstResponder is NSTextView) {
                self.hidePanel(); return nil
            }
            return event
        }
    }
    private func belongsToPanel(_ window: NSWindow) -> Bool {
        var current: NSWindow? = window
        while let w = current { if w == panel { return true }; current = w.parent }
        return false
    }
    private func removeMonitors() {
        if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor); self.outsideMonitor = nil }
        if let localMonitor { NSEvent.removeMonitor(localMonitor); self.localMonitor = nil }
    }
    private func hidePanel() {
        closeEditor(); panel.orderOut(nil); store.close(); removeMonitors()
    }
    func windowDidResignKey(_ notification: Notification) {
        // SwiftUI popovers may take key focus; keep the parent visible for those.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, self.panel.isVisible else { return }
            if NSApp.keyWindow != nil { return }
            if self.panel.childWindows?.contains(where: \.isVisible) == true { return }
            self.hidePanel()
        }
    }
    func applicationWillTerminate(_ notification: Notification) { removeMonitors() }
}

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
}
