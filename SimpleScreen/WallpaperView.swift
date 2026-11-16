import SwiftUI
import AppKit
import ImageIO

struct WallpaperView: View {
    let wallpaper: Wallpaper
    var animate = true
    var body: some View {
        Group {
            if wallpaper.style == .image, let path = wallpaper.mediaPath {
                MediaView(path: path, fill: wallpaper.fill, animate: animate && wallpaper.animated)
            } else {
                NativeWallpaper(wallpaper: wallpaper, animate: animate && wallpaper.animated)
            }
        }.clipped().accessibilityLabel("Wallpaper: \(wallpaper.style.rawValue)")
    }
}
struct NativeWallpaper: NSViewRepresentable {
    let wallpaper: Wallpaper
    let animate: Bool
    func makeNSView(context: Context) -> WallpaperNSView { WallpaperNSView() }
    func updateNSView(_ view: WallpaperNSView, context: Context) { view.configure(wallpaper, animate: animate) }
}
final class WallpaperNSView: NSView {
    private var wallpaper = Wallpaper()
    private var running = false
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private(set) var phase: Double = 0
    private(set) var renderedFrames = 0
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { true }
    func configure(_ wallpaper: Wallpaper, animate: Bool) {
        self.wallpaper = wallpaper
        let changed = running != animate
        running = animate
        if changed || timer == nil { updateTimer() }
        needsDisplay = true
    }
    private func updateTimer() {
        timer?.invalidate(); timer = nil
        lastTick = ProcessInfo.processInfo.systemUptime
        guard running, window != nil else { return }
        let next = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = ProcessInfo.processInfo.systemUptime
            let delta = min(0.15, max(0, now - self.lastTick))
            self.lastTick = now
            self.phase += delta * (0.25 + self.wallpaper.speed * 1.8)
            self.needsDisplay = true
            // Desktop windows can be considered occluded by Finder's icon window.
            // An explicit native display pass does not depend on SwiftUI's animation cadence.
            self.displayIfNeeded()
        }
        next.tolerance = 0.004
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); updateTimer() }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        WallpaperPainter.draw(context, size: bounds.size, wallpaper: wallpaper, time: phase)
        renderedFrames += 1
    }
    deinit { timer?.invalidate() }
}
struct WallpaperCanvas: View {
    let wallpaper: Wallpaper
    let time: Double
    var body: some View {
        Canvas { context, size in
            context.withCGContext { cg in WallpaperPainter.draw(cg, size: size, wallpaper: wallpaper, time: time) }
        }
    }
}
enum WallpaperPainter {
    static func draw(_ cg: CGContext, size: CGSize, wallpaper: Wallpaper, time: Double) {
        guard size.width > 0, size.height > 0 else { return }
        let colors = (wallpaper.colors.isEmpty ? ["102B46", "2F8D9C", "A8DDD0"] : wallpaper.colors).map { NSColor(Color(hex: $0)).cgColor }
        let w = size.width, h = size.height
        let rect = CGRect(origin: .zero, size: size)
        cg.saveGState(); defer { cg.restoreGState() }
        cg.clip(to: rect)
        let animatedAngle = wallpaper.angle + sin(time * 0.6) * 28
        let angle = animatedAngle * .pi / 180
        let start = CGPoint(x: w * CGFloat(0.5 - cos(angle) * 0.7), y: h * CGFloat(0.5 - sin(angle) * 0.7))
        let end = CGPoint(x: w - start.x, y: h - start.y)
        linear(cg, colors: colors, from: start, to: end)
        switch wallpaper.style {
        case .aurora:
            for i in 0..<6 {
                let phase = Double(i) * 1.7 + time * 0.65
                let center = CGPoint(x: w * CGFloat(0.5 + sin(phase) * 0.45), y: h * CGFloat(0.5 + cos(phase * 0.8) * 0.45))
                radial(cg, color: colors[i % colors.count], center: center, radius: max(w, h) * 0.55, alpha: 0.85)
            }
        case .dunes: dunes(cg, size: size, colors: colors, time: time)
        case .orbit:
            let center = CGPoint(x: w * CGFloat(0.5 + sin(time * 0.6) * 0.13), y: h * CGFloat(0.5 + cos(time * 0.4) * 0.06))
            for i in 0..<8 {
                let radius = h * CGFloat(0.09 + Double(i) * 0.078)
                cg.setStrokeColor(NSColor.white.withAlphaComponent(0.12 + Double(i) * 0.035).cgColor)
                cg.setLineWidth(max(1, h * 0.009))
                cg.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            }
        case .contour, .ribbons: lines(cg, size: size, colors: colors, time: time, ribbons: wallpaper.style == .ribbons)
        case .ripple:
            let center = CGPoint(x: w * CGFloat(0.5 + sin(time * 0.25) * 0.15), y: h * 0.5)
            for i in 0..<12 {
                let progress = (Double(i) / 12 + time * 0.07).truncatingRemainder(dividingBy: 1)
                let radius = max(w, h) * progress
                cg.setStrokeColor(NSColor.white.withAlphaComponent((1 - progress) * 0.28).cgColor)
                cg.setLineWidth(1 + 5 * (1 - progress))
                cg.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius * 0.65, width: radius * 2, height: radius * 1.3))
            }
        case .stars:
            for i in 0..<180 {
                let seed = Double(i)
                let x = fraction(seed * 0.6180339 + time * 0.003) * Double(w)
                let y = fraction(seed * 0.4142135) * Double(h)
                let depth = fraction(seed * 0.271828)
                let alpha = 0.25 + (sin(time * 1.2 + seed) + 1) * 0.3
                let radius = 0.6 + depth * 1.5
                cg.setFillColor(NSColor.white.withAlphaComponent(alpha).cgColor)
                cg.fillEllipse(in: CGRect(x: x, y: y, width: radius * 2, height: radius * 2))
            }
        default: break
        }
    }
    private static func dunes(_ cg: CGContext, size: CGSize, colors: [CGColor], time: Double) {
        let w = size.width, h = size.height
        for i in 0..<6 {
            let y = h * CGFloat(0.25 + Double(i) * 0.13)
            let lift = h * CGFloat(0.25 + sin(time * 0.8 + Double(i)) * 0.12)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -10, y: y))
            path.addCurve(to: CGPoint(x: w + 10, y: y + h * 0.12), control1: CGPoint(x: w * 0.3, y: y - lift), control2: CGPoint(x: w * 0.65, y: y + h * 0.3))
            path.addLine(to: CGPoint(x: w + 10, y: h + 10)); path.addLine(to: CGPoint(x: -10, y: h + 10)); path.closeSubpath()
            cg.saveGState(); cg.addPath(path); cg.clip()
            linear(cg, colors: [colors[i % colors.count], colors[(i + 1) % colors.count]], from: CGPoint(x: 0, y: y), to: CGPoint(x: w, y: h))
            cg.restoreGState()
            cg.addPath(path); cg.setStrokeColor(NSColor.white.withAlphaComponent(0.15).cgColor); cg.setLineWidth(1); cg.strokePath()
        }
    }
    private static func lines(_ cg: CGContext, size: CGSize, colors: [CGColor], time: Double, ribbons: Bool) {
        let count = ribbons ? 9 : 36
        for i in 0..<count {
            let path = CGMutablePath()
            for step in 0...100 {
                let progress = Double(step) / 100
                let wave = sin(progress * 7 + time + Double(i) * 0.12)
                let y = CGFloat(Double(i) / Double(count - 2) + wave * 0.14) * size.height
                let point = CGPoint(x: CGFloat(progress) * size.width, y: y)
                if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            cg.addPath(path)
            cg.setLineWidth(ribbons ? size.height * 0.045 : 1)
            cg.setStrokeColor(ribbons ? colors[i % colors.count].copy(alpha: 0.5)! : NSColor.white.withAlphaComponent(0.23).cgColor)
            cg.strokePath()
        }
    }
    private static func linear(_ cg: CGContext, colors: [CGColor], from: CGPoint, to: CGPoint) {
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil) else { return }
        cg.drawLinearGradient(gradient, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }
    private static func radial(_ cg: CGContext, color: CGColor, center: CGPoint, radius: CGFloat, alpha: Double) {
        guard let first = color.copy(alpha: alpha), let clear = color.copy(alpha: 0),
              let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [first, clear] as CFArray, locations: [0, 1]) else { return }
        cg.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }
    private static func fraction(_ value: Double) -> Double { value - floor(value) }
}
struct MediaView: NSViewRepresentable {
    let path: String
    let fill: Bool
    let animate: Bool
    func makeNSView(context: Context) -> AnimatedImageView { AnimatedImageView() }
    func updateNSView(_ view: AnimatedImageView, context: Context) { view.configure(path: path, fill: fill, animate: animate) }
}
final class AnimatedImageView: NSView {
    private var source: CGImageSource?
    private var frameImage: CGImage?
    private var frameIndex = 0
    private var count = 0
    private var timer: Timer?
    private var currentPath = ""
    private var fill = true
    private var animate = false
    override var isFlipped: Bool { true }
    func configure(path: String, fill: Bool, animate: Bool) {
        let changed = path != currentPath
        self.fill = fill
        if changed {
            timer?.invalidate(); timer = nil
            currentPath = path
            source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)
            count = source.map { CGImageSourceGetCount($0) } ?? 0
            frameIndex = 0
            decode()
        }
        if changed || self.animate != animate {
            self.animate = animate
            timer?.invalidate(); timer = nil
            if animate && count > 1 { schedule() }
        }
        needsDisplay = true
    }
    private func decode() {
        guard let source else { frameImage = nil; return }
        frameImage = CGImageSourceCreateImageAtIndex(source, frameIndex, [kCGImageSourceShouldCache: true] as CFDictionary)
        needsDisplay = true
    }
    private func schedule() {
        guard let source, animate, count > 1 else { return }
        let props = CGImageSourceCopyPropertiesAtIndex(source, frameIndex, nil) as? [CFString: Any]
        let gif = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] ?? gif?[kCGImagePropertyGIFDelayTime]) as? Double ?? 0.1
        timer = Timer.scheduledTimer(withTimeInterval: max(0.02, delay), repeats: false) { [weak self] _ in
            guard let self else { return }
            self.frameIndex = (self.frameIndex + 1) % self.count
            self.decode()
            self.schedule()
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); bounds.fill()
        guard let frameImage else { return }
        let image = NSImage(cgImage: frameImage, size: .zero)
        let scale = fill ? max(bounds.width / image.size.width, bounds.height / image.size.height) : min(bounds.width / image.size.width, bounds.height / image.size.height)
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: NSRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
    }
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { timer?.invalidate(); timer = nil; animate = false }
        super.viewWillMove(toWindow: newWindow)
    }
    deinit { timer?.invalidate() }
}
