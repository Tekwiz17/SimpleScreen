import AppKit
import SwiftUI
import Combine

final class DesktopPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
@MainActor final class DesktopController: NSObject, NSWindowDelegate {
    let store: Store
    private var wallpapers: [String: NSWindow] = [:]
    private var widgets: [UUID: DesktopPanel] = [:]
    private var effects: [NSWindow] = []
    private var updating = false
    private var cancellables = Set<AnyCancellable>()
    init(store: Store) {
        self.store = store
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        store.$editing.dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { self?.sync() }
        }.store(in: &cancellables)
    }
    @objc private func screensChanged() { sync() }
    func sync() {
        guard !updating else { return }
        updating = true; defer { updating = false }
        guard store.preferences.enabled else {
            wallpapers.values.forEach { $0.orderOut(nil) }
            widgets.values.forEach { $0.orderOut(nil) }
            return
        }
        let screens = NSScreen.screens
        guard let first = screens.first else { return }
        let ids = Set(screens.map(screenID))
        for key in Array(wallpapers.keys) where !ids.contains(key) { wallpapers.removeValue(forKey: key)?.close() }
        for screen in screens {
            let id = screenID(screen)
            let window: NSWindow
            if let existing = wallpapers[id] { window = existing }
            else {
                window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.level = NSWindow.Level(rawValue: CGWindowLevelForKey(.desktopWindow) + 1)
                window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
                window.ignoresMouseEvents = true
                window.hasShadow = false
                wallpapers[id] = window
                window.contentView = NSHostingView(rootView: DesktopWallpaper(store: store))
            }
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
        }
        let active = Set(store.preferences.widgets.map(\.id))
        for id in Array(widgets.keys) where !active.contains(id) { widgets.removeValue(forKey: id)?.close() }
        for widget in store.preferences.widgets {
            let screen = screens.first(where: { screenID($0) == widget.screenID }) ?? first
            let area = screen.visibleFrame
            let width = min(widget.width, area.width), height = min(widget.height, area.height)
            let x = Layout.position(widget.x, extent: area.width, size: width, snap: false, grid: 20)
            let y = Layout.position(widget.y, extent: area.height, size: height, snap: false, grid: 20)
            let frame = NSRect(x: area.minX + x, y: area.maxY - y - height, width: width, height: height)
            let panel: DesktopPanel
            if let existing = widgets[widget.id] { panel = existing }
            else {
                panel = DesktopPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                panel.isReleasedWhenClosed = false
                panel.isFloatingPanel = false
                panel.hidesOnDeactivate = false
                panel.backgroundColor = .clear
                panel.isOpaque = false
                panel.hasShadow = false
                panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
                panel.delegate = self
                widgets[widget.id] = panel
                panel.contentView = NSHostingView(rootView: DesktopWidgetView(store: store, services: store.services, id: widget.id, effect: { [weak self] kind in self?.showEffect(kind, on: screen) }))
            }
            panel.level = NSWindow.Level(rawValue: CGWindowLevelForKey(.desktopIconWindow) + 1)
            panel.ignoresMouseEvents = !store.editing && !widget.interaction
            if panel.frame != frame { panel.setFrame(frame, display: true) }
            panel.orderFrontRegardless()
        }
    }
    func windowDidMove(_ notification: Notification) {
        guard !updating, let window = notification.object as? NSWindow,
              let item = widgets.first(where: { $0.value === window }),
              let screen = window.screen else { return }
        let area = screen.visibleFrame
        store.update(item.key) {
            $0.screenID = screenID(screen)
            $0.x = Layout.position(window.frame.minX - area.minX, extent: area.width, size: window.frame.width, snap: store.preferences.snap, grid: store.preferences.grid)
            $0.y = Layout.position(area.maxY - window.frame.maxY, extent: area.height, size: window.frame.height, snap: store.preferences.snap, grid: store.preferences.grid)
        }
    }
    func showEffect(_ kind: String, on screen: NSScreen) {
        guard store.animate else { return }
        effects.forEach { $0.close() }; effects.removeAll()
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear; window.isOpaque = false; window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .init(rawValue: CGWindowLevelForKey(.desktopIconWindow) + 2)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.contentView = NSHostingView(rootView: WeatherEffect(kind: kind))
        effects.append(window); window.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self, weak window] in
            window?.close()
            self?.effects.removeAll { $0 === window }
        }
    }
}
struct DesktopWallpaper: View {
    @ObservedObject var store: Store
    @ObservedObject private var services: Services
    init(store: Store) { self.store = store; self.services = store.services }
    var body: some View { WallpaperView(wallpaper: store.preferences.wallpaper, animate: store.animate) }
}
struct DragHandle: NSViewRepresentable {
    var enabled: Bool
    func makeNSView(context: Context) -> HandleView { HandleView() }
    func updateNSView(_ nsView: HandleView, context: Context) { nsView.enabled = enabled }
    final class HandleView: NSView {
        var enabled = true
        override func mouseDown(with event: NSEvent) {
            guard enabled else { return }
            window?.performDrag(with: event)
        }
        override func resetCursorRects() {
            if enabled { addCursorRect(bounds, cursor: .openHand) }
        }
    }
}
struct WeatherEffect: View {
    let kind: String
    @State private var start = Date()
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                let fade = min(1, t / 0.7) * max(0, min(1, (8 - t) / 1.5))
                context.opacity = fade
                if kind == "sun" {
                    let center = CGPoint(x: size.width * 0.78, y: size.height * 0.12)
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(Gradient(colors: [.white.opacity(0.9), .yellow.opacity(0.18), .clear]), center: center, startRadius: 0, endRadius: size.width * 0.7))
                    for i in 0..<9 {
                        var ray = Path()
                        let a = Double(i) * 0.21 + 0.8 + sin(t * 0.2) * 0.05
                        ray.move(to: center)
                        ray.addLine(to: CGPoint(x: center.x + cos(a) * size.width, y: center.y + sin(a) * size.width))
                        ray.addLine(to: CGPoint(x: center.x + cos(a + 0.06) * size.width, y: center.y + sin(a + 0.06) * size.width))
                        ray.closeSubpath()
                        context.fill(ray, with: .color(.white.opacity(0.035)))
                    }
                } else {
                    let snow = kind == "snow"
                    for i in 0..<(snow ? 180 : 280) {
                        let seed = Double(i)
                        let depth = 0.3 + fraction(sin(seed * 12.9898) * 43758.5453) * 0.7
                        let x0 = fraction(sin(seed * 78.233) * 19341.123) * size.width
                        let speed = (snow ? 45.0 : 700.0) * depth
                        let y = (fraction(seed * 0.618) * (size.height + 100) + t * speed).truncatingRemainder(dividingBy: size.height + 100) - 50
                        let x = x0 + (snow ? sin(t * 0.8 + seed) * 35 : -y * 0.08)
                        if snow {
                            let radius = 1 + depth * 3.5
                            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)), with: .radialGradient(Gradient(colors: [.white.opacity(depth), .white.opacity(0.1)]), center: CGPoint(x: x + radius, y: y + radius), startRadius: 0, endRadius: radius))
                        } else {
                            var line = Path()
                            line.move(to: CGPoint(x: x, y: y))
                            line.addLine(to: CGPoint(x: x - 2, y: y + 18 * depth))
                            context.stroke(line, with: .color(.white.opacity(0.18 + depth * 0.3)), lineWidth: depth)
                            let rippleY = size.height * (0.87 + fraction(seed * 0.391) * 0.13)
                            let ripple = fraction(t * 1.5 + seed * 0.17)
                            context.stroke(Path(ellipseIn: CGRect(x: x0, y: rippleY, width: ripple * 20, height: ripple * 5)), with: .color(.white.opacity((1 - ripple) * 0.15)), lineWidth: 0.6)
                        }
                    }
                }
            }
        }.allowsHitTesting(false)
    }
    private func fraction(_ n: Double) -> Double { n - floor(n) }
}
