#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate_app_icon.swift /path/to/AppIcon.icns\n", stderr)
    exit(64)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let fileManager = FileManager.default
let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("InboxCourierIcon-\(UUID().uuidString)", isDirectory: true)
let iconsetURL = temporaryDirectory.appendingPathComponent("AppIcon.iconset", isDirectory: true)

try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let icons: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func drawIcon(pixels: Int) -> NSImage {
    let size = NSSize(width: pixels, height: pixels)
    let image = NSImage(size: size)

    image.lockFocus()
    defer { image.unlockFocus() }

    let rect = NSRect(origin: .zero, size: size)
    NSColor.clear.setFill()
    rect.fill()

    let radius = CGFloat(pixels) * 0.22
    let background = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(pixels) * 0.055, dy: CGFloat(pixels) * 0.055), xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.10, green: 0.43, blue: 0.95, alpha: 1.0),
        NSColor(calibratedRed: 0.10, green: 0.72, blue: 0.70, alpha: 1.0)
    ])
    gradient?.draw(in: background, angle: -35)

    NSColor(calibratedWhite: 0.0, alpha: 0.16).setFill()
    NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(pixels) * 0.055, dy: CGFloat(pixels) * 0.055), xRadius: radius, yRadius: radius).fill()
    gradient?.draw(in: background, angle: -35)

    let trayRect = NSRect(
        x: CGFloat(pixels) * 0.20,
        y: CGFloat(pixels) * 0.24,
        width: CGFloat(pixels) * 0.60,
        height: CGFloat(pixels) * 0.38
    )
    let lineWidth = max(2, CGFloat(pixels) * 0.045)

    let tray = NSBezierPath()
    tray.lineWidth = lineWidth
    tray.lineJoinStyle = .round
    tray.lineCapStyle = .round
    tray.move(to: NSPoint(x: trayRect.minX, y: trayRect.maxY))
    tray.line(to: NSPoint(x: trayRect.minX + trayRect.width * 0.18, y: trayRect.minY))
    tray.line(to: NSPoint(x: trayRect.maxX - trayRect.width * 0.18, y: trayRect.minY))
    tray.line(to: NSPoint(x: trayRect.maxX, y: trayRect.maxY))
    tray.move(to: NSPoint(x: trayRect.minX + trayRect.width * 0.23, y: trayRect.minY + trayRect.height * 0.43))
    tray.line(to: NSPoint(x: trayRect.maxX - trayRect.width * 0.23, y: trayRect.minY + trayRect.height * 0.43))
    NSColor.white.withAlphaComponent(0.96).setStroke()
    tray.stroke()

    let arrow = NSBezierPath()
    arrow.lineWidth = lineWidth
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.move(to: NSPoint(x: CGFloat(pixels) * 0.50, y: CGFloat(pixels) * 0.75))
    arrow.line(to: NSPoint(x: CGFloat(pixels) * 0.50, y: CGFloat(pixels) * 0.43))
    arrow.move(to: NSPoint(x: CGFloat(pixels) * 0.36, y: CGFloat(pixels) * 0.56))
    arrow.line(to: NSPoint(x: CGFloat(pixels) * 0.50, y: CGFloat(pixels) * 0.42))
    arrow.line(to: NSPoint(x: CGFloat(pixels) * 0.64, y: CGFloat(pixels) * 0.56))
    NSColor.white.setStroke()
    arrow.stroke()

    let dotRect = NSRect(
        x: CGFloat(pixels) * 0.64,
        y: CGFloat(pixels) * 0.62,
        width: CGFloat(pixels) * 0.13,
        height: CGFloat(pixels) * 0.13
    )
    NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.24, alpha: 1.0).setFill()
    NSBezierPath(ovalIn: dotRect).fill()

    return image
}

func writePNG(image: NSImage, to url: URL) throws {
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw CocoaError(.fileWriteUnknown)
    }

    try pngData.write(to: url)
}

for icon in icons {
    let image = drawIcon(pixels: icon.pixels)
    try writePNG(image: image, to: iconsetURL.appendingPathComponent(icon.name))
}

try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
if fileManager.fileExists(atPath: outputURL.path) {
    try fileManager.removeItem(at: outputURL)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", "-o", outputURL.path, iconsetURL.path]
try process.run()
process.waitUntilExit()

try? fileManager.removeItem(at: temporaryDirectory)

if process.terminationStatus != 0 {
    exit(process.terminationStatus)
}
