import AppKit
import SwiftUI

@main struct NativeMotion {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: NSRect(x: 20, y: 20, width: 480, height: 270), styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.level = .init(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        let view = WallpaperNSView(frame: NSRect(x: 0, y: 0, width: 480, height: 270))
        window.contentView = view
        window.orderFrontRegardless()
        var count = 0
        for style in WallpaperStyle.allCases where style != .image {
            let wallpaper = Wallpaper(style: style)
            view.configure(wallpaper, animate: true)
            let before = pixels(view)
            let phase = view.phase
            let draws = view.renderedFrames
            RunLoop.main.run(until: Date().addingTimeInterval(0.8))
            guard view.phase > phase, view.renderedFrames > draws else { fatalError("Native redraw timer stalled for \(style)") }
            guard before != pixels(view) else { fatalError("Native desktop frame did not change for \(style)") }
            view.configure(wallpaper, animate: false)
            let paused = view.phase
            let still = pixels(view)
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
            guard view.phase == paused, pixels(view) == still else { fatalError("Pause failed for \(style)") }
            count += 1
        }
        let phase = view.phase
        view.configure(Wallpaper(), animate: true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        guard view.phase > phase else { fatalError("Resume failed") }
        window.close()
        print("\(count) native desktop animation/pause checks and resume passed.")
    }
    @MainActor static func pixels(_ view: NSView) -> Data {
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fatalError("Bitmap unavailable") }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("PNG unavailable") }
        return data
    }
}
