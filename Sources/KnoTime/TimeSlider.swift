import AppKit
import SwiftUI

struct TimeSlider: NSViewRepresentable {
    @ObservedObject var store: ClockStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeNSView(context: Context) -> TimelineView { TimelineView() }
    func updateNSView(_ view: TimelineView, context: Context) {
        view.position = store.position
        view.intervals = store.ranges
        view.label = store.time(store.displayDate, zone: store.referenceZone)
        view.startLabel = store.preferences.twentyFour ? "00:00" : "12 AM"
        view.endLabel = store.preferences.twentyFour ? "23:59" : "12 AM"
        view.previewing = store.preview != nil
        view.toolTip = store.selected.isEmpty ? "Drag to compare · Release to return to now" : store.ranges.isEmpty ? "No shared working hours" : "Working hours · \(store.selected.count) selected"
        view.pulse = store.visible && store.inOverlap && !reduceMotion
        view.onChange = { store.scrub($0) }; view.onEnd = { store.snap() }
        view.needsDisplay = true; view.updateBand()
    }
}

final class TimelineView: NSView {
    var position: Double = 0
    var intervals: [ClosedRange<Double>] = []
    var label = ""
    var startLabel = "00:00"
    var endLabel = "23:59"
    var previewing = false
    var pulse = false
    var onChange: ((Double) -> Void)?
    var onEnd: (() -> Void)?
    private var tracking = false
    private let band = CAShapeLayer()
    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame); wantsLayer = true; layer?.addSublayer(band)
        setAccessibilityElement(true); setAccessibilityRole(.slider)
        setAccessibilityLabel("Time comparison")
        setAccessibilityHelp("Drag or use arrow keys to compare times. Release to return to now. Filled areas are shared working hours.")
        toolTip = "Drag to compare · Release to return to now"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func accessibilityValue() -> Any? { label }
    override func accessibilityPerformIncrement() -> Bool { onChange?(min(1, position + 15.0 / 1440)); DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.onEnd?() }; return true }
    override func accessibilityPerformDecrement() -> Bool { onChange?(max(0, position - 15.0 / 1440)); DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.onEnd?() }; return true }
    override func layout() { super.layout(); updateBand() }
    func updateBand() {
        let path = CGMutablePath()
        for range in intervals {
            let rect = CGRect(x: range.lowerBound * bounds.width, y: 0, width: max(1, (range.upperBound - range.lowerBound) * bounds.width), height: bounds.height)
            path.addRoundedRect(in: rect, cornerWidth: 0, cornerHeight: 0)
        }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        band.frame = bounds; band.path = path; band.fillColor = NSColor(calibratedRed: 0.43, green: 0.78, blue: 0.60, alpha: 0.22).cgColor
        CATransaction.commit()
        if pulse && band.animation(forKey: "breathe") == nil {
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 0.8; animation.toValue = 1; animation.duration = 2.0
            animation.autoreverses = true; animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            band.add(animation, forKey: "breathe")
        } else if !pulse { band.removeAnimation(forKey: "breathe") }
    }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); if window == nil { band.removeAllAnimations() } }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let width = bounds.width
        let x = min(width - 0.5, max(0.5, CGFloat(position) * width))
        let line = NSBezierPath(); line.move(to: NSPoint(x: x, y: 0)); line.line(to: NSPoint(x: x, y: bounds.height))
        NSColor.systemBlue.setStroke(); line.lineWidth = 1; line.stroke()
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
        let text = label as NSString; let size = text.size(withAttributes: attrs)
        let textX = x + size.width + 12 < width - 15 ? x + 10 : x - size.width - 10
        let rect = NSRect(x: max(15, textX), y: (bounds.height - size.height) / 2, width: size.width, height: size.height)
        let muted: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.6)]
        let left = startLabel as NSString, right = endLabel as NSString
        let lRect = NSRect(origin: NSPoint(x: 15, y: rect.minY), size: left.size(withAttributes: muted))
        let rSize = right.size(withAttributes: muted)
        let rRect = NSRect(x: width - 15 - rSize.width, y: rect.minY, width: rSize.width, height: rSize.height)
        if !rect.insetBy(dx: -12, dy: 0).intersects(lRect) && abs(x - lRect.midX) > 30 { left.draw(in: lRect, withAttributes: muted) }
        if !rect.insetBy(dx: -12, dy: 0).intersects(rRect) && abs(x - rRect.midX) > 30 { right.draw(in: rRect, withAttributes: muted) }
        text.draw(in: rect, withAttributes: attrs)
    }
    private func change(_ event: NSEvent) {
        let x = convert(event.locationInWindow, from: nil).x
        onChange?(min(1, max(0, x / bounds.width)))
    }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self); tracking = true; change(event) }
    override func mouseDragged(with event: NSEvent) { if tracking { change(event) } }
    override func mouseUp(with event: NSEvent) { tracking = false; onEnd?() }
    override func scrollWheel(with event: NSEvent) {
        // A wheel gesture behaves like a drag and snaps when the gesture ends.
        let delta = event.scrollingDeltaX != 0 ? event.scrollingDeltaX : -event.scrollingDeltaY
        onChange?(min(1, max(0, position + delta / 1200)))
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(endScroll), object: nil)
        perform(#selector(endScroll), with: nil, afterDelay: 0.18)
    }
    @objc private func endScroll() { onEnd?() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 123 { onChange?(max(0, position - 15.0 / 1440)) }
        else if event.keyCode == 124 { onChange?(min(1, position + 15.0 / 1440)) }
        else if event.keyCode == 53 { onEnd?() }
        else { super.keyDown(with: event) }
    }
    override func keyUp(with event: NSEvent) { onEnd?() }
}
