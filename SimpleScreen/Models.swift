import Foundation
import CoreFoundation
import SwiftUI

enum WallpaperStyle: String, Codable, CaseIterable, Identifiable {
    case aurora = "Aurora", gradient = "Gradient", dunes = "Dunes", orbit = "Orbit", contour = "Contour", ripple = "Ripple", stars = "Starlight", ribbons = "Ribbons", image = "Image or GIF"
    var id: String { rawValue }
}
enum WidgetKind: String, Codable, CaseIterable, Identifiable {
    case clock = "Clock", weather = "Weather", battery = "Battery", calendar = "Calendar", focus = "Focus", note = "Note", usage = "AI Usage", html = "HTML"
    case batteries = "Device Batteries", worldClock = "World Clock", analog = "Analog Clock", countdown = "Countdown", stopwatch = "Stopwatch", checklist = "Checklist", habit = "Habit", water = "Water", breathing = "Breathe", quote = "Daily Thought", dayProgress = "Day Progress", storage = "Storage", memory = "Memory", uptime = "Uptime", links = "Quick Links", calculator = "Calculator", dice = "Dice", color = "Color Studio", weatherDetails = "Weather Details"
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
        case .batteries: return "battery.100percent"
        case .worldClock: return "globe"
        case .analog: return "clock"
        case .countdown: return "calendar.badge.clock"
        case .stopwatch: return "stopwatch"
        case .checklist: return "checklist"
        case .habit: return "checkmark.seal"
        case .water: return "drop.fill"
        case .breathing: return "wind"
        case .quote: return "quote.opening"
        case .dayProgress: return "sun.horizon"
        case .storage: return "externaldrive"
        case .memory: return "memorychip"
        case .uptime: return "power"
        case .links: return "link"
        case .calculator: return "plus.forwardslash.minus"
        case .dice: return "dice"
        case .color: return "eyedropper.halffull"
        case .weatherDetails: return "thermometer.sun"
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
    var options: WidgetOptions?
    var settings: WidgetOptions { options ?? WidgetOptions() }
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
    var pauseInLowPower: Bool?
    var respectReduceMotion: Bool?
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
    private static func number(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite else { return nil }
        return number.doubleValue
    }
    static func parse(_ data: Data, provider: String, captured: Date) -> UsageSnapshot? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let payload = root["payload"] as? [String: Any] ?? root
        guard let limits = payload["rate_limits"] as? [String: Any] else { return nil }
        var windows: [UsageWindow] = []
        for key in provider == "Claude Code" ? ["five_hour", "seven_day"] : ["primary", "secondary"] {
            guard let w = limits[key] as? [String: Any],
                  let used = number(w["used_percent"] ?? w["used_percentage"]),
                  used.isFinite, (0...100).contains(used) else { continue }
            let minutes = w["window_minutes"] as? Int
            let label = key == "five_hour" ? "5 hours" : key == "seven_day" ? "7 days" : minutes.map { $0 >= 1440 ? "\($0 / 1440) days" : "\($0 / 60) hours" } ?? key.capitalized
            let reset = number(w["resets_at"]).map { Date(timeIntervalSince1970: $0) }
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

struct TaskItem: Codable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    var done = false
}
struct ShortcutLink: Codable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    var url: String
}
struct WidgetOptions: Codable, Equatable {
    var timeZone = "Europe/London"
    var targetDate = Date().addingTimeInterval(7 * 86400)
    var elapsed: Double = 0
    var startedAt: Date?
    var goal = 8
    var count = 0
    var dayKey = ""
    var completedDays: [String] = []
    var items: [TaskItem] = [.init(title: "One important thing"), .init(title: "Take a proper break")]
    var links: [ShortcutLink] = [.init(title: "GitHub", url: "https://github.com"), .init(title: "Wikipedia", url: "https://wikipedia.org")]
    var colorHex = "74B9B2"
    var diceCount = 2
    var diceSides = 6
}
enum MotionPolicy {
    static func pauseReason(enabled: Bool, sleeping: Bool, lowPower: Bool, reduceMotion: Bool, onBattery: Bool, pauseOnBattery: Bool, pauseInLowPower: Bool, respectReduceMotion: Bool) -> String? {
        if !enabled { return "Desktop is paused" }
        if sleeping { return "Mac is sleeping" }
        if reduceMotion && respectReduceMotion { return "Reduce Motion is enabled" }
        if lowPower && pauseInLowPower { return "Low Power Mode is enabled" }
        if onBattery && pauseOnBattery { return "Battery animation is disabled" }
        return nil
    }
}
enum WidgetMath {
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
    static func dailyCount(_ options: WidgetOptions, at date: Date) -> Int {
        options.dayKey == dayKey(date) ? options.count : 0
    }
    static func stopwatch(_ options: WidgetOptions, at date: Date) -> Double {
        max(0, options.elapsed + (options.startedAt.map { date.timeIntervalSince($0) } ?? 0))
    }
    static func progress(_ date: Date, component: Calendar.Component, calendar: Calendar = .current) -> Double {
        guard let interval = calendar.dateInterval(of: component, for: date), interval.duration > 0 else { return 0 }
        return min(1, max(0, date.timeIntervalSince(interval.start) / interval.duration))
    }
    static func safeURL(_ input: String) -> URL? {
        guard let url = URL(string: input), let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme), url.host != nil else { return nil }
        return url
    }
}
struct DeviceBattery: Identifiable, Equatable {
    let id: String
    let name: String
    let component: String
    let percent: Int?
    let symbol: String
    var charging: Bool? = nil
}
enum BatteryParser {
    static func percentage(_ value: Any?) -> Int? {
        let number: Double?
        if let string = value as? String { number = Double(string.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespacesAndNewlines)) }
        else if let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() { number = n.doubleValue }
        else { number = nil }
        guard let number, number.isFinite, (0...100).contains(number) else { return nil }
        return Int(number.rounded())
    }
    static func bluetooth(_ data: Data) -> [DeviceBattery]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let controllers = root["SPBluetoothDataType"] as? [[String: Any]] else { return nil }
        var result: [DeviceBattery] = []
        var seen = Set<String>()
        for controller in controllers {
            guard let connected = controller["device_connected"] as? [[String: Any]] else { continue }
            for group in connected {
                for name in group.keys.sorted() {
                    guard let device = group[name] as? [String: Any] else { continue }
                    let address = device["device_address"] as? String ?? name
                    let type = (device["device_minorType"] as? String ?? name).lowercased()
                    let symbol = type.contains("mouse") ? "computermouse" : type.contains("keyboard") ? "keyboard" : type.contains("trackpad") ? "rectangle.and.hand.point.up.left" : type.contains("airpod") || type.contains("head") ? "headphones" : "wave.3.right"
                    let keys = [("device_batteryLevelMain", ""), ("device_batteryLevelLeft", "Left"), ("device_batteryLevelRight", "Right"), ("device_batteryLevelCase", "Case")]
                    var found = false
                    for (key, component) in keys {
                        guard let percent = percentage(device[key]) else { continue }
                        let id = address + ":" + key
                        guard seen.insert(id).inserted else { continue }
                        found = true
                        result.append(.init(id: id, name: name, component: component, percent: percent, symbol: component == "Case" ? "case" : symbol))
                    }
                    if !found && seen.insert(address).inserted {
                        result.append(.init(id: address, name: name, component: "Not reported by macOS", percent: nil, symbol: symbol))
                    }
                }
            }
        }
        return result
    }
}

struct CalculatorState {
    var display = "0"
    private var held: Double?
    private var operation: String?
    private var newNumber = true
    mutating func press(_ key: String) {
        if key == "C" { self = CalculatorState(); return }
        if key == "⌫" { display = String(display.dropLast()); if display.isEmpty || display == "-" { display = "0" }; return }
        if key == "±" { set(-(Double(display) ?? 0)); return }
        if key == "%" { set((Double(display) ?? 0) / 100); return }
        if ["+", "−", "×", "÷", "="].contains(key) {
            let value = Double(display) ?? 0
            if let left = held, let op = operation, !newNumber {
                let result: Double
                switch op { case "+": result = left + value; case "−": result = left - value; case "×": result = left * value; default: result = value == 0 ? .nan : left / value }
                set(result)
            }
            held = key == "=" ? nil : Double(display)
            operation = key == "=" ? nil : key
            newNumber = true
            return
        }
        guard key == "." || Int(key) != nil else { return }
        if newNumber || display == "Error" { display = key == "." ? "0." : key; newNumber = false; return }
        if key == "." && display.contains(".") { return }
        guard display.count < 15 else { return }
        display = display == "0" && key != "." ? key : display + key
    }
    private mutating func set(_ value: Double) { display = value.isFinite ? String(format: "%.10g", value) : "Error" }
}
