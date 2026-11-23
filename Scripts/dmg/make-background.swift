// Draws the installer window backgrounds for the Kumo and Shima disk images.
// swiftc -O Scripts/dmg/make-background.swift -o /tmp/make-background && /tmp/make-background <out-dir> <shima-icon.png> <kumo-icon.png>
import AppKit

struct Design {
    let name: String
    let title: String
    let subtitle: String
    let tagline: String
    let marks: [String]
    let icons: [(x: CGFloat, label: String)]
    let arrow: (from: CGFloat, to: CGFloat)
}

let width: CGFloat = 660, height: CGFloat = 440
let iconY: CGFloat = 300

func draw(_ design: Design, marks: [String: NSImage], scale: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width) * scale, pixelsHigh: Int(height) * scale, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: width, height: height)
    let base = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    base.translateBy(x: 0, y: height)
    base.scaleBy(x: 1, y: -1)
    let ctx = NSGraphicsContext(cgContext: base, flipped: true)
    NSGraphicsContext.current = ctx
    let cg = base
    let space = CGColorSpaceCreateDeviceRGB()

    // graphite page with a soft lift at the top
    let back = CGGradient(colorsSpace: space, colors: [NSColor(srgbRed: 0.105, green: 0.105, blue: 0.12, alpha: 1).cgColor, NSColor(srgbRed: 0.045, green: 0.045, blue: 0.05, alpha: 1).cgColor] as CFArray, locations: [0, 1])!
    cg.drawLinearGradient(back, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: height), options: [])
    let lift = CGGradient(colorsSpace: space, colors: [NSColor.white.withAlphaComponent(0.07).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
    cg.drawRadialGradient(lift, startCenter: CGPoint(x: width / 2, y: 90), startRadius: 0, endCenter: CGPoint(x: width / 2, y: 90), endRadius: 340, options: [])

    // marks at the top
    let side: CGFloat = 64
    let total = CGFloat(design.marks.count) * side + CGFloat(max(0, design.marks.count - 1)) * 16
    var x = (width - total) / 2
    for name in design.marks {
        if let image = marks[name] {
            image.draw(in: NSRect(x: x, y: 40, width: side, height: side), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])
        }
        x += side + 16
    }

    func text(_ string: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, y: CGFloat, kern: CGFloat = 0) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributed = NSAttributedString(string: string, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: NSColor.white.withAlphaComponent(alpha),
            .paragraphStyle: paragraph,
            .kern: kern,
        ])
        attributed.draw(in: NSRect(x: 0, y: y, width: width, height: size * 1.4))
    }
    text(design.title, size: 34, weight: .semibold, alpha: 1, y: 122, kern: -0.8)
    text(design.subtitle, size: 15, weight: .regular, alpha: 0.6, y: 170)
    text(design.tagline, size: 12, weight: .regular, alpha: 0.32, y: 406)

    // light pills under the labels: Finder draws the names on top in black
    for icon in design.icons {
        let pill = CGRect(x: icon.x - 62, y: iconY + 56 + 6, width: 124, height: 28)
        cg.addPath(CGPath(roundedRect: pill, cornerWidth: 14, cornerHeight: 14, transform: nil))
        cg.setFillColor(NSColor.white.withAlphaComponent(0.92).cgColor)
        cg.fillPath()
    }

    // dashed arrow
    cg.setStrokeColor(NSColor.white.withAlphaComponent(0.38).cgColor)
    cg.setLineWidth(3)
    cg.setLineCap(.round)
    cg.setLineDash(phase: 0, lengths: [0.1, 9])
    cg.move(to: CGPoint(x: design.arrow.from, y: iconY))
    cg.addLine(to: CGPoint(x: design.arrow.to - 18, y: iconY))
    cg.strokePath()
    cg.setLineDash(phase: 0, lengths: [])
    cg.setLineWidth(3.5)
    cg.move(to: CGPoint(x: design.arrow.to - 22, y: iconY - 14))
    cg.addLine(to: CGPoint(x: design.arrow.to - 6, y: iconY))
    cg.addLine(to: CGPoint(x: design.arrow.to - 22, y: iconY + 14))
    cg.strokePath()

    NSGraphicsContext.current = nil
    return rep
}

let out = CommandLine.arguments[1]
let marks = [
    "Shima": NSImage(contentsOfFile: CommandLine.arguments[2])!,
    "Kumo": NSImage(contentsOfFile: CommandLine.arguments[3])!,
]
let designs = [
    Design(name: "shima", title: "Shima", subtitle: "Drag Shima into Applications.", tagline: "Your notch, put to work.", marks: ["Shima"], icons: [(180, "Shima"), (480, "Applications")], arrow: (270, 390)),
    Design(name: "kumo", title: "Kumo", subtitle: "Drag Kumo into Applications.", tagline: "Lectures, written down as they happen.", marks: ["Kumo"], icons: [(180, "Kumo"), (480, "Applications")], arrow: (270, 390)),
    Design(name: "bundle", title: "Kumo and Shima", subtitle: "Drag both apps into Applications.", tagline: "Two small Mac apps by Salise Studio.", marks: ["Kumo", "Shima"], icons: [(130, "Kumo"), (270, "Shima"), (530, "Applications")], arrow: (345, 440)),
]
for design in designs {
    for scale in [1, 2] {
        let rep = draw(design, marks: marks, scale: scale)
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(design.name)@\(scale)x.png"))
    }
}
