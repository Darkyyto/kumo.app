// README banner (light and dark) and the social preview for Kumo.
// swiftc -O Scripts/brand/make-graphics.swift -o /tmp/make-graphics && /tmp/make-graphics docs <icon.png>
import AppKit

let out = CommandLine.arguments[1]
let title = "Kumo"
let tagline = "Lectures, written down as they happen."

func render(width: CGFloat, height: CGFloat, dark: Bool, scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: width, height: height)
    let base = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    base.translateBy(x: 0, y: height)
    base.scaleBy(x: 1, y: -1)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: base, flipped: true)
    let cg = base
    let ink = dark ? NSColor(srgbRed: 0.96, green: 0.96, blue: 0.97, alpha: 1) : NSColor(srgbRed: 0.11, green: 0.11, blue: 0.13, alpha: 1)
    let dim = dark ? NSColor(srgbRed: 0.56, green: 0.56, blue: 0.58, alpha: 1) : NSColor(srgbRed: 0.42, green: 0.42, blue: 0.45, alpha: 1)

    cg.setFillColor((dark ? NSColor(srgbRed: 0.055, green: 0.055, blue: 0.063, alpha: 1) : NSColor(srgbRed: 0.96, green: 0.96, blue: 0.96, alpha: 1)).cgColor)
    cg.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let s = height / 420
    // the app icon, centred above the title
    let side = 128 * s
    if let icon = NSImage(contentsOfFile: CommandLine.arguments[2]) {
        icon.draw(in: NSRect(x: width / 2 - side / 2, y: 40 * s, width: side, height: side), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])
    }

    func centered(_ string: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, y: CGFloat, kern: CGFloat) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        NSAttributedString(string: string, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: paragraph, .kern: kern])
            .draw(in: NSRect(x: 0, y: y, width: width, height: size * 1.4))
    }
    centered(title, size: 92 * s, weight: .semibold, color: ink, y: 200 * s, kern: -2.4 * s)
    centered(tagline, size: 26 * s, weight: .regular, color: dim, y: 312 * s, kern: -0.2 * s)
    NSGraphicsContext.current = nil
    return rep
}

for dark in [false, true] {
    let rep = render(width: 1200, height: 420, dark: dark, scale: 2)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/banner-\(dark ? "dark" : "light").png"))
}
let social = render(width: 1280, height: 640, dark: true, scale: 1)
try! social.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/social-preview.png"))
