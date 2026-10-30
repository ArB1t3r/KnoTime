import AppKit

/// Orbit clock: a broken clock ring and a satellite mark for a second time zone.
/// A cached template image stays crisp at native menu-bar scale and follows macOS tint.
enum KnoTimeMark {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            draw(in: rect, color: .black)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "KnoTime"
        return image
    }()
    static func draw(in rect: NSRect, color: NSColor) {
        NSGraphicsContext.saveGraphicsState()
        let transform = AffineTransform(translationByX: rect.minX, byY: rect.minY)
        let scaling = AffineTransform(scaleByX: rect.width / 18, byY: rect.height / 18)
        (transform as NSAffineTransform).concat()
        (scaling as NSAffineTransform).concat()
        color.setStroke(); color.setFill()
        let ring = NSBezierPath()
        ring.appendArc(withCenter: NSPoint(x: 8.5, y: 8.5), radius: 6.25, startAngle: 72, endAngle: 384, clockwise: false)
        ring.lineWidth = 1.5; ring.lineCapStyle = .round; ring.stroke()
        NSBezierPath(ovalIn: NSRect(x: 11.4, y: 11.7, width: 3.1, height: 3.1)).fill()
        let hands = NSBezierPath()
        hands.move(to: NSPoint(x: 8.5, y: 12))
        hands.line(to: NSPoint(x: 8.5, y: 8.5))
        hands.line(to: NSPoint(x: 11.4, y: 6.8))
        hands.lineWidth = 1.5; hands.lineCapStyle = .round; hands.lineJoinStyle = .round; hands.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }
}
