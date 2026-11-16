import AppKit
let pid = Int(CommandLine.arguments[1])!
let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
let mine = windows.filter { $0[kCGWindowOwnerPID as String] as? Int == pid }
guard mine.contains(where: {
    guard $0[kCGWindowLayer as String] as? Int == 0,
          let bounds = $0[kCGWindowBounds as String] as? NSDictionary,
          let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return false }
    return rect.width >= 800 && rect.height >= 600
}) else { fatalError("First launch did not show settings") }
let wallpaperLevel = Int(CGWindowLevelForKey(.desktopWindow) + 1)
guard mine.contains(where: { $0[kCGWindowLayer as String] as? Int == wallpaperLevel }) else { fatalError("Desktop wallpaper is missing or at wrong level") }
print("Live first-launch settings and desktop window checks passed.")
