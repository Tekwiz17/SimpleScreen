import AppKit
import Foundation

let destination = CommandLine.arguments[1]
let directory = URL(fileURLWithPath: destination).deletingPathExtension().appendingPathExtension("iconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
func draw(size: Int, name: String) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let c = context.cgContext
    c.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let outline = NSBezierPath(roundedRect: NSRect(x: 60, y: 60, width: 904, height: 904), xRadius: 205, yRadius: 205)
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.22); shadow.shadowBlurRadius = 28; shadow.shadowOffset = NSSize(width: 0, height: -12); shadow.set()
    NSColor(calibratedRed: 0.08, green: 0.24, blue: 0.31, alpha: 1).setFill(); outline.fill()
    NSShadow().set()
    NSGradient(colors: [
        NSColor(calibratedRed: 0.11, green: 0.31, blue: 0.40, alpha: 1),
        NSColor(calibratedRed: 0.31, green: 0.62, blue: 0.64, alpha: 1),
        NSColor(calibratedRed: 0.73, green: 0.88, blue: 0.81, alpha: 1)
    ])!.draw(in: outline, angle: 55)
    c.saveGState(); outline.addClip()
    let wave = NSBezierPath()
    wave.move(to: NSPoint(x: -50, y: 220))
    wave.curve(to: NSPoint(x: 1100, y: 590), controlPoint1: NSPoint(x: 300, y: 830), controlPoint2: NSPoint(x: 710, y: -50))
    wave.line(to: NSPoint(x: 1100, y: -20)); wave.line(to: NSPoint(x: -50, y: -20)); wave.close()
    NSGradient(starting: .white.withAlphaComponent(0.42), ending: .white.withAlphaComponent(0.02))!.draw(in: wave, angle: 90)
    c.restoreGState()
    let glass = NSBezierPath(roundedRect: NSRect(x: 240, y: 285, width: 544, height: 454), xRadius: 76, yRadius: 76)
    let glassShadow = NSShadow(); glassShadow.shadowColor = .black.withAlphaComponent(0.17); glassShadow.shadowBlurRadius = 28; glassShadow.shadowOffset = NSSize(width: 0, height: -14); glassShadow.set()
    NSColor.white.withAlphaComponent(0.12).setFill(); glass.fill(); NSShadow().set()
    NSGradient(starting: .white.withAlphaComponent(0.36), ending: .white.withAlphaComponent(0.05))!.draw(in: glass, angle: 90)
    NSColor.white.withAlphaComponent(0.65).setStroke(); glass.lineWidth = 3; glass.stroke()
    let small = NSBezierPath(roundedRect: NSRect(x: 286, y: 332, width: 452, height: 359), xRadius: 42, yRadius: 42)
    NSColor.white.withAlphaComponent(0.17).setFill(); small.fill()
    let horizon = NSBezierPath()
    horizon.move(to: NSPoint(x: 320, y: 415))
    horizon.curve(to: NSPoint(x: 704, y: 485), controlPoint1: NSPoint(x: 445, y: 580), controlPoint2: NSPoint(x: 535, y: 350))
    NSColor.white.withAlphaComponent(0.95).setStroke(); horizon.lineWidth = 15; horizon.lineCapStyle = .round; horizon.stroke()
    NSColor.white.withAlphaComponent(0.95).setFill()
    NSBezierPath(ovalIn: NSRect(x: 598, y: 567, width: 48, height: 48)).fill()
    NSColor.white.withAlphaComponent(0.3).setStroke(); outline.lineWidth = 3; outline.stroke()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
}
for size in [16, 32, 128, 256, 512] {
    try draw(size: size, name: "icon_\(size)x\(size).png")
    try draw(size: size * 2, name: "icon_\(size)x\(size)@2x.png")
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", directory.path, "-o", destination]
try task.run(); task.waitUntilExit()
guard task.terminationStatus == 0 else { fatalError("iconutil failed") }

try FileManager.default.removeItem(at: directory)
