// Draws the purple moon (no background) for the modern .icon file.
// Usage: swift make_glyph.swift <AppIcon.icon/Assets folder>
import AppKit
func glyph(_ color: NSColor) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let cfg = NSImage.SymbolConfiguration(pointSize: 560, weight: .regular)
        .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
    let img = NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: nil)!.withSymbolConfiguration(cfg)!
    let s = img.size
    img.draw(in: NSRect(x: 512 - s.width / 2, y: 512 - s.height / 2 - 8, width: s.width, height: s.height))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
let out = CommandLine.arguments[1]
try! glyph(NSColor(srgbRed: 0.35, green: 0.34, blue: 0.84, alpha: 1)).write(to: URL(fileURLWithPath: out + "/moon-light.png"))
try! glyph(NSColor(srgbRed: 0.47, green: 0.46, blue: 1.0, alpha: 1)).write(to: URL(fileURLWithPath: out + "/moon-dark.png"))
