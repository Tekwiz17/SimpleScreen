import Foundation
import SwiftUI

var count = 0
func check(_ name: String, _ condition: @autoclosure () -> Bool) {
    guard condition() else { fatalError("FAIL: \(name)") }
    count += 1; print("PASS: \(name)")
}
check("Snap rounds to closest grid cell", Layout.position(31, extent: 1000, size: 240, snap: true, grid: 20) == 40)
check("Negative position stays visible", Layout.position(-25, extent: 1000, size: 240, snap: false, grid: 20) == 0)
check("Oversized widget stays on screen", Layout.position(200, extent: 100, size: 240, snap: true, grid: 20) == 0)
check("Right edge remains reachable", Layout.position(990, extent: 1000, size: 240, snap: true, grid: 20) == 760)
check("Invalid coordinates recover", Layout.position(.nan, extent: 1000, size: 240, snap: true, grid: 0) == 0)
var preferences = Preferences()
preferences.widgets = WidgetKind.allCases.map { DesktopWidget(kind: $0) }
preferences.widgets[0].fontName = "Georgia"
preferences.widgets[0].surface = .clear
preferences.widgets[0].screenID = "42"
preferences.wallpaper.colors = ["ABCDEF", "123456"]
preferences.presence = .neither
let encoded = try JSONEncoder().encode(preferences)
let decoded = try JSONDecoder().decode(Preferences.self, from: encoded)
check("All widget properties survive relaunch", decoded.widgets == preferences.widgets)
check("Wallpaper properties survive relaunch", decoded.wallpaper == preferences.wallpaper)
check("Hidden app preference persists", decoded.presence == .neither)
check("Network connections are opt-in", !Preferences().codexEnabled && !Preferences().weatherEnabled && !DesktopWidget(kind: .html).networkAllowed)
let codex = Data(#"{"timestamp":"2026-11-16T12:00:00.000Z","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":23.5,"window_minutes":300,"resets_at":1800000000},"secondary":{"used_percent":42,"window_minutes":10080}}}}"#.utf8)
let snapshot = UsageParser.parse(codex, provider: "Codex", captured: .now)!
check("Codex remaining is derived from official percent", snapshot.windows[0].remaining == 76.5)
check("Codex window duration is not assumed", snapshot.windows[1].label == "7 days")
check("Codex event timestamp overrides file timestamp", snapshot.captured! < Date(timeIntervalSince1970: 1794840001))
let weekly = Data(#"{"rate_limits":{"primary":{"used_percent":10,"window_minutes":10080},"secondary":null}}"#.utf8)
check("Weekly-only plan supported", UsageParser.parse(weekly, provider: "Codex", captured: .now)?.windows.first?.label == "7 days")
let claude = Data(#"{"rate_limits":{"five_hour":{"used_percentage":32,"resets_at":1800000000},"seven_day":{"used_percentage":87}}}"#.utf8)
check("Claude both windows parsed", UsageParser.parse(claude, provider: "Claude Code", captured: .now)?.windows.count == 2)
check("Claude remaining accurate", UsageParser.parse(claude, provider: "Claude Code", captured: .now)?.windows[1].remaining == 13)
check("Missing allowance never becomes 100 percent", UsageParser.parse(Data(#"{"rate_limits":{}}"#.utf8), provider: "Codex", captured: .now) == nil)
check("Malformed input handled", UsageParser.parse(Data("oops".utf8), provider: "Codex", captured: .now) == nil)
check("Out-of-range percent rejected", UsageParser.parse(Data(#"{"rate_limits":{"primary":{"used_percent":120}}}"#.utf8), provider: "Codex", captured: .now) == nil)
check("Old snapshot labeled stale", UsageSnapshot(captured: Date().addingTimeInterval(-1000)).stale)
check("New snapshot not stale", !UsageSnapshot(captured: Date()).stale)
check("Boolean allowance rejected", UsageParser.parse(Data(#"{"rate_limits":{"primary":{"used_percent":true}}}"#.utf8), provider: "Codex", captured: .now) == nil)

let legacyObject = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
let legacy = try JSONDecoder().decode(Preferences.self, from: legacyData)
check("Version 1 preferences load without new motion keys", legacy.pauseInLowPower == nil && legacy.respectReduceMotion == nil)
check("Old widgets gain default optional options", legacy.widgets[0].settings.goal == 8)
var options = WidgetOptions()
options.startedAt = Date(timeIntervalSince1970: 100)
options.elapsed = 20
check("Stopwatch resumes stored elapsed time", WidgetMath.stopwatch(options, at: Date(timeIntervalSince1970: 110)) == 30)
options.count = 7; options.dayKey = "yesterday"
check("Daily water count resets by date", WidgetMath.dailyCount(options, at: .now) == 0)
check("Web shortcut blocks scripts", WidgetMath.safeURL("javascript:alert(1)") == nil)
check("Web shortcut accepts HTTPS", WidgetMath.safeURL("https://example.com") != nil)
check("29 widget choices", WidgetKind.allCases.count == 29)
func reason(battery: Bool = false, low: Bool = false, reduce: Bool = false, pauseBattery: Bool = false, pauseLow: Bool = true, respect: Bool = true) -> String? {
    MotionPolicy.pauseReason(enabled: true, sleeping: false, lowPower: low, reduceMotion: reduce, onBattery: battery, pauseOnBattery: pauseBattery, pauseInLowPower: pauseLow, respectReduceMotion: respect)
}
check("Battery animation allowed", reason(battery: true) == nil)
check("Battery pause explained", reason(battery: true, pauseBattery: true) == "Battery animation is disabled")
check("Low power override works", reason(battery: true, low: true, pauseLow: false) == nil)
check("Low power pause explained", reason(low: true) == "Low Power Mode is enabled")
check("Reduce Motion override works", reason(reduce: true, respect: false) == nil)
check("Reduce Motion pause explained", reason(reduce: true) == "Reduce Motion is enabled")
check("Battery zero percent valid", BatteryParser.percentage("0%") == 0)
check("Battery percent string parsed", BatteryParser.percentage("87%") == 87)
check("Missing battery stays missing", BatteryParser.percentage(nil) == nil)
check("Out of range battery rejected", BatteryParser.percentage(101) == nil)
check("Boolean battery rejected", BatteryParser.percentage(true) == nil)
let bluetooth = Data(#"{"SPBluetoothDataType":[{"device_connected":[{"AirPods":{"device_address":"AA","device_batteryLevelLeft":"62%","device_batteryLevelRight":"70%","device_batteryLevelCase":"90%"}},{"Keyboard":{"device_address":"BB","device_batteryLevelMain":"41%"}},{"Speaker":{"device_address":"CC"}}],"device_not_connected":[{"Old Mouse":{"device_batteryLevelMain":"99%"}}]}]}"#.utf8)
let devices = BatteryParser.bluetooth(bluetooth)!
check("Separate earbud and case readings", devices.filter { $0.name == "AirPods" }.count == 3)
check("Keyboard battery included", devices.first { $0.name == "Keyboard" }?.percent == 41)
check("Unknown battery is unavailable", devices.first { $0.name == "Speaker" }?.percent == nil)
check("Disconnected devices excluded", !devices.contains { $0.name == "Old Mouse" })
check("Malformed Bluetooth snapshot rejected", BatteryParser.bluetooth(Data("oops".utf8)) == nil)
var calc = CalculatorState()
["2", "+", "3", "="].forEach { calc.press($0) }
check("Calculator addition", calc.display == "5")
["C", "6", "÷", "0", "="].forEach { calc.press($0) }
check("Calculator divide by zero", calc.display == "Error")
["C", "1", ".", "5", "×", "2", "="].forEach { calc.press($0) }
check("Calculator decimal multiplication", calc.display == "3")

check("App synonym finds launcher", WidgetKind.launcher.matches("apps"))
check("Folder synonym finds launcher", WidgetKind.launcher.matches("folders"))
check("Music finds Now Playing", WidgetKind.nowPlaying.matches("music"))
check("Browser finds Now Playing", WidgetKind.nowPlaying.matches("browser"))
check("Search ignores case and accents", SearchText.matches("CAFE", in: "Café"))
check("Search uses all terms", SearchText.matches("open app", in: "applications open"))
check("Search rejects absent words", !SearchText.matches("open banana", in: "applications open"))
check("Old options default launcher settings", decoded.widgets[0].settings.launchItems == nil && decoded.widgets[0].settings.mediaSource == nil)
check("Media connection is opt-in", Preferences().connectedPlayers == nil)
check("Numeric version ordering", AppVersion("1.10.0")! > AppVersion("1.9.9")!)
check("Version prefix accepted", AppVersion("v1.2.0") == AppVersion("1.2"))
check("Prerelease version rejected", AppVersion("1.2.0-beta") == nil)
check("Malformed version rejected", AppVersion("1..2") == nil)
let releaseJSON = Data(#"{"tag_name":"v1.3.0","body":"Improvements","draft":false,"prerelease":false,"assets":[{"name":"SimpleScreen-macOS.zip","size":10,"browser_download_url":"https://github.com/Tekwiz17/SimpleScreen/releases/download/v1.3.0/SimpleScreen-macOS.zip"}]}"#.utf8)
let release = try JSONDecoder().decode(AppRelease.self, from: releaseJSON)
check("Trusted release asset accepted", release.assetURL("SimpleScreen-macOS.zip") != nil)
check("Missing release asset rejected", release.assetURL("SHA256SUMS.txt") == nil)
let badRelease = try JSONDecoder().decode(AppRelease.self, from: Data(String(decoding: releaseJSON, as: UTF8.self).replacingOccurrences(of: "https://github.com", with: "https://example.com").utf8))
check("Untrusted update host rejected", badRelease.assetURL("SimpleScreen-macOS.zip") == nil)
let checksum = String(repeating: "a", count: 64)
check("Checksum selects expected asset", UpdateValidation.checksum(checksum + "  SimpleScreen-macOS.zip\n", filename: "SimpleScreen-macOS.zip") == checksum)
check("Wrong checksum asset rejected", UpdateValidation.checksum(checksum + " other.zip", filename: "SimpleScreen-macOS.zip") == nil)
check("Malformed checksum rejected", UpdateValidation.checksum("xyz SimpleScreen-macOS.zip", filename: "SimpleScreen-macOS.zip") == nil)
check("Expected archive paths accepted", UpdateValidation.safeArchivePaths("SimpleScreen.app/\nSimpleScreen.app/Contents/Info.plist"))
check("Archive traversal rejected", !UpdateValidation.safeArchivePaths("SimpleScreen.app/../../outside"))
check("Absolute archive path rejected", !UpdateValidation.safeArchivePaths("/Applications/Other.app"))
let media = NowPlayingSnapshot.decode(Data(#"{"title":"Track","artist":"Artist","album":"Album","state":"playing","position":120,"duration":60,"artwork":"https://example.com/art.png","error":null}"#.utf8))!
check("Media position clamped", media.position == 60)
check("HTTPS artwork allowed", media.validArtworkURL != nil)
let unsafeArt = NowPlayingSnapshot(title: "Test", artist: "", album: "", state: "paused", position: 0, duration: 1, artwork: "file:///private/test")
check("Local file artwork rejected", unsafeArt.validArtworkURL == nil)
check("Browser player classification", MediaSource.chrome.browser && !MediaSource.music.browser)
print("\(count) model checks passed.")


