#if DEBUG
import AppKit
import OpenToolbeltCore
import SwiftUI

/// Debug-only: renders the 30-second launch video, frame by frame, from the
/// app's own views and shader. Frames stream into ffmpeg as raw pixels.
/// Usage: swift run OpenToolbeltApp --promo <out.mp4> --home <demo home>
@MainActor
enum Promo {
    static let size = CGSize(width: 1920, height: 1080)
    static let fps = 30.0
    static let duration = 30.0

    static func render(to output: URL, home: URL) {
        let store = Store()
        store.apply(Audit.run(home: home))
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        let icon = NSImage(contentsOfFile: "Design/AppIcon/AppIcon-1024.png")

        let ffmpeg = Process()
        ffmpeg.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        ffmpeg.arguments = ["-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "bgra",
                            "-s", "\(Int(size.width))x\(Int(size.height))", "-r", "\(Int(fps))", "-i", "-",
                            "-c:v", "libx264", "-preset", "slow", "-crf", "16", "-pix_fmt", "yuv420p",
                            "-movflags", "+faststart", output.path]
        let pipe = Pipe()
        ffmpeg.standardInput = pipe
        try! ffmpeg.run()

        let frames = Int(duration * fps)
        for index in 0..<frames {
            let t = Double(index) / fps
            var frame: CGImage?
            // The app's dynamic colors resolve against the drawing appearance; dark matches the reference.
            NSAppearance(named: .darkAqua)!.performAsCurrentDrawingAppearance {
                let renderer = ImageRenderer(content: PromoFrame(t: t, icon: icon).environment(store)
                    .frame(width: size.width, height: size.height))
                renderer.scale = 1
                frame = renderer.cgImage
            }
            guard let image = frame else { continue }
            pipe.fileHandleForWriting.write(bgra(image))
            if index % 60 == 0 { print("frame \(index)/\(frames)") }
        }
        try? pipe.fileHandleForWriting.close()
        ffmpeg.waitUntilExit()
        print("Wrote \(output.path)")
    }

    private static func bgra(_ image: CGImage) -> Data {
        let width = Int(size.width), height = Int(size.height)
        var data = Data(count: width * height * 4)
        data.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                    bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return data
    }
}

// MARK: Timing

/// 0 to 1 over [start, start + length], eased out.
private func ease(_ t: Double, _ start: Double, _ length: Double = 0.6) -> Double {
    let x = min(max((t - start) / length, 0), 1)
    return 1 - pow(1 - x, 3)
}

/// A soft overshoot, for things that pop in.
private func pop(_ t: Double, _ start: Double, _ length: Double = 0.5) -> Double {
    let x = min(max((t - start) / length, 0), 1)
    let c = 1.6
    return 1 + (c + 1) * pow(x - 1, 3) + c * pow(x - 1, 2)
}

/// Visible between start and end, with short fades at both edges.
private func window(_ t: Double, _ start: Double, _ end: Double, fade: Double = 0.35) -> Double {
    min(ease(t, start, fade), 1 - ease(t, end - fade, fade))
}

private let ink = Color(nsColor: NSColor(hex: 0x111214))
private let paper = Color(nsColor: NSColor(hex: 0xF4F4F2))
private let mint = Color(nsColor: NSColor(hex: 0x6EE7B7))
private let mintInk = Color(nsColor: NSColor(hex: 0x059669))

// MARK: Frame

struct PromoFrame: View {
    @Environment(Store.self) private var store
    var t: Double
    var icon: NSImage?

    var body: some View {
        ZStack {
            if t < 4.2 { Opening(t: t).opacity(1 - ease(t, 3.8, 0.4)) }
            if t >= 3.8 && t < 13.4 { PileUp(t: t).opacity(window(t, 3.8, 13.4, fade: 0.4)) }
            if t >= 13 && t < 17.4 { TokenCount(t: t).opacity(window(t, 13, 17.4, fade: 0.4)) }
            if t >= 17 && t < 26.4 { Product(t: t).opacity(window(t, 17, 26.4, fade: 0.4)) }
            if t >= 26 { EndCard(t: t, icon: icon).opacity(ease(t, 26, 0.5)) }
        }
        .background(Color.black)
    }
}

/// Headline words rise in one after another.
private struct Kinetic: View {
    var text: String
    var t: Double
    var start: Double
    var size: CGFloat = 84
    var color: Color = ink

    var body: some View {
        let words = text.split(separator: " ").map(String.init)
        HStack(spacing: size * 0.24) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                let p = ease(t, start + Double(index) * 0.09, 0.5)
                Text(word)
                    .font(.system(size: size, weight: .semibold))
                    .tracking(-size * 0.025)
                    .foregroundStyle(color)
                    .opacity(p)
                    .offset(y: (1 - p) * size * 0.35)
                    .blur(radius: (1 - p) * 6)
            }
        }
    }
}

// MARK: 0–4s: radar, agents light up

private struct Opening: View {
    @Environment(Store.self) private var store
    var t: Double

    var body: some View {
        ZStack {
            ShaderView(kind: .radar(blips: store.blips()), scopeRadius: 430, time: t * 1.15 + 3)
            ForEach(Array(Agent.allCases.enumerated()), id: \.offset) { index, agent in
                let angle = Double(index) / 6 * 2 * .pi - .pi / 2
                let p = pop(t, 0.5 + Double(index) * 0.32)
                VStack(spacing: 14) {
                    AgentIcon(agent: agent, size: 64)
                        .padding(20)
                        .background(.white.opacity(0.08), in: .rect(cornerRadius: 26))
                        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(.white.opacity(0.14), lineWidth: 1))
                    Text(agent.displayName).font(.system(size: 22, weight: .medium)).foregroundStyle(.white.opacity(0.85))
                }
                .scaleEffect(max(p, 0.001))
                .opacity(min(p, 1))
                .offset(x: cos(angle) * 300, y: sin(angle) * 300)
            }
        }
    }
}

// MARK: 4–13s: skills pile up, then most go quiet

private struct PileUp: View {
    @Environment(Store.self) private var store
    var t: Double

    private struct Chip { var name: String; var kind: ItemKind; var used: Bool; var x: CGFloat; var y: CGFloat }

    private var chips: [Chip] {
        let used: Set<String> = ["github", "pdf", "systematic-debugging"]
        let names: [(String, ItemKind)] = [
            ("pdf", .skill), ("docx", .skill), ("xlsx", .skill), ("skill-creator", .skill), ("brainstorming", .skill),
            ("systematic-debugging", .skill), ("test-driven-development", .skill), ("frontend-design", .skill),
            ("web-design-guidelines", .skill), ("github", .mcpServer), ("postgres", .mcpServer), ("sentry", .mcpServer),
            ("linear-issues", .skill), ("sentry-triage", .skill), ("release-notes", .skill), ("filesystem", .mcpServer),
            ("puppeteer", .mcpServer), ("changelog", .skill), ("figma", .mcpServer), ("linear-cycles", .skill),
        ]
        // Fixed positions in a loose ring around the headline.
        let spots: [(CGFloat, CGFloat)] = [
            (-700, -360), (-360, -400), (40, -420), (420, -390), (700, -340), (-760, -150), (690, -170),
            (-780, 60), (690, 40), (-760, 260), (760, 250), (-520, 390), (-160, 420), (220, 410), (560, 380),
            (-420, -250), (440, -240), (-480, 230), (480, 220), (0, 300),
        ]
        return zip(names, spots).map { Chip(name: $0.0.0, kind: $0.0.1, used: used.contains($0.0.0), x: $0.1.0, y: $0.1.1) }
    }

    var body: some View {
        let quiet = ease(t, 9.2, 0.8)
        ZStack {
            paper
            Grid()
            ForEach(Array(chips.enumerated()), id: \.offset) { index, chip in
                let p = pop(t, 4.3 + Double(index) * 0.11, 0.55)
                let dim = chip.used ? 0 : quiet
                HStack(spacing: 10) {
                    ItemTile(kind: chip.kind, name: chip.name, size: 26)
                    Text(chip.name).font(.system(size: 22, weight: .medium)).foregroundStyle(ink)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(.white, in: .rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(chip.used ? mintInk.opacity(quiet) : .black.opacity(0.06), lineWidth: chip.used ? 2 : 1))
                .shadow(color: chip.used ? mint.opacity(0.5 * quiet) : .black.opacity(0.06), radius: chip.used ? 18 : 10, y: 4)
                .saturation(1 - dim)
                .opacity(min(p, 1) * (1 - 0.6 * dim))
                .scaleEffect(max(p, 0.001) * (1 - 0.06 * dim))
                .offset(x: chip.x, y: chip.y)
            }
            VStack(spacing: 22) {
                ZStack {
                    Kinetic(text: "Your agents carry a lot.", t: t, start: 4.9).opacity(1 - ease(t, 8.9, 0.3))
                    Kinetic(text: "Most of it never runs.", t: t, start: 9.3)
                }
                ZStack {
                    Text("\(store.rows(.skills).count) skills · \(store.rows(.mcpServers).count) MCP servers · 6 agents")
                        .opacity(ease(t, 5.8) * (1 - ease(t, 8.9, 0.3)))
                    Text("Nine of ten skills were never called once.")
                        .opacity(ease(t, 10.2))
                }
                .font(.system(size: 28)).foregroundStyle(ink.opacity(0.55))
            }
        }
    }
}

/// The faint 60pt grid behind the light scenes.
private struct Grid: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            for x in stride(from: 0, through: size.width, by: 60) {
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0, through: size.height, by: 60) {
                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(.black.opacity(0.045)), lineWidth: 1)
        }
    }
}

// MARK: 13–17s: the cost

private struct TokenCount: View {
    var t: Double

    var body: some View {
        let count = Int(8500 * ease(t, 13.6, 1.8))
        ZStack {
            Color(nsColor: NSColor(hex: 0x0B0C0E))
            VStack(spacing: 18) {
                Kinetic(text: "It still costs you.", t: t, start: 13.2, size: 44, color: .white.opacity(0.7))
                Text(count.formatted(.number))
                    .font(.system(size: 220, weight: .semibold).monospacedDigit())
                    .tracking(-6)
                    .foregroundStyle(mint)
                    .shadow(color: mint.opacity(0.35), radius: 40)
                Text("tokens, every session, spent listing skills before you type a word.")
                    .font(.system(size: 30)).foregroundStyle(.white.opacity(0.6))
                    .opacity(ease(t, 15))
                Text("Measured on a real Claude Code setup.")
                    .font(.system(size: 20)).foregroundStyle(.white.opacity(0.35))
                    .opacity(ease(t, 15.6))
            }
        }
    }
}

// MARK: 17–26s: the app

private struct Product: View {
    @Environment(Store.self) private var store
    var t: Double

    var body: some View {
        let slide = ease(t, 17.2, 0.9)
        let trim = t >= 21.6
        ZStack(alignment: .leading) {
            paper
            Grid()
            VStack(alignment: .leading, spacing: 16) {
                ZStack(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Kinetic(text: "See it all.", t: t, start: 17.5)
                        Kinetic(text: "In one place.", t: t, start: 17.8)
                    }
                    .opacity(1 - ease(t, 21.4, 0.3))
                    VStack(alignment: .leading, spacing: 0) {
                        Kinetic(text: "Trim in", t: t, start: 21.8)
                        Kinetic(text: "one click.", t: t, start: 22.0)
                    }
                }
                ZStack(alignment: .leading) {
                    Text("Every skill and MCP server,\nacross six agents.").opacity(ease(t, 18.6) * (1 - ease(t, 21.4, 0.3)))
                    Text("Unused skills come off.\nThe token bill drops.").opacity(ease(t, 22.6))
                }
                .font(.system(size: 28)).foregroundStyle(ink.opacity(0.55))
            }
            .padding(.leading, 140)

            Group {
                if trim { TrimCard(t: t) } else { AppWindow() }
            }
            .scaleEffect(trim ? 1 : 0.7, anchor: .leading)
            .rotation3DEffect(.degrees((1 - slide) * 18), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .offset(x: trim ? 860 : 780 + (1 - slide) * 400, y: trim ? 0 : 150)
            .opacity(slide)
            .shadow(color: .black.opacity(0.25), radius: 50, y: 24)
        }
    }
}

/// The real window, built from the app's own views.
private struct AppWindow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Sidebar().frame(width: 216).frame(maxHeight: .infinity).background(Theme.Palette.sidebar)
                .overlay(alignment: .trailing) { Rectangle().fill(Theme.Palette.hairline).frame(width: 1) }
            VStack(spacing: 0) {
                PageBar(title: "Overview", detail: nil) { AddSkillsButton() }
                OverviewContent().padding(Theme.Space.lg)
                Spacer(minLength: 0)
            }
            .background(Theme.Palette.canvas)
        }
        .frame(width: 1240, height: 1180, alignment: .top)
        .clipShape(.rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}

/// A suggestion being acted on, with the per-session cost falling.
private struct TrimCard: View {
    var t: Double

    var body: some View {
        let pressed = t >= 23.4 && t < 23.6
        let drop = ease(t, 23.6, 1.4)
        let tokens = Int(8500 - 7700 * drop)
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Context per session").font(.system(size: 22)).foregroundStyle(.white.opacity(0.55))
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(tokens.formatted(.number)).font(.system(size: 72, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                    Text("tokens").font(.system(size: 26)).foregroundStyle(.white.opacity(0.5))
                }
            }
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
            HStack(spacing: 18) {
                AgentIcon(agent: .claudeCode, size: 34)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Trim 53 unused skills from Claude Code").font(.system(size: 26, weight: .medium)).foregroundStyle(.white)
                    Text("Every session loads their descriptions.").font(.system(size: 20)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer(minLength: 24)
                Text("−7.7k tokens").font(.system(size: 22, weight: .medium).monospacedDigit()).foregroundStyle(mint)
                Text(drop > 0.05 ? "Trimmed" : "Review")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(drop > 0.05 ? mint : .white.opacity(0.85))
                    .padding(.horizontal, 18).frame(height: 44)
                    .background(.white.opacity(pressed ? 0.18 : 0.06), in: .rect(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.12), lineWidth: 1))
                    .scaleEffect(pressed ? 0.95 : 1)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "cursorarrow").font(.system(size: 34)).foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 4)
                            .offset(x: 16 + (1 - ease(t, 22.4, 1.0)) * 220, y: 24 + (1 - ease(t, 22.4, 1.0)) * 140)
                            .opacity(ease(t, 22.2, 0.3) * (1 - ease(t, 24.6, 0.3)))
                    }
            }
        }
        .padding(40)
        .frame(width: 920, alignment: .leading)
        .background(Color(nsColor: NSColor(hex: 0x131416)), in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.1), lineWidth: 1))
    }
}

// MARK: 26–30s: end card

private struct EndCard: View {
    @Environment(Store.self) private var store
    var t: Double
    var icon: NSImage?

    var body: some View {
        ZStack {
            ShaderView(kind: .radar(blips: store.blips()), scopeRadius: 520, time: t * 0.9)
                .blur(radius: 18)
                .overlay(Color.black.opacity(0.45))
            VStack(spacing: 22) {
                HStack(spacing: 26) {
                    if let icon {
                        Image(nsImage: icon).resizable().frame(width: 132, height: 132)
                            .scaleEffect(max(pop(t, 26.2), 0.001))
                    }
                    Text("OpenToolbelt").font(.system(size: 104, weight: .semibold)).tracking(-3).foregroundStyle(.white)
                        .opacity(ease(t, 26.4))
                }
                Text("Know what your agents carry.").font(.system(size: 40, weight: .medium)).foregroundStyle(.white.opacity(0.9))
                    .opacity(ease(t, 27.0))
                Text("Free and open source · github.com/apurv-1/OpenToolbelt")
                    .font(.system(size: 24)).foregroundStyle(.white.opacity(0.55))
                    .opacity(ease(t, 27.5))
            }
        }
    }
}
#endif
