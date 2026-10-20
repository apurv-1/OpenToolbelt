import AppKit

/// The menu bar glyph: a ring with a sweep whose bright edge is the beam.
/// Drawn in code as a template image, so macOS tints it for light and dark
/// menu bars and it stays sharp at any scale.
enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let center = CGPoint(x: 9, y: 9), ring: CGFloat = 1.4
            let lead: CGFloat = 45, trail: CGFloat = 180, steps = 120
            let radius = 7.4 - ring / 2
            for i in 0..<steps {
                let fraction = CGFloat(i + 1) / CGFloat(steps)
                let start = lead - trail + trail * CGFloat(i) / CGFloat(steps)
                let end = min(start + trail / CGFloat(steps) + 0.3, lead)
                ctx.move(to: center)
                ctx.addArc(center: center, radius: radius, startAngle: (90 - start) * .pi / 180,
                           endAngle: (90 - end) * .pi / 180, clockwise: true)
                ctx.closePath()
                ctx.setFillColor(NSColor.black.withAlphaComponent(pow(fraction, 1.15)).cgColor)
                ctx.fillPath()
            }
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(ring)
            ctx.strokeEllipse(in: CGRect(x: 1 + ring / 2, y: 1 + ring / 2, width: 16 - ring, height: 16 - ring))
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "OpenSkills"
        return image
    }()
}
