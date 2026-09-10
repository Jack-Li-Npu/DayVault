#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

private struct IconPalette {
    let background: CGColor
    let back: CGColor
    let offset: CGColor
    let face: CGColor
    let ink: CGColor
}

private func color(_ hex: String) -> CGColor {
    let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    let number = UInt64(value, radix: 16) ?? 0
    return CGColor(
        red: CGFloat((number >> 16) & 0xFF) / 255,
        green: CGFloat((number >> 8) & 0xFF) / 255,
        blue: CGFloat(number & 0xFF) / 255,
        alpha: 1
    )
}

private func cutCornerPath(_ rect: CGRect, cut: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
    path.closeSubpath()
    return path
}

private func dPath(in rect: CGRect) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.52, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.28))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.72))
    path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.52, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.closeSubpath()
    return path
}

private func render(_ palette: IconPalette, to url: URL) throws {
    let size = 1_024
    let space = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: space,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        throw NSError(domain: "DayVaultIcon", code: 1)
    }

    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    context.setFillColor(palette.background)
    context.fill(canvas)

    context.setFillColor(palette.ink)
    context.fill(CGRect(x: 208, y: 154, width: 650, height: 650))
    context.setFillColor(palette.back)
    context.fill(CGRect(x: 144, y: 242, width: 650, height: 650))
    context.setFillColor(palette.offset)
    context.fill(CGRect(x: 256, y: 128, width: 650, height: 650))

    let faceRect = CGRect(x: 188, y: 198, width: 650, height: 650)
    context.addPath(cutCornerPath(faceRect, cut: 118))
    context.setFillColor(palette.face)
    context.fillPath()
    context.addPath(cutCornerPath(faceRect, cut: 118))
    context.setStrokeColor(palette.ink)
    context.setLineWidth(18)
    context.strokePath()

    let markRect = CGRect(x: 328, y: 330, width: 386, height: 386)
    context.addPath(dPath(in: markRect))
    context.setFillColor(palette.ink)
    context.fillPath()

    let vRect = markRect.insetBy(dx: 96, dy: 72)
    context.move(to: CGPoint(x: vRect.minX, y: vRect.maxY))
    context.addLine(to: CGPoint(x: vRect.midX, y: vRect.minY))
    context.addLine(to: CGPoint(x: vRect.maxX, y: vRect.maxY))
    context.setStrokeColor(palette.face)
    context.setLineWidth(54)
    context.setLineCap(.square)
    context.setLineJoin(.miter)
    context.strokePath()

    context.setFillColor(palette.ink)
    for index in 0..<4 {
        context.fill(CGRect(x: 248 + index * 44, y: 260, width: 24, height: 24))
    }

    guard let image = context.makeImage() else {
        throw NSError(domain: "DayVaultIcon", code: 2)
    }
    let representation = NSBitmapImageRep(cgImage: image)
    guard let data = representation.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "DayVaultIcon", code: 3)
    }
    try data.write(to: url, options: .atomic)
}

private let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let outputs: [(String, IconPalette)] = [
    (
        "DayVault/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
        IconPalette(background: color("#F4F0E7"), back: color("#4F46E5"), offset: color("#FF6B4A"), face: color("#DDFB58"), ink: color("#171714"))
    ),
    (
        "DayVault/Assets.xcassets/AppIconEmerald.appiconset/AppIconEmerald-1024.png",
        IconPalette(background: color("#EAF3E7"), back: color("#145B45"), offset: color("#FF6B4A"), face: color("#67D7AC"), ink: color("#11110F"))
    ),
    (
        "DayVault/Assets.xcassets/AppIconGraphite.appiconset/AppIconGraphite-1024.png",
        IconPalette(background: color("#E8E5DC"), back: color("#6A6760"), offset: color("#FF6B4A"), face: color("#F7F3E8"), ink: color("#171714"))
    ),
]

private let designCopies = [
    "Design/dayvault-app-icon-source.png",
    "Design/dayvault-app-icon-emerald-source.png",
    "Design/dayvault-app-icon-graphite-source.png",
]

for (index, output) in outputs.enumerated() {
    let (relativePath, palette) = output
    try render(palette, to: root.appendingPathComponent(relativePath))
    try render(palette, to: root.appendingPathComponent(designCopies[index]))
}
