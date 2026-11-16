import AppKit
import SwiftUI

@main struct RenderChecks {
    @MainActor static func main() {
        var count = 0
        for style in WallpaperStyle.allCases where style != .image {
            for palette in Palette.all {
                let wallpaper = Wallpaper(style: style, colors: palette.colors)
                let first = render(wallpaper, time: 0)
                let second = render(wallpaper, time: 2)
                guard Set(first.prefix(100_000)).count > 12 else { fatalError("Blank wallpaper: \(style)") }
                guard first != second else { fatalError("Wallpaper never moves: \(style)") }
                count += 1
            }
        }
        print("\(count) wallpaper palette render-and-motion checks passed.")
    }
    @MainActor static func render(_ wallpaper: Wallpaper, time: Double) -> Data {
        let view = WallpaperCanvas(wallpaper: wallpaper, time: time).frame(width: 640, height: 360)
        let renderer = ImageRenderer(content: view)
        guard let image = renderer.cgImage, image.width == 640, let bytes = image.dataProvider?.data else { fatalError("Render failed") }
        return bytes as Data
    }
}
