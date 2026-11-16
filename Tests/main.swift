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
print("\(count) model checks passed.")
