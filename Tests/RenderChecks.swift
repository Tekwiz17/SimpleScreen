import AppKit
import SwiftUI

@main struct RenderChecks {
    @MainActor static func main() {
        var count = 0
        for style in WallpaperStyle.allCases where style != .image {
            for palette in Palette.all {
                let view = WallpaperCanvas(wallpaper: Wallpaper(style: style, colors: palette.colors), time: 0.7).frame(width: 640, height: 360)
                let renderer = ImageRenderer(content: view)
                guard let image = renderer.cgImage, image.width == 640, let bytes = image.dataProvider?.data else { fatalError("Render failed: \(style)") }
                let data = bytes as Data
                guard Set(data.prefix(100_000)).count > 12 else { fatalError("Blank wallpaper: \(style)") }
                count += 1
            }
        }
        print("\(count) wallpaper renders passed.")
    }
}
