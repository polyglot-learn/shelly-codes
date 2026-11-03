// Draws the 1024×1024 app icon: Shelly the turtle drawing a line towards a star.
// Usage: swift scripts/make_icon.swift ShellyCodes/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import AppKit

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: make_icon.swift <output.png>\n".data(using: .utf8)!)
    exit(2)
}

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let size = 1024
// Opaque, as the App Store requires.
let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

// Background: a warm sky-to-mint gradient.
let gradient = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [rgb(0x7FD8F0), rgb(0xB8F2C8)] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])

// A faint grid, like Shelly's canvas.
ctx.setStrokeColor(rgb(0xFFFFFF, 0.35))
ctx.setLineWidth(4)
for i in stride(from: 0, through: 1024, by: 128) {
    ctx.move(to: CGPoint(x: i, y: 0))
    ctx.addLine(to: CGPoint(x: i, y: 1024))
    ctx.move(to: CGPoint(x: 0, y: i))
    ctx.addLine(to: CGPoint(x: 1024, y: i))
}
ctx.strokePath()

// Shelly walks diagonally towards a star, drawing an orange line behind her.
let heading = 45.0
let s: CGFloat = 540
let shelly = CGPoint(x: 500, y: 500)
ctx.setLineCap(.round)
ctx.setStrokeColor(rgb(0xFF8A3D))
ctx.setLineWidth(40)
ctx.move(to: CGPoint(x: 120, y: 120))
ctx.addLine(to: shelly)
ctx.strokePath()

func star(center: CGPoint, radius: CGFloat) {
    for i in 0..<10 {
        let r = i % 2 == 0 ? radius : radius * 0.45
        let angle = (90 + Double(i) * 36) * .pi / 180
        let point = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
        if i == 0 { ctx.move(to: point) } else { ctx.addLine(to: point) }
    }
    ctx.closePath()
}
star(center: CGPoint(x: 855, y: 855), radius: 105)
ctx.setFillColor(rgb(0xFFC233))
ctx.setStrokeColor(rgb(0xF59E0B))
ctx.setLineWidth(12)
ctx.setLineJoin(.round)
ctx.drawPath(using: .fillStroke)

// Shelly, facing along the trail.
func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
    CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h)
}
ctx.saveGState()
ctx.translateBy(x: shelly.x, y: shelly.y)
ctx.rotate(by: heading * .pi / 180)
let skin = rgb(0x9BD770)
let skinDark = rgb(0x4E8A2E)
ctx.setLineWidth(0.025 * s)
for (x, y) in [(0.2, -0.28), (0.2, 0.28), (-0.22, -0.26), (-0.22, 0.26)] {
    let leg = ellipse(x * s, y * s, 0.2 * s, 0.17 * s)
    ctx.setFillColor(skin)
    ctx.fillEllipse(in: leg)
    ctx.setStrokeColor(skinDark)
    ctx.strokeEllipse(in: leg)
}
ctx.move(to: CGPoint(x: -0.32 * s, y: -0.06 * s))
ctx.addLine(to: CGPoint(x: -0.5 * s, y: 0))
ctx.addLine(to: CGPoint(x: -0.32 * s, y: 0.06 * s))
ctx.closePath()
ctx.setFillColor(skin)
ctx.fillPath()
let head = ellipse(0.4 * s, 0, 0.27 * s, 0.24 * s)
ctx.setFillColor(skin)
ctx.fillEllipse(in: head)
ctx.setStrokeColor(skinDark)
ctx.strokeEllipse(in: head)
for y in [-0.06, 0.06] {
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillEllipse(in: ellipse(0.46 * s, y * s, 0.075 * s, 0.075 * s))
    ctx.setFillColor(rgb(0x000000))
    ctx.fillEllipse(in: ellipse(0.475 * s, y * s, 0.042 * s, 0.042 * s))
}
let body = ellipse(0, 0, 0.66 * s, 0.56 * s)
ctx.setFillColor(rgb(0x2FBF71))
ctx.fillEllipse(in: body)
ctx.setFillColor(rgb(0x1E8C50))
ctx.fillEllipse(in: ellipse(0, 0, 0.36 * s, 0.3 * s))
for angle in stride(from: 0.0, to: 360.0, by: 60.0) {
    let r = angle * .pi / 180
    ctx.fillEllipse(in: ellipse(0.24 * s * cos(r), 0.2 * s * sin(r), 0.1 * s, 0.09 * s))
}
ctx.setStrokeColor(rgb(0x1E8C50))
ctx.setLineWidth(0.035 * s)
ctx.strokeEllipse(in: body)
ctx.setFillColor(rgb(0xFFFFFF, 0.35))
ctx.fillEllipse(in: ellipse(-0.08 * s, 0.12 * s, 0.14 * s, 0.07 * s))
ctx.restoreGState()

let png = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
