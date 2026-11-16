import Foundation
import AppKit

@main struct SeedWidgets {
    static func main() throws {
        var preferences = Preferences()
        preferences.onboardingComplete = true
        preferences.wallpaper.animated = false
        preferences.widgets = WidgetKind.allCases.enumerated().map { index, kind in
            var widget = DesktopWidget(kind: kind)
            widget.x = Double(index % 4) * 250
            widget.y = Double(index / 4) * 180 + 40
            return widget
        }
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SimpleScreen")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONEncoder().encode(preferences).write(to: folder.appendingPathComponent("Preferences.json"), options: .atomic)
        print("Seeded all 27 widget kinds for live launch.")
    }
}
