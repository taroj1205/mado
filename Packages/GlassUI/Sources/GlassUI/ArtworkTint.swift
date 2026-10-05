import AppKit

enum ArtworkTint {
    private static let side = 16
    private static let bits = 8
    private static let channels = 4
    private static let evenWeight = 0.002
    private static let lifelessSaturation = 0.12
    private static let saturation = (floor: 0.45, ceiling: 0.9)
    private static let brightness = (floor: 0.4, ceiling: 0.95)

    static func of(_ image: NSImage) -> NSColor? {
        guard let sample = sample(image) else { return nil }
        var total = 0.0
        var mix = (red: 0.0, green: 0.0, blue: 0.0)
        for column in 0..<side {
            for row in 0..<side {
                guard let pixel = sample.colorAt(x: column, y: row)?.usingColorSpace(.sRGB) else {
                    continue
                }
                let weight = evenWeight + pixel.saturationComponent * pixel.brightnessComponent
                total += weight * pixel.alphaComponent
                mix.red += weight * pixel.alphaComponent * pixel.redComponent
                mix.green += weight * pixel.alphaComponent * pixel.greenComponent
                mix.blue += weight * pixel.alphaComponent * pixel.blueComponent
            }
        }
        guard total > 0 else { return nil }
        let average = NSColor(
            srgbRed: mix.red / total, green: mix.green / total, blue: mix.blue / total, alpha: 1)
        let light = min(max(average.brightnessComponent, brightness.floor), brightness.ceiling)
        guard average.saturationComponent > lifelessSaturation else {
            return NSColor(white: light, alpha: 1)
        }
        return NSColor(
            hue: average.hueComponent,
            saturation: min(max(average.saturationComponent, saturation.floor), saturation.ceiling),
            brightness: light, alpha: 1)
    }

    private static func sample(_ image: NSImage) -> NSBitmapImageRep? {
        guard
            let bitmap = unsafe NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: bits,
                samplesPerPixel: channels, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
            let context = NSGraphicsContext(bitmapImageRep: bitmap)
        else { return nil }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        image.draw(
            in: NSRect(x: 0, y: 0, width: side, height: side), from: .zero, operation: .copy,
            fraction: 1)
        return bitmap
    }
}
