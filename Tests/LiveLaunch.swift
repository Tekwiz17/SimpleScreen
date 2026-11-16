import AppKit
let pid = Int(CommandLine.arguments[1])!
let widgetsMode = CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "widgets"
let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
let mine = windows.filter { $0[kCGWindowOwnerPID as String] as? Int == pid }
if widgetsMode {
    let level = Int(CGWindowLevelForKey(.desktopIconWindow) + 1)
    let widgets = mine.filter { $0[kCGWindowLayer as String] as? Int == level }
    guard widgets.count == 29 else { fatalError("Expected 29 desktop widgets, found \(widgets.count)") }
    guard level < 0 else { fatalError("Widgets must stay behind normal application windows") }
    print("All 29 saved widget types launched at the correct desktop level.")
} else {
    guard mine.contains(where: {
        guard $0[kCGWindowLayer as String] as? Int == 0,
              let bounds = $0[kCGWindowBounds as String] as? NSDictionary,
              let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return false }
        return rect.width >= 800 && rect.height >= 600
    }) else { fatalError("First launch did not show settings") }
    print("Live first-launch settings check passed.")
}
let wallpaperLevel = Int(CGWindowLevelForKey(.desktopWindow) + 1)
guard mine.contains(where: { $0[kCGWindowLayer as String] as? Int == wallpaperLevel }) else { fatalError("Desktop wallpaper is missing or at wrong level") }
print("Desktop wallpaper window level check passed.")
