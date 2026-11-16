import SwiftUI
import AppKit
import ImageIO

struct WallpaperView: View {
    let wallpaper: Wallpaper
    var animate = true
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: !animate || !wallpaper.animated || wallpaper.style == .image)) { context in
            let t = animate && wallpaper.animated ? context.date.timeIntervalSinceReferenceDate * wallpaper.speed * 0.18 : 0
            ZStack {
                if wallpaper.style == .image, let path = wallpaper.mediaPath {
                    MediaView(path: path, fill: wallpaper.fill, animate: animate && wallpaper.animated)
                } else {
                    WallpaperCanvas(wallpaper: wallpaper, time: t)
                }
            }
        }
        .clipped()
        .accessibilityLabel("Wallpaper: \(wallpaper.style.rawValue)")
    }
}
struct WallpaperCanvas: View {
    let wallpaper: Wallpaper
    let time: Double
    var colors: [Color] { wallpaper.colors.isEmpty ? [.black, .blue, .white] : wallpaper.colors.map { Color(hex: $0) } }
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let angle = wallpaper.angle * .pi / 180
            let start = CGPoint(x: size.width * (0.5 - cos(angle) * 0.5), y: size.height * (0.5 - sin(angle) * 0.5))
            let end = CGPoint(x: size.width - start.x, y: size.height - start.y)
            context.fill(Path(rect), with: .linearGradient(Gradient(colors: colors), startPoint: start, endPoint: end))
            switch wallpaper.style {
            case .aurora:
                context.addFilter(.blur(radius: size.width * 0.065))
                for index in 0..<5 {
                    let phase = Double(index) * 1.9 + time
                    let center = CGPoint(x: size.width * (0.5 + sin(phase * 0.7) * 0.4), y: size.height * (0.5 + cos(phase * 0.6) * 0.4))
                    let radius = size.width * 0.55
                    let blob = CGRect(x: center.x - radius / 2, y: center.y - radius / 2, width: radius, height: radius * 0.7)
                    context.fill(Path(ellipseIn: blob), with: .radialGradient(Gradient(colors: [colors[index % colors.count].opacity(0.85), .clear]), center: center, startRadius: 0, endRadius: radius / 2))
                }
            case .dunes:
                for index in 0..<6 {
                    var path = Path()
                    let y = size.height * (0.28 + Double(index) * 0.13)
                    path.move(to: CGPoint(x: -10, y: y))
                    path.addCurve(to: CGPoint(x: size.width + 10, y: y + size.height * 0.12),
                                  control1: CGPoint(x: size.width * 0.3, y: y - size.height * (0.28 + sin(time + Double(index)) * 0.06)),
                                  control2: CGPoint(x: size.width * 0.65, y: y + size.height * 0.3))
                    path.addLine(to: CGPoint(x: size.width + 10, y: size.height + 10))
                    path.addLine(to: CGPoint(x: -10, y: size.height + 10))
                    path.closeSubpath()
                    context.fill(path, with: .linearGradient(Gradient(colors: [colors[index % colors.count].opacity(0.6), colors[(index + 1) % colors.count]]), startPoint: CGPoint(x: 0, y: y), endPoint: CGPoint(x: size.width, y: size.height)))
                    context.stroke(path, with: .color(.white.opacity(0.12)), lineWidth: 1)
                }
            case .orbit:
                for index in 0..<7 {
                    let radius = size.height * (0.12 + Double(index) * 0.085)
                    let center = CGPoint(x: size.width * (0.55 + sin(time) * 0.08), y: size.height * 0.47)
                    let ellipse = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                    context.stroke(Path(ellipseIn: ellipse), with: .linearGradient(Gradient(colors: [.white.opacity(0.5), .clear, colors[index % colors.count]]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)), lineWidth: max(1, size.height * 0.012))
                }
            case .contour:
                for index in 0..<36 {
                    var path = Path()
                    for step in 0...80 {
                        let x = Double(step) / 80 * size.width
                        let y = Double(index) / 30 * size.height + sin(x / size.width * 7 + time + Double(index) * 0.09) * size.height * 0.12
                        if step == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    context.stroke(path, with: .color(.white.opacity(0.2)), lineWidth: 1)
                }
            default: break
            }
        }
    }
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
