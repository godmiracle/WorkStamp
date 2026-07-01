import AppKit

let outputDirectory = URL(fileURLWithPath: "/Users/v/XBP/WorkStamp/WorkStamp/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let canvasSize = CGSize(width: 1024, height: 1024)

enum IconVariant: CaseIterable {
    case light
    case dark
    case tinted

    var filename: String {
        switch self {
        case .light:
            return "AppIcon-Light.png"
        case .dark:
            return "AppIcon-Dark.png"
        case .tinted:
            return "AppIcon-Tinted.png"
        }
    }

    var backgroundGradient: [NSColor] {
        switch self {
        case .light:
            return [
                NSColor(calibratedRed: 0.88, green: 0.96, blue: 1.0, alpha: 1.0),
                NSColor(calibratedRed: 0.67, green: 0.84, blue: 1.0, alpha: 1.0),
                NSColor(calibratedRed: 0.80, green: 0.93, blue: 0.98, alpha: 1.0)
            ]
        case .dark:
            return [
                NSColor(calibratedRed: 0.09, green: 0.14, blue: 0.22, alpha: 1.0),
                NSColor(calibratedRed: 0.10, green: 0.28, blue: 0.45, alpha: 1.0),
                NSColor(calibratedRed: 0.05, green: 0.10, blue: 0.16, alpha: 1.0)
            ]
        case .tinted:
            return [
                NSColor(calibratedWhite: 0.94, alpha: 1.0),
                NSColor(calibratedWhite: 0.78, alpha: 1.0),
                NSColor(calibratedWhite: 0.66, alpha: 1.0)
            ]
        }
    }

    var panelFill: NSColor {
        switch self {
        case .light:
            return NSColor.white.withAlphaComponent(0.26)
        case .dark:
            return NSColor.white.withAlphaComponent(0.14)
        case .tinted:
            return NSColor.white.withAlphaComponent(0.34)
        }
    }

    var panelStroke: NSColor {
        switch self {
        case .light:
            return NSColor.white.withAlphaComponent(0.58)
        case .dark:
            return NSColor.white.withAlphaComponent(0.18)
        case .tinted:
            return NSColor.white.withAlphaComponent(0.70)
        }
    }

    var primaryGlyph: NSColor {
        switch self {
        case .light:
            return NSColor.white.withAlphaComponent(0.96)
        case .dark:
            return NSColor(calibratedRed: 0.92, green: 0.98, blue: 1.0, alpha: 0.94)
        case .tinted:
            return NSColor(calibratedWhite: 1.0, alpha: 0.95)
        }
    }

    var secondaryGlyph: NSColor {
        switch self {
        case .light:
            return NSColor(calibratedRed: 0.62, green: 0.86, blue: 1.0, alpha: 0.78)
        case .dark:
            return NSColor(calibratedRed: 0.38, green: 0.83, blue: 1.0, alpha: 0.55)
        case .tinted:
            return NSColor(calibratedWhite: 0.90, alpha: 0.78)
        }
    }
}

func drawLinearGradient(in rect: CGRect, colors: [NSColor], angle: CGFloat) {
    guard let gradient = NSGradient(colors: colors) else { return }
    gradient.draw(in: NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220), angle: angle)
}

func drawOrb(center: CGPoint, radius: CGFloat, colors: [NSColor], stroke: NSColor) {
    let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    let path = NSBezierPath(ovalIn: rect)

    guard let gradient = NSGradient(colors: colors) else { return }
    gradient.draw(in: path, relativeCenterPosition: NSPoint(x: -0.22, y: 0.24))

    stroke.setStroke()
    path.lineWidth = 2
    path.stroke()
}

func makeImage(for variant: IconVariant) -> NSImage {
    let image = NSImage(size: canvasSize)
    image.lockFocus()

    let bounds = CGRect(origin: .zero, size: canvasSize)
    drawLinearGradient(in: bounds, colors: variant.backgroundGradient, angle: 55)

    let glow = NSBezierPath(ovalIn: CGRect(x: 96, y: 520, width: 600, height: 420))
    NSColor.white.withAlphaComponent(variant == .dark ? 0.08 : 0.18).setFill()
    glow.fill()

    let panelRect = CGRect(x: 168, y: 144, width: 688, height: 736)
    let panel = NSBezierPath(roundedRect: panelRect, xRadius: 180, yRadius: 180)
    variant.panelFill.setFill()
    panel.fill()

    variant.panelStroke.setStroke()
    panel.lineWidth = 3
    panel.stroke()

    let highlight = NSBezierPath(roundedRect: CGRect(x: 210, y: 652, width: 500, height: 128), xRadius: 64, yRadius: 64)
    NSColor.white.withAlphaComponent(variant == .dark ? 0.08 : 0.22).setFill()
    highlight.fill()

    drawOrb(
        center: CGPoint(x: 512, y: 510),
        radius: 184,
        colors: [
            variant.primaryGlyph.withAlphaComponent(0.24),
            variant.secondaryGlyph.withAlphaComponent(0.10),
            NSColor.clear
        ],
        stroke: NSColor.white.withAlphaComponent(variant == .dark ? 0.18 : 0.40)
    )

    drawOrb(
        center: CGPoint(x: 512, y: 510),
        radius: 122,
        colors: [
            variant.primaryGlyph.withAlphaComponent(0.78),
            variant.secondaryGlyph.withAlphaComponent(0.24)
        ],
        stroke: NSColor.white.withAlphaComponent(variant == .dark ? 0.30 : 0.55)
    )

    let innerLens = NSBezierPath(ovalIn: CGRect(x: 452, y: 450, width: 120, height: 120))
    NSColor.white.withAlphaComponent(variant == .dark ? 0.20 : 0.34).setFill()
    innerLens.fill()

    let pinPath = NSBezierPath()
    pinPath.move(to: CGPoint(x: 512, y: 340))
    pinPath.curve(to: CGPoint(x: 610, y: 472), controlPoint1: CGPoint(x: 582, y: 360), controlPoint2: CGPoint(x: 642, y: 410))
    pinPath.curve(to: CGPoint(x: 512, y: 656), controlPoint1: CGPoint(x: 610, y: 564), controlPoint2: CGPoint(x: 566, y: 636))
    pinPath.curve(to: CGPoint(x: 414, y: 472), controlPoint1: CGPoint(x: 458, y: 636), controlPoint2: CGPoint(x: 414, y: 564))
    pinPath.curve(to: CGPoint(x: 512, y: 340), controlPoint1: CGPoint(x: 382, y: 410), controlPoint2: CGPoint(x: 442, y: 360))
    pinPath.close()

    variant.primaryGlyph.withAlphaComponent(0.22).setFill()
    pinPath.fill()

    variant.primaryGlyph.withAlphaComponent(0.92).setStroke()
    pinPath.lineWidth = 18
    pinPath.lineJoinStyle = .round
    pinPath.stroke()

    let clockRing = NSBezierPath(ovalIn: CGRect(x: 448, y: 428, width: 128, height: 128))
    variant.primaryGlyph.setStroke()
    clockRing.lineWidth = 16
    clockRing.stroke()

    let hourHand = NSBezierPath()
    hourHand.move(to: CGPoint(x: 512, y: 492))
    hourHand.line(to: CGPoint(x: 512, y: 548))
    hourHand.lineWidth = 14
    hourHand.lineCapStyle = .round
    variant.primaryGlyph.setStroke()
    hourHand.stroke()

    let minuteHand = NSBezierPath()
    minuteHand.move(to: CGPoint(x: 512, y: 492))
    minuteHand.line(to: CGPoint(x: 552, y: 462))
    minuteHand.lineWidth = 12
    minuteHand.lineCapStyle = .round
    variant.secondaryGlyph.setStroke()
    minuteHand.stroke()

    let topSpec = NSBezierPath()
    topSpec.move(to: CGPoint(x: 294, y: 804))
    topSpec.curve(to: CGPoint(x: 676, y: 758), controlPoint1: CGPoint(x: 408, y: 862), controlPoint2: CGPoint(x: 582, y: 834))
    topSpec.lineWidth = 24
    topSpec.lineCapStyle = .round
    NSColor.white.withAlphaComponent(variant == .dark ? 0.10 : 0.28).setStroke()
    topSpec.stroke()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "IconWriter", code: 1)
    }

    try pngData.write(to: url)
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for variant in IconVariant.allCases {
    let image = makeImage(for: variant)
    let url = outputDirectory.appendingPathComponent(variant.filename)
    try writePNG(image, to: url)
    print("Wrote \(url.path)")
}
