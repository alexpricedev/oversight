#!/usr/bin/env swift

// Draws the Oversight app icon and writes a macOS AppIcon asset set.
//
//   swift Scripts/GenerateAppIcon.swift [output-dir] [preview-path]
//
// The mark is the app's own shape: four cards on a dark squircle, with the
// active card highlighted. Everything is drawn at 1024pt and downsampled, so
// no external tools or fonts are involved.

import AppKit
import Foundation

let outputDirectory = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Sources/Assets.xcassets/AppIcon.appiconset"
let previewPath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : nil

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func makeBitmap(width: Int, height: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: width, height: height)
    return rep
}

func makeBitmap(size: Int) -> NSBitmapImageRep {
    makeBitmap(width: size, height: size)
}

func drawIcon() -> NSBitmapImageRep {
    let master = makeBitmap(size: 1024)
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    guard let context = NSGraphicsContext(bitmapImageRep: master) else { return master }
    NSGraphicsContext.current = context

    let squircle = NSBezierPath(
        roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824),
        xRadius: 185,
        yRadius: 185
    )

    // Soft drop shadow so the icon sits well in the Dock.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 26
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    color(0x0C1218).setFill()
    squircle.fill()
    NSGraphicsContext.restoreGraphicsState()

    let background = NSGradient(starting: color(0x35495E), ending: color(0x0D1620))!
    background.draw(in: squircle, angle: -90)

    color(0xFFFFFF, 0.08).setStroke()
    squircle.lineWidth = 3
    squircle.stroke()

    // Three columns, one highlighted: the dashboard at a glance.
    let columnWidth: CGFloat = 180
    let columnHeight: CGFloat = 436
    let gap: CGFloat = 18
    let totalWidth = columnWidth * 3 + gap * 2
    let originX = (1024 - totalWidth) / 2
    let originY = (1024 - columnHeight) / 2

    for index in 0 ..< 3 {
        let rect = NSRect(
            x: originX + CGFloat(index) * (columnWidth + gap),
            y: originY,
            width: columnWidth,
            height: columnHeight
        )
        let card = NSBezierPath(roundedRect: rect, xRadius: 34, yRadius: 34)

        if index == 1 {
            let accent = NSGradient(starting: color(0x63B1FF), ending: color(0x2D66DB))!
            accent.draw(in: card, angle: -90)

            // A check mark: the run that passed.
            let check = NSBezierPath()
            let centre = NSPoint(x: rect.midX, y: rect.midY)
            check.move(to: NSPoint(x: centre.x - 40, y: centre.y + 2))
            check.line(to: NSPoint(x: centre.x - 9, y: centre.y - 31))
            check.line(to: NSPoint(x: centre.x + 43, y: centre.y + 36))
            check.lineWidth = 22
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            NSColor.white.withAlphaComponent(0.95).setStroke()
            check.stroke()
        } else {
            color(0xFFFFFF, 0.08).setFill()
            card.fill()
            color(0xFFFFFF, 0.14).setStroke()
            card.lineWidth = 2.5
            card.stroke()

            // A short list of rows, so the columns read as content.
            for line in 0 ..< 4 {
                let height: CGFloat = line == 0 ? 15 : 10
                let row = NSBezierPath(
                    roundedRect: NSRect(
                        x: rect.minX + 26,
                        y: rect.maxY - 64 - CGFloat(line) * 48,
                        width: columnWidth - 52,
                        height: height
                    ),
                    xRadius: height / 2,
                    yRadius: height / 2
                )
                color(0xFFFFFF, line == 0 ? 0.18 : 0.10).setFill()
                row.fill()
            }
        }
    }

    return master
}

func png(_ master: NSBitmapImageRep, size: Int) -> Data {
    let target = makeBitmap(size: size)
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    guard let context = NSGraphicsContext(bitmapImageRep: target) else {
        return Data()
    }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    master.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    return target.representation(using: .png, properties: [:]) ?? Data()
}

let master = drawIcon()

let variants: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]

try FileManager.default.createDirectory(
    atPath: outputDirectory,
    withIntermediateDirectories: true
)

for variant in variants {
    let pixels = variant.points * variant.scale
    let suffix = variant.scale == 1 ? "" : "@\(variant.scale)x"
    let name = "icon_\(variant.points)\(suffix).png"
    let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent(name)
    try png(master, size: pixels).write(to: url)
}

let contents = """
{
  "images" : [
    { "filename" : "icon_16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
try contents.write(
    toFile: URL(fileURLWithPath: outputDirectory).appendingPathComponent("Contents.json").path,
    atomically: true,
    encoding: .utf8
)

let catalogRoot = URL(fileURLWithPath: outputDirectory).deletingLastPathComponent()
try """
{
  "info" : { "author" : "xcode", "version" : 1 }
}
""".write(
    toFile: catalogRoot.appendingPathComponent("Contents.json").path,
    atomically: true,
    encoding: .utf8
)

// A contact sheet for reviewing the icon at Dock and Finder sizes.
if let previewPath {
    let sizes = [16, 32, 64, 128, 256]
    let sheetWidth = 700
    let sheetHeight = 620
    let sheet = makeBitmap(width: sheetWidth, height: sheetHeight)

    NSGraphicsContext.saveGraphicsState()
    if let sheetContext = NSGraphicsContext(bitmapImageRep: sheet) {
        NSGraphicsContext.current = sheetContext

        let rows: [(NSColor, CGFloat)] = [
            (color(0xF2F3F5), 320),
            (color(0x1B1D21), 20),
        ]
        for (background, y) in rows {
            let panel = NSBezierPath(
                roundedRect: NSRect(x: 20, y: y, width: CGFloat(sheetWidth) - 40, height: 280),
                xRadius: 18,
                yRadius: 18
            )
            background.setFill()
            panel.fill()

            var x: CGFloat = 44
            for size in sizes {
                let image = NSImage(size: NSSize(width: size, height: size))
                if let rep = NSBitmapImageRep(data: png(master, size: size)) {
                    image.addRepresentation(rep)
                }
                image.draw(
                    in: NSRect(x: x, y: y + 140 - CGFloat(size) / 2, width: CGFloat(size), height: CGFloat(size)),
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1
                )
                x += CGFloat(size) + 24
            }
        }
        NSGraphicsContext.restoreGraphicsState()
    }
    try sheet.representation(using: .png, properties: [:])?
        .write(to: URL(fileURLWithPath: previewPath))
}

print("Wrote \(outputDirectory)")
