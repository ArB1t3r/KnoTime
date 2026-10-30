import AppKit
let directory = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let body = NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 196, yRadius: 196)
NSColor(calibratedRed: 0.115, green: 0.12, blue: 0.135, alpha: 1).setFill(); body.fill()
let sun = NSBezierPath(ovalIn: NSRect(x: 220, y: 346, width: 332, height: 332))
NSColor(calibratedRed: 1, green: 0.78, blue: 0.19, alpha: 1).setFill(); sun.fill()
let moon = NSBezierPath(ovalIn: NSRect(x: 472, y: 346, width: 332, height: 332))
NSColor(calibratedRed: 0.37, green: 0.35, blue: 0.72, alpha: 1).setFill(); moon.fill()
NSColor(calibratedRed: 0.43, green: 0.77, blue: 0.61, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 477, y: 383, width: 70, height: 258), xRadius: 35, yRadius: 35).fill()
let hand = NSBezierPath(); hand.move(to: NSPoint(x: 638, y: 572)); hand.line(to: NSPoint(x: 638, y: 512)); hand.line(to: NSPoint(x: 683, y: 486)); hand.lineWidth = 14; hand.lineCapStyle = .round
NSColor.white.withAlphaComponent(0.9).setStroke(); hand.stroke()
image.unlockFocus()
try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
for size in [16,32,128,256,512] {
    for scale in [1,2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: directory + "/icon_\(size)x\(size)\(suffix).png"))
    }
}
