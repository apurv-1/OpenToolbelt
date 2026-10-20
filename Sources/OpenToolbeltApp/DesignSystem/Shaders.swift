import Metal
import SwiftUI

/// GPU shader backdrops. The Metal source compiles at runtime with the Metal
/// framework, so building the app needs no offline Metal toolchain.
enum ShaderSource {
    static let msl = """
    #include <metal_stdlib>
    using namespace metal;

    // frame: size.xy (px), time (s), display scale
    // scope: center.xy (px), radius (px)
    // meta:  blip count
    // blips: clock angle (rad), radius fraction, intensity
    struct Uniforms { float4 frame; float4 scope; float4 meta; float4 blips[16]; };
    struct VOut { float4 pos [[position]]; float2 uv; };

    constant float3 MINT = float3(0.486, 0.973, 0.784);
    constant float3 PHOSPHOR = float3(0.184, 0.878, 0.627);
    constant float TAU = 6.2831853;

    vertex VOut fullscreen(uint vid [[vertex_id]]) {
        float2 p = float2((vid << 1) & 2, vid & 2);
        VOut o;
        o.pos = float4(p * 2.0 - 1.0, 0.0, 1.0);
        o.uv = float2(p.x, 1.0 - p.y);
        return o;
    }

    float hash(float2 p) { return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453); }
    float wrap(float a) { return a - TAU * floor(a / TAU); }

    // A radar scope: graticule, a phosphor sweep, and blips that flare as the beam passes.
    fragment float4 radar(VOut in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
        float2 size = u.frame.xy; float t = u.frame.z; float s = u.frame.w;
        float2 p = in.uv * size, c = u.scope.xy; float R = u.scope.z;
        float2 d = p - c; float r = length(d);
        float inside = smoothstep(R + s, R - s, r);

        float3 col = mix(float3(0.051, 0.082, 0.078), float3(0.020, 0.031, 0.031), saturate(in.uv.y * 0.9 + 0.1));
        col += PHOSPHOR * 0.14 * exp(-(r * r) / (R * R * 1.2));

        float ring = 0.0;
        for (int k = 1; k <= 3; k++) {
            float rr = R * float(k) / 3.0;
            ring += (1.0 - smoothstep(0.0, 1.0 * s, abs(r - rr))) * (k == 3 ? 0.42 : 0.13);
        }
        float cross = (1.0 - smoothstep(0.0, 0.7 * s, min(abs(d.x), abs(d.y)))) * 0.07 * inside;
        col += MINT * (ring + cross);

        float lead = wrap(t * 0.85);
        float behind = wrap(lead - atan2(d.x, -d.y));
        float trail = 1.9;
        float sweep = behind < trail ? pow(1.0 - behind / trail, 2.4) : 0.0;
        col += PHOSPHOR * 0.40 * sweep * inside;
        float beam = (1.0 - smoothstep(0.0, 1.4 * s, r * abs(sin(behind)))) * step(0.0, cos(behind)) * inside;
        col += MINT * 0.85 * beam;

        int count = int(u.meta.x);
        for (int i = 0; i < count; i++) {
            float4 b = u.blips[i];
            float2 bp = c + R * b.y * float2(sin(b.x), -cos(b.x));
            float dist = length(p - bp);
            float since = wrap(lead - b.x);
            float flare = b.z * (0.30 + 0.70 * exp(-since * 1.3));
            float dotMask = 1.0 - smoothstep(2.0 * s, 3.2 * s, dist);
            float glow = exp(-(dist * dist) / (40.0 * s * s)) * 0.55;
            col += MINT * (dotMask + glow) * flare;
        }
        col += MINT * (1.0 - smoothstep(2.0 * s, 3.0 * s, r));
        col += (hash(p + fract(t) * 97.0) - 0.5) * 0.035;
        return float4(col, 1.0);
    }
    """
}

/// One point on the radar: a used item glows bright, an unused one stays dim.
struct Blip: Equatable {
    var angle: Float
    var radius: Float
    var intensity: Float

    /// Places an item at a stable spot derived from its name, so the radar
    /// looks the same on every launch.
    init(name: String, used: Bool) {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in name.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        angle = Float(hash % 3600) / 3600 * 2 * .pi
        radius = 0.22 + Float((hash >> 20) % 1000) / 1000 * 0.68
        intensity = used ? 1 : 0.22
    }
}

enum ShaderKind: Equatable {
    case radar(blips: [Blip])

    var function: String {
        switch self {
        case .radar: "radar"
        }
    }
}

@MainActor
final class ShaderRenderer {
    static let shared = ShaderRenderer()

    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private var pipelines: [String: MTLRenderPipelineState] = [:]
    private var targets: [String: MTLTexture] = [:]

    private init?() {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(),
              let library = try? device.makeLibrary(source: ShaderSource.msl, options: nil),
              let vertex = library.makeFunction(name: "fullscreen") else { return nil }
        self.device = device
        self.queue = queue
        for name in ["radar"] {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = library.makeFunction(name: name)
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelines[name] = try? device.makeRenderPipelineState(descriptor: descriptor)
        }
    }

    /// Renders one frame into a CGImage of `width` x `height` pixels.
    func image(function: String, width: Int, height: Int, uniforms: [SIMD4<Float>]) -> CGImage? {
        guard width > 0, height > 0, let pipeline = pipelines[function] else { return nil }
        let key = "\(function)-\(width)x\(height)"
        let texture: MTLTexture
        if let cached = targets[key] {
            texture = cached
        } else {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            descriptor.usage = .renderTarget
            descriptor.storageMode = .managed
            guard let made = device.makeTexture(descriptor: descriptor) else { return nil }
            targets[key] = made
            texture = made
        }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let buffer = queue.makeCommandBuffer(), let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return nil }
        encoder.setRenderPipelineState(pipeline)
        var data = uniforms
        encoder.setFragmentBytes(&data, length: MemoryLayout<SIMD4<Float>>.stride * data.count, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        if let blit = buffer.makeBlitCommandEncoder() {
            blit.synchronize(resource: texture)
            blit.endEncoding()
        }
        buffer.commit()
        buffer.waitUntilCompleted()

        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        texture.getBytes(&pixels, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}

/// A live shader backdrop. Animates at 30 fps, and holds a still frame when
/// the user has Reduce Motion on.
struct ShaderView: View {
    var kind: ShaderKind
    /// Radar only: scope center as a fraction of the view, and radius in points.
    var scopeCenter = UnitPoint.center
    var scopeRadius: CGFloat = 60
    /// A fixed time in seconds, for rendering exact frames offscreen. nil animates live.
    var time: Double?

    @Environment(\.displayScale) private var scale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                let now = time ?? (reduceMotion ? 1.4 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600))
                if let image = frame(size: geo.size, time: now) {
                    Image(decorative: image, scale: scale).resizable()
                } else {
                    Color(nsColor: NSColor(hex: 0x0D1514))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func frame(size: CGSize, time: Double) -> CGImage? {
        let width = Int(size.width * scale), height = Int(size.height * scale)
        var uniforms: [SIMD4<Float>] = [
            SIMD4(Float(width), Float(height), Float(time), Float(scale)),
            SIMD4(Float(scopeCenter.x * size.width * scale), Float(scopeCenter.y * size.height * scale),
                  Float(scopeRadius * scale), 0),
        ]
        var blips: [Blip] = []
        if case .radar(let list) = kind { blips = Array(list.prefix(16)) }
        uniforms.append(SIMD4(Float(blips.count), 0, 0, 0))
        uniforms += blips.map { SIMD4($0.angle, $0.radius, $0.intensity, 0) }
        uniforms += Array(repeating: SIMD4<Float>(), count: 16 - blips.count)
        return ShaderRenderer.shared?.image(function: kind.function, width: width, height: height, uniforms: uniforms)
    }
}
