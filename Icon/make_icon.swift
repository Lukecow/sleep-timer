// Draws the Sleep Timer app icon (light and dark) as 1024x1024 PNGs.
// Usage: swift make_icon.swift <output-folder>
import AppKit

func makeIcon(dark: Bool) -> NSBitmapImageRep {
    let size = 1024
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Apple's macOS icon grid: 824pt rounded square centred on a 1024 canvas.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    // Soft shadow under the tile.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(dark ? 0.5 : 0.25)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Background
    let bg = dark
        ? NSGradient(starting: NSColor(srgbRed: 0.17, green: 0.16, blue: 0.27, alpha: 1),
                     ending: NSColor(srgbRed: 0.06, green: 0.06, blue: 0.11, alpha: 1))!
        : NSGradient(starting: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
                     ending: NSColor(srgbRed: 0.91, green: 0.91, blue: 0.97, alpha: 1))!
    bg.draw(in: shape, angle: -90)

    // Moon with "zzz" in the app's purple (system indigo).
    let purple = dark
        ? NSColor(srgbRed: 0.45, green: 0.44, blue: 0.98, alpha: 1)
        : NSColor(srgbRed: 0.35, green: 0.34, blue: 0.84, alpha: 1)
    let config = NSImage.SymbolConfiguration(pointSize: 470, weight: .regular)
        .applying(NSImage.SymbolConfiguration(paletteColors: [purple]))
    let symbol = NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: nil)!
        .withSymbolConfiguration(config)!
    let s = symbol.size
    let rect = NSRect(x: 512 - s.width / 2, y: 512 - s.height / 2 - 6, width: s.width, height: s.height)
    symbol.draw(in: rect)

    // Subtle edge highlight.
    NSColor.white.withAlphaComponent(dark ? 0.10 : 0.6).setStroke()
    let edge = NSBezierPath(roundedRect: body.insetBy(dx: 1.5, dy: 1.5), xRadius: 184, yRadius: 184)
    edge.lineWidth = 3
    edge.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let out = CommandLine.arguments[1]
for dark in [false, true] {
    let data = makeIcon(dark: dark).representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(out)/icon-\(dark ? "dark" : "light").png"))
}
print("done")
