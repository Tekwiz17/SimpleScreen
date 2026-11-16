import Foundation
import SwiftUI

enum WallpaperStyle: String, Codable, CaseIterable, Identifiable {
    case aurora = "Aurora", gradient = "Gradient", dunes = "Dunes", orbit = "Orbit", contour = "Contour", image = "Image or GIF"
    var id: String { rawValue }
}
enum WidgetKind: String, Codable, CaseIterable, Identifiable {
    case clock = "Clock", weather = "Weather", battery = "Battery", calendar = "Calendar", focus = "Focus", note = "Note", usage = "AI Usage", html = "HTML"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .clock: return "clock"
        case .weather: return "cloud.sun"
        case .battery: return "battery.100percent"
        case .calendar: return "calendar"
        case .focus: return "timer"
        case .note: return "note.text"
        case .usage: return "chart.bar.xaxis"
        case .html: return "curlybraces"
        }
    }
}
enum WidgetSurface: String, Codable, CaseIterable { case glass = "Glass", solid = "Color", clear = "None" }
enum Presence: String, Codable, CaseIterable { case both = "Dock & menu bar", dock = "Dock only", menu = "Menu bar only", neither = "Neither" }
struct Palette: Identifiable {
    let name: String
    let colors: [String]
    var id: String { name }
    static let all: [Palette] = [
        .init(name: "Tidal", colors: ["102B46", "2F8D9C", "A8DDD0"]),
        .init(name: "Daybreak", colors: ["572D5E", "D37B8D", "F4CDA5"]),
        .init(name: "Moss", colors: ["162E2A", "56816B", "CCD8AE"]),
        .init(name: "Porcelain", colors: ["C5CCD8", "EBE3DA", "FFFFFF"]),
        .init(name: "Ember", colors: ["301E26", "A84933", "F5B66D"]),
        .init(name: "Midnight", colors: ["080F23", "1A3866", "789EC8"]),
        .init(name: "Lilac", colors: ["292445", "827DB5", "E1C8DE"]),
        .init(name: "Ink", colors: ["101214", "414B52", "ACB5BC"])
    ]
}
struct Wallpaper: Codable, Equatable {
    var style: WallpaperStyle = .aurora
    var colors = Palette.all[0].colors
    var animated = true
    var speed: Double = 0.35
    var angle: Double = 35
    var mediaPath: String?
    var fill = true
}
struct DesktopWidget: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: WidgetKind
    var screenID: String = ""
    var x: Double = 40
    var y: Double = 80
    var width: Double = 240
    var height: Double = 160
    var surface: WidgetSurface = .glass
    var foreground = "FFFFFF"
    var background = "20394A"
    var opacity: Double = 0.7
    var fontName = "System"
    var fontSize: Double = 28
    var interaction = true
    var title = ""
    var text = "Make room for a little quiet."
    var html = """
    <style>body{margin:0;display:grid;place-items:center;height:100vh;color:white;font:24px system-ui}
    button{color:inherit;background:none;border:0;font:inherit;cursor:pointer}</style>
    <button onclick="this.textContent=this.textContent==='Hello, desktop.'?'Make something lovely.':'Hello, desktop.'">Hello, desktop.</button>
    """
    var focusMinutes = 25
    var focusEnd: Date?
    var provider = "Codex"
    var networkAllowed = false
    var showSeconds = false
}
struct Preferences: Codable {
    var version = 1
    var wallpaper = Wallpaper()
    var widgets: [DesktopWidget] = []
    var presence: Presence = .both
    var enabled = true
    var snap = true
    var grid: Double = 20
    var pauseOnBattery = true
    var weatherEnabled = false
    var latitude: Double = 40.71
    var longitude: Double = -74.01
    var city = "New York"
    var fahrenheit = true
    var codexEnabled = false
    var claudePath = ""
    var onboardingComplete = false
}
enum Layout {
    static func position(_ value: Double, extent: Double, size: Double, snap: Bool, grid: Double) -> Double {
        let finite = value.isFinite ? value : 0
        let step = max(1, grid.isFinite ? grid : 20)
        let proposed = snap ? (finite / step).rounded() * step : finite
        return min(max(0, proposed), max(0, extent - size))
    }
}
extension Color {
    init(hex: String) {
        let n = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0
        self.init(.sRGB, red: Double((n >> 16) & 255) / 255, green: Double((n >> 8) & 255) / 255, blue: Double(n & 255) / 255, opacity: 1)
    }
    var hex: String {
        let c = NSColor(self).usingColorSpace(.sRGB) ?? .white
        return String(format: "%02X%02X%02X", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }
}
struct UsageWindow: Equatable {
    let label: String
    let used: Double
    let reset: Date?
    var remaining: Double { max(0, min(100, 100 - used)) }
}
struct UsageSnapshot {
    var windows: [UsageWindow] = []
    var captured: Date?
    var message = "Connect in Settings"
    var stale: Bool { captured.map { Date().timeIntervalSince($0) > 900 } ?? true }
}
enum UsageParser {
    static func parse(_ data: Data, provider: String, captured: Date) -> UsageSnapshot? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let payload = root["payload"] as? [String: Any] ?? root
        guard let limits = payload["rate_limits"] as? [String: Any] else { return nil }
        var windows: [UsageWindow] = []
        for key in provider == "Claude Code" ? ["five_hour", "seven_day"] : ["primary", "secondary"] {
            guard let w = limits[key] as? [String: Any],
                  let used = (w["used_percent"] ?? w["used_percentage"]) as? Double,
                  used.isFinite, (0...100).contains(used) else { continue }
            let minutes = w["window_minutes"] as? Int
            let label = key == "five_hour" ? "5 hours" : key == "seven_day" ? "7 days" : minutes.map { $0 >= 1440 ? "\($0 / 1440) days" : "\($0 / 60) hours" } ?? key.capitalized
            let reset = (w["resets_at"] as? Double).map { Date(timeIntervalSince1970: $0) }
            windows.append(.init(label: label, used: used, reset: reset))
        }
        guard !windows.isEmpty else { return nil }
        var date = captured
        if let stamp = root["timestamp"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            date = formatter.date(from: stamp) ?? ISO8601DateFormatter().date(from: stamp) ?? captured
        }
        return UsageSnapshot(windows: windows, captured: date, message: "Local snapshot")
    }
}
