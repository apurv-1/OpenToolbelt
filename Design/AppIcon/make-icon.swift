// Draws the 1024px app icon. scripts/build-app.sh turns it into AppIcon.icns.
// The menu bar glyph is drawn in app code: Sources/OpenSkillsApp/MenuBarIcon.swift.
// Usage: swift -O make-icon.swift <output-dir>
import AppKit

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: a)
}
func grad(_ colors: [CGColor], _ locs: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: locs)!
}
func point(_ c: CGPoint, _ r: CGFloat, _ deg: CGFloat) -> CGPoint {
    let t = deg * .pi / 180; return CGPoint(x: c.x + r * sin(t), y: c.y + r * cos(t))
}
func circle(_ c: CGPoint, _ r: CGFloat) -> CGRect { CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r) }

/// A conic fade: brightest at the beam (clock angle `lead`), gone `trail` degrees behind it.
func sweepImage(center c: CGPoint, radius R: CGFloat, lead: CGFloat, trail: CGFloat) -> CGImage {
    let n = 1024
    var px = [UInt8](repeating: 0, count: n * n * 4)
    for y in 0..<n {
        for x in 0..<n {
            let dx = CGFloat(x) + 0.5 - c.x, dy = CGFloat(n - 1 - y) + 0.5 - c.y
            let d = (dx * dx + dy * dy).squareRoot()
            guard d < R + 2 else { continue }
            var clock = atan2(dx, dy) * 180 / .pi
            if clock < 0 { clock += 360 }
            var behind = lead - clock
            if behind < 0 { behind += 360 }
            guard behind <= trail else { continue }
            let a = 0.78 * pow(1 - behind / trail, 1.8) * min(1, max(0, R + 1 - d))
            let i = (y * n + x) * 4
            // Premultiplied mint (0x2FE0A0).
            px[i] = UInt8(47 * a); px[i + 1] = UInt8(224 * a); px[i + 2] = UInt8(160 * a); px[i + 3] = UInt8(255 * a)
        }
    }
    let provider = CGDataProvider(data: Data(px) as CFData)!
    return CGImage(width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4,
                   space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
}

struct Tile { var top, bottom, bezelTop, bezelBottom: CGColor }
let graphite = Tile(top: rgb(0x2C3236), bottom: rgb(0x0E1113), bezelTop: rgb(0x8C959B), bezelBottom: rgb(0x23282C))
let mint = rgb(0x7CF8C8)

func draw(_ t: Tile, _ ctx: CGContext) {
    let tileRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tile = CGPath(roundedRect: tileRect, cornerWidth: 185, cornerHeight: 185, transform: nil)
    // Tile with drop shadow.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 44, color: rgb(0x000000, 0.35))
    ctx.addPath(tile); ctx.setFillColor(t.bottom); ctx.fillPath(); ctx.restoreGState()
    ctx.saveGState(); ctx.addPath(tile); ctx.clip()
    ctx.drawLinearGradient(grad([t.top, t.bottom]), start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    let c = CGPoint(x: 512, y: 512), bezelR: CGFloat = 310, R: CGFloat = 272

    // Bezel: brushed-metal ring casting a soft shadow on the tile.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 36, color: rgb(0x000000, 0.45))
    ctx.addEllipse(in: circle(c, bezelR)); ctx.setFillColor(t.bezelBottom); ctx.fillPath(); ctx.restoreGState()
    ctx.saveGState(); ctx.addEllipse(in: circle(c, bezelR)); ctx.clip()
    ctx.drawLinearGradient(grad([t.bezelTop, t.bezelBottom]), start: CGPoint(x: 512, y: 512 + bezelR), end: CGPoint(x: 512, y: 512 - bezelR), options: [])
    ctx.restoreGState()
    // Inner lip, lit from below so the screen reads as recessed.
    ctx.saveGState(); ctx.addEllipse(in: circle(c, R + 12)); ctx.clip()
    ctx.drawLinearGradient(grad([rgb(0x000000, 0.55), rgb(0xFFFFFF, 0.25)]), start: CGPoint(x: 512, y: 512 + R), end: CGPoint(x: 512, y: 512 - R), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()

    // Screen.
    ctx.saveGState(); ctx.addEllipse(in: circle(c, R)); ctx.clip()
    ctx.drawRadialGradient(grad([rgb(0x123A2E), rgb(0x061410), rgb(0x020806)], [0, 0.7, 1]), startCenter: c, startRadius: 0, endCenter: c, endRadius: R, options: [])

    // Graticule.
    ctx.setStrokeColor(rgb(0x7CF8C8, 0.16)); ctx.setLineWidth(4)
    for r in [R * 0.36, R * 0.70] { ctx.addEllipse(in: circle(c, r)); ctx.strokePath() }
    ctx.setStrokeColor(rgb(0x7CF8C8, 0.10)); ctx.setLineWidth(3)
    ctx.move(to: CGPoint(x: c.x - R, y: c.y)); ctx.addLine(to: CGPoint(x: c.x + R, y: c.y))
    ctx.move(to: CGPoint(x: c.x, y: c.y - R)); ctx.addLine(to: CGPoint(x: c.x, y: c.y + R)); ctx.strokePath()

    // Phosphor sweep trailing the beam, computed per pixel so it is smooth.
    let lead: CGFloat = 50, trail: CGFloat = 100
    ctx.draw(sweepImage(center: c, radius: R, lead: lead, trail: trail), in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    // Edge vignette sits under the beam so the glow stays bright.
    ctx.drawRadialGradient(grad([rgb(0x000000, 0), rgb(0x000000, 0.55)], [0.72, 1]), startCenter: c, startRadius: 0, endCenter: c, endRadius: R, options: [])

    // Beam, blips and hub, with bloom.
    ctx.setLineCap(.round)
    ctx.saveGState(); ctx.setShadow(offset: .zero, blur: 26, color: mint)
    ctx.setStrokeColor(mint); ctx.setLineWidth(9)
    ctx.move(to: c); ctx.addLine(to: point(c, R, lead)); ctx.strokePath()
    ctx.setShadow(offset: .zero, blur: 46, color: mint)
    let hit = point(c, R * 0.70, lead - 13)
    ctx.setFillColor(rgb(0xD8FFEF)); ctx.fillEllipse(in: circle(hit, 20)); ctx.fillEllipse(in: circle(hit, 20))
    ctx.setShadow(offset: .zero, blur: 18, color: mint)
    ctx.fillEllipse(in: circle(c, 13))
    ctx.restoreGState()
    let dim = point(c, R * 0.62, 232)
    ctx.setFillColor(rgb(0x7CF8C8, 0.30)); ctx.fillEllipse(in: circle(dim, 13))

    // Glass reflection across the top.
    let glare = CGRect(x: c.x - R * 0.80, y: c.y + R * 0.18, width: R * 1.60, height: R * 0.86)
    ctx.addEllipse(in: glare); ctx.clip()
    ctx.drawLinearGradient(grad([rgb(0xFFFFFF, 0.11), rgb(0xFFFFFF, 0.0)]), start: CGPoint(x: c.x, y: glare.maxY), end: CGPoint(x: c.x, y: glare.minY), options: [])
    ctx.restoreGState()

    ctx.restoreGState()
    ctx.addPath(tile); ctx.setStrokeColor(rgb(0xFFFFFF, 0.10)); ctx.setLineWidth(2); ctx.strokePath()
}


func png(_ width: Int, _ height: Int, _ name: String, _ body: (CGContext) -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    body(NSGraphicsContext(bitmapImageRep: rep)!.cgContext)
    let out = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(name)
    try! rep.representation(using: .png, properties: [:])!.write(to: out)
}

png(1024, 1024, "AppIcon-1024.png") { draw(graphite, $0) }
