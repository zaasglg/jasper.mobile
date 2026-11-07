// Run from the project root: swift tool/generate_app_icons.swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("assets/images/app_icon_source.png")
guard let source = NSImage(contentsOf: sourceURL) else {
    fatalError("Cannot read \(sourceURL.path)")
}

func render(_ size: Int, to path: String, contentScale: CGFloat = 1) throws {
    let pixels = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    let context = NSGraphicsContext(cgContext: pixels, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    NSColor.white.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()
    let side = CGFloat(size) * contentScale
    let inset = (CGFloat(size) - side) / 2
    source.draw(in: NSRect(x: inset, y: inset, width: side, height: side),
                from: .zero, operation: .sourceOver, fraction: 1)
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    let target = root.appendingPathComponent(path)
    try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
    let bitmap = NSBitmapImageRep(cgImage: pixels.makeImage()!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: target)
}

let catalogPath = "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent(catalogPath + "Contents.json"))) as! [String: Any]
for entry in catalog["images"] as! [[String: String]] {
    let points = Double(entry["size"]!.components(separatedBy: "x")[0])!
    let scale = Double(entry["scale"]!.replacingOccurrences(of: "x", with: ""))!
    try render(Int(points * scale), to: catalogPath + entry["filename"]!)
}

for (density, size, adaptiveSize) in [
    ("mdpi", 48, 108), ("hdpi", 72, 162), ("xhdpi", 96, 216),
    ("xxhdpi", 144, 324), ("xxxhdpi", 192, 432)
] {
    let path = "android/app/src/main/res/mipmap-\(density)/"
    try render(size, to: path + "ic_launcher.png")
    // Android masks adaptive icons. Keep the supplied artwork in the safe area.
    try render(adaptiveSize, to: path + "ic_launcher_foreground.png", contentScale: 2.0 / 3.0)
}
print("Generated iOS and Android launcher icons.")
