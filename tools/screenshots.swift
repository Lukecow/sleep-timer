// Renders the README screenshots: three equal-size cards (choose time, running, settings)
// side by side, in light and dark. Usage (from the project folder):
//   swiftc -swift-version 5 -target arm64-apple-macos15.0 Sources/Views.swift Sources/WheelColumn.swift \
//     Sources/TimerModel.swift Sources/SystemActions.swift tools/screenshots.swift -parse-as-library -o /tmp/shots && /tmp/shots docs
import AppKit
import SwiftUI

let cardWidth: CGFloat = 300

/// A borderless window that can be the focused window, so controls draw in their active colours.
final class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
let scale: CGFloat = 2

/// Renders the menu exactly as it looks when open (active window, so switches are coloured).
@MainActor func renderCard(dark: Bool, height: CGFloat?) -> (CGImage, CGFloat) {
    let bg = dark ? Color(white: 0.165) : Color(white: 0.955)
    let root = MenuContent()
        .environmentObject(TimerModel.shared)
        .environment(\.controlActiveState, .key)
        .frame(width: cardWidth, height: height, alignment: .top)
        .background(bg)
    let host = NSHostingView(rootView: AnyView(root))
    let win = KeyWindow(contentRect: NSRect(x: -3000, y: 0, width: cardWidth, height: 600),
                       styleMask: [.borderless], backing: .buffered, defer: false)
    win.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    win.contentView = host
    NSApp.activate(ignoringOtherApps: true)
    win.makeKeyAndOrderFront(nil)
    win.orderFrontRegardless()
    RunLoop.main.run(until: Date().addingTimeInterval(0.8))
    let size = host.fittingSize
    win.setContentSize(size)
    host.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.6))
    let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
    host.cacheDisplay(in: host.bounds, to: rep)
    win.orderOut(nil)
    return (rep.cgImage!, size.height)
}

@MainActor func setState(_ i: Int) {
    let m = TimerModel.shared
    m.cancel()
    m.showSettings = false
    m.endAction = .sleep
    m.pauseMedia = true
    m.fadeVolume = true
    switch i {
    case 0:
        m.pickedHours = 0; m.pickedMinutes = 45
    case 1:
        m.start(seconds: 23 * 60 + 41)
        m.totalDuration = 45 * 60
    default:
        m.showSettings = true
    }
}

@MainActor func composite(dark: Bool, out: String) {
    // Measure every card, then render all at the tallest height so they line up.
    var heights: [CGFloat] = []
    for i in 0..<3 { setState(i); heights.append(renderCard(dark: dark, height: nil).1) }
    let h = heights.max()!
    var cards: [CGImage] = []
    for i in 0..<3 { setState(i); cards.append(renderCard(dark: dark, height: h).0) }
    TimerModel.shared.cancel()

    let gap: CGFloat = 28, margin: CGFloat = 30, radius: CGFloat = 14
    let W = (cardWidth * 3 + gap * 2 + margin * 2) * scale
    let H = (h + margin * 2) * scale
    let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: scale, y: scale)
    for (i, card) in cards.enumerated() {
        let rect = CGRect(x: margin + CGFloat(i) * (cardWidth + gap), y: margin, width: cardWidth, height: h)
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        // shadow
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 22,
                      color: NSColor.black.withAlphaComponent(dark ? 0.55 : 0.18).cgColor)
        ctx.addPath(path); ctx.setFillColor(NSColor.black.cgColor); ctx.fillPath()
        ctx.restoreGState()
        // card image, clipped to rounded corners
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        ctx.draw(card, in: rect)
        ctx.restoreGState()
        // hairline border
        ctx.addPath(path)
        ctx.setStrokeColor(NSColor(white: dark ? 1 : 0, alpha: dark ? 0.14 : 0.10).cgColor)
        ctx.setLineWidth(1 / scale * 2)
        ctx.strokePath()
    }
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(out)/screenshots-\(dark ? "dark" : "light").png"))
}

@main
struct Screenshots {
    @MainActor static func main() {
        NSApplication.shared.setActivationPolicy(.accessory)
        let out = CommandLine.arguments[1]
        composite(dark: false, out: out)
        composite(dark: true, out: out)
        print("done")
    }
}
