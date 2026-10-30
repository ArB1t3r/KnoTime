import SwiftUI
import AppKit

/// Native right-click handling avoids SwiftUI's mandatory intermediate context menu.
struct WorkButton: NSViewRepresentable {
    let enabled: Bool
    let name: String
    let onToggle: () -> Void
    let onConfigure: (NSRect) -> Void
    func makeNSView(context: Context) -> WorkingHoursButton {
        let button = WorkingHoursButton()
        button.isBordered = false; button.bezelStyle = .regularSquare
        button.imagePosition = .imageOnly; button.imageScaling = .scaleProportionallyDown
        button.target = button; button.action = #selector(WorkingHoursButton.toggle)
        return button
    }
    func updateNSView(_ button: WorkingHoursButton, context: Context) {
        let symbol = NSImage(systemSymbolName: enabled ? "briefcase.fill" : "briefcase", accessibilityDescription: "Working hours")
        button.image = symbol?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .regular))
        button.contentTintColor = enabled ? NSColor(calibratedRed: 0.43, green: 0.78, blue: 0.60, alpha: 1) : NSColor.secondaryLabelColor.withAlphaComponent(0.5)
        button.onToggle = onToggle; button.onConfigure = onConfigure
        button.toolTip = "Click to \(enabled ? "exclude" : "include") · Right-click to set hours"
        button.setAccessibilityLabel("Working hours for \(name)")
        button.setAccessibilityValue(enabled ? "Included" : "Excluded")
    }
}
final class WorkingHoursButton: NSButton {
    var onToggle: (() -> Void)?
    var onConfigure: ((NSRect) -> Void)?
    @objc func toggle() { onToggle?() }
    override func rightMouseDown(with event: NSEvent) {
        let anchor = window?.convertToScreen(convert(bounds, to: nil)) ?? .zero
        onConfigure?(anchor)
    }
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { rightMouseDown(with: event) }
        else { super.mouseDown(with: event) }
    }
    override func accessibilityCustomActions() -> [NSAccessibilityCustomAction]? {
        [NSAccessibilityCustomAction(name: "Configure working hours", handler: { [weak self] in
            guard let self else { return false }
            let rect = self.window?.convertToScreen(self.convert(self.bounds, to: nil)) ?? .zero
            self.onConfigure?(rect); return true
        })]
    }
}
