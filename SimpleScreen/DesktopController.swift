import AppKit
import SwiftUI
import Combine

final class DesktopPanel: NSPanel {
    var dragging = false
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
            effects.forEach { $0.close() }; effects.removeAll()
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
                window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
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
                panel.contentView = NSHostingView(rootView: DesktopWidgetView(store: store, services: store.services, id: widget.id, effect: { [weak self] kind in
                    guard let self, let activeScreen = self.widgets[widget.id]?.screen else { return }
                    self.showEffect(kind, on: activeScreen)
                }))
            }
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            panel.ignoresMouseEvents = !store.editing && !widget.interaction
            if !panel.dragging && panel.frame != frame { panel.setFrame(frame, display: true) }
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
        window.level = .init(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 2)
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
            guard let panel = window as? DesktopPanel else { return }
            panel.dragging = true
            panel.performDrag(with: event)
            panel.dragging = false
            NotificationCenter.default.post(name: NSWindow.didMoveNotification, object: panel)
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
            Canvas { context, size in
                draw(context: &context, size: size, elapsed: timeline.date.timeIntervalSince(start))
            }
        }.allowsHitTesting(false)
    }
    private func draw(context: inout GraphicsContext, size: CGSize, elapsed: Double) {
        let fadeIn = min(1.0, elapsed / 0.7)
        let fadeOut = max(0.0, min(1.0, (8 - elapsed) / 1.5))
        context.opacity = fadeIn * fadeOut
        if kind == "sun" { sun(context: &context, size: size, time: elapsed) }
        else { particles(context: &context, size: size, time: elapsed, snow: kind == "snow") }
    }
    private func sun(context: inout GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width * 0.78, y: size.height * 0.12)
        let gradient = Gradient(colors: [Color.white.opacity(0.9), Color.yellow.opacity(0.18), Color.clear])
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: size.width * 0.7))
        for index in 0..<9 {
            let angle = Double(index) * 0.21 + 0.8 + sin(time * 0.2) * 0.05
            let first = CGPoint(x: center.x + CGFloat(cos(angle)) * size.width, y: center.y + CGFloat(sin(angle)) * size.width)
            let second = CGPoint(x: center.x + CGFloat(cos(angle + 0.06)) * size.width, y: center.y + CGFloat(sin(angle + 0.06)) * size.width)
            var ray = Path()
            ray.move(to: center); ray.addLine(to: first); ray.addLine(to: second); ray.closeSubpath()
            context.fill(ray, with: .color(Color.white.opacity(0.035)))
        }
    }
    private func particles(context: inout GraphicsContext, size: CGSize, time: Double, snow: Bool) {
        let width = Double(size.width), height = Double(size.height)
        let count = snow ? 180 : 280
        for index in 0..<count {
            let seed = Double(index)
            let depth = 0.3 + fraction(sin(seed * 12.9898) * 43758.5453) * 0.7
            let x0 = fraction(sin(seed * 78.233) * 19341.123) * width
            let speed = (snow ? 45.0 : 700.0) * depth
            let startY = fraction(seed * 0.618) * (height + 100)
            let y = (startY + time * speed).truncatingRemainder(dividingBy: height + 100) - 50
            let drift = snow ? sin(time * 0.8 + seed) * 35 : -y * 0.08
            let x = x0 + drift
            if snow { flake(context: &context, x: x, y: y, depth: depth) }
            else { rain(context: &context, x: x, y: y, x0: x0, height: height, depth: depth, seed: seed, time: time) }
        }
    }
    private func flake(context: inout GraphicsContext, x: Double, y: Double, depth: Double) {
        let radius = 1 + depth * 3.5
        let rect = CGRect(x: x, y: y, width: radius * 2, height: radius * 2)
        let gradient = Gradient(colors: [Color.white.opacity(depth), Color.white.opacity(0.1)])
        context.fill(Path(ellipseIn: rect), with: .radialGradient(gradient, center: CGPoint(x: x + radius, y: y + radius), startRadius: 0, endRadius: radius))
    }
    private func rain(context: inout GraphicsContext, x: Double, y: Double, x0: Double, height: Double, depth: Double, seed: Double, time: Double) {
        var line = Path()
        line.move(to: CGPoint(x: x, y: y))
        line.addLine(to: CGPoint(x: x - 2, y: y + 18 * depth))
        context.stroke(line, with: .color(Color.white.opacity(0.18 + depth * 0.3)), lineWidth: depth)
        let rippleY = height * (0.87 + fraction(seed * 0.391) * 0.13)
        let ripple = fraction(time * 1.5 + seed * 0.17)
        let rect = CGRect(x: x0, y: rippleY, width: ripple * 20, height: ripple * 5)
        context.stroke(Path(ellipseIn: rect), with: .color(Color.white.opacity((1 - ripple) * 0.15)), lineWidth: 0.6)
    }
    private func fraction(_ n: Double) -> Double { n - floor(n) }
}
