#!/usr/bin/env swift
//
// Generates the two raster assets the pages reference:
//
//   assets/og-image.png         1200×630  social preview card
//   assets/apple-touch-icon.png  180×180  iOS home-screen bookmark
//
// Raster rather than SVG because Open Graph consumers (iMessage, Slack, X,
// WhatsApp) will not render an SVG preview, and apple-touch-icon has never
// supported it.
//
// The lotus is drawn from the same petal arrangement as assets/favicon.svg and
// the app's own icon, so all three stay one drawing. There is still no build
// step for the site: these PNGs are committed, and this script only exists to
// regenerate them.
//
// Run: swift scripts/generate-assets.swift

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// The teal ramp and warm grey, matching assets/style.css.
func hex(_ value: UInt32) -> CGColor {
    CGColor(
        red: CGFloat((value >> 16) & 0xFF) / 255,
        green: CGFloat((value >> 8) & 0xFF) / 255,
        blue: CGFloat(value & 0xFF) / 255,
        alpha: 1
    )
}

let tealSoft = hex(0xE1F5EE)  // teal 50 — the tinted background
let tealEdge = hex(0x9FE1CB)  // teal 100
let tealMid = hex(0x1D9E75)   // teal 400
let tealDeep = hex(0x0F6E56)  // teal 600 — the identity stop
let inkStrong = hex(0x04342C)  // teal 900
let inkMuted = hex(0x085041)   // teal 800

let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()

func context(width: Int, height: Int) -> CGContext {
    guard
        let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            // Opaque: an apple-touch-icon with alpha gets a black matte on iOS.
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
    else { fatalError("could not create a \(width)×\(height) context") }
    return ctx
}

/// One petal: an ellipse whose base sits `distance` from the centre, rotated
/// into place. Matches the favicon's construction.
func drawPetalRing(
    in ctx: CGContext,
    centre: CGPoint,
    count: Int,
    radiusX: CGFloat,
    radiusY: CGFloat,
    distance: CGFloat,
    angleOffset: CGFloat,
    colour: CGColor
) {
    for index in 0..<count {
        let angle = (CGFloat(index) + angleOffset) / CGFloat(count) * 2 * .pi
        ctx.saveGState()
        ctx.translateBy(x: centre.x, y: centre.y)
        ctx.rotate(by: angle)
        ctx.setFillColor(colour)
        ctx.fillEllipse(
            in: CGRect(
                x: -radiusX, y: distance - radiusY,
                width: radiusX * 2, height: radiusY * 2
            )
        )
        ctx.restoreGState()
    }
}

func drawLotus(in ctx: CGContext, centre: CGPoint, size: CGFloat) {
    drawPetalRing(
        in: ctx, centre: centre, count: 6,
        radiusX: size * 0.113, radiusY: size * 0.204,
        distance: size * 0.240, angleOffset: 0, colour: tealDeep
    )
    drawPetalRing(
        in: ctx, centre: centre, count: 6,
        radiusX: size * 0.088, radiusY: size * 0.138,
        distance: size * 0.146, angleOffset: 0.5, colour: tealMid
    )
    ctx.setFillColor(tealEdge)
    ctx.fillEllipse(
        in: CGRect(
            x: centre.x - size * 0.092, y: centre.y - size * 0.092,
            width: size * 0.184, height: size * 0.184
        )
    )
}

// CoreText's attribute names, spelled out rather than using the
// `.font` / `.foregroundColor` conveniences — those are declared by AppKit and
// UIKit, and this script deliberately imports neither.
let fontKey = NSAttributedString.Key(kCTFontAttributeName as String)
let colourKey = NSAttributedString.Key(kCTForegroundColorAttributeName as String)
let kernKey = NSAttributedString.Key(kCTKernAttributeName as String)

func draw(
    _ text: String,
    in ctx: CGContext,
    at point: CGPoint,
    fontName: String,
    size: CGFloat,
    colour: CGColor,
    tracking: CGFloat = 0
) {
    let font = CTFontCreateWithName(fontName as CFString, size, nil)
    var attributes: [NSAttributedString.Key: Any] = [
        fontKey: font,
        colourKey: colour,
    ]
    if tracking != 0 { attributes[kernKey] = tracking }
    let line = CTLineCreateWithAttributedString(
        NSAttributedString(string: text, attributes: attributes)
    )
    ctx.textPosition = point
    CTLineDraw(line, ctx)
}

/// Width of a string, so text can be centred without guessing.
func width(
    _ text: String, fontName: String, size: CGFloat, tracking: CGFloat = 0
) -> CGFloat {
    let font = CTFontCreateWithName(fontName as CFString, size, nil)
    var attributes: [NSAttributedString.Key: Any] = [fontKey: font]
    if tracking != 0 { attributes[kernKey] = tracking }
    let line = CTLineCreateWithAttributedString(
        NSAttributedString(string: text, attributes: attributes)
    )
    return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
}

func write(_ image: CGImage, to relativePath: String) {
    let url = repoRoot.appending(path: relativePath)
    guard
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        )
    else { fatalError("could not create \(url.path)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("could not write \(url.path)")
    }
    print("wrote \(relativePath) — \(image.width)×\(image.height)")
}

// ── Open Graph card ─────────────────────────────────────────────────────────
//
// 1200×630 is the size every consumer crops toward. The lotus sits left of the
// wordmark rather than above it, because previews are often shown letterboxed
// and a vertical stack loses its top.

do {
    let w = 1200, h = 630
    let ctx = context(width: w, height: h)
    ctx.setFillColor(tealSoft)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

    // Sized and placed so the lotus and the text block carry roughly equal
    // weight; the first attempt left a visibly empty right third.
    let lotusSize: CGFloat = 350
    drawLotus(in: ctx, centre: CGPoint(x: 322, y: 315), size: lotusSize)

    let title = "Hasu"
    let tagline = "A quiet place for two"
    let strapline = "ONE SMALL THING A DAY"

    draw(title, in: ctx, at: CGPoint(x: 556, y: 356),
         fontName: "Helvetica-Bold", size: 108, colour: inkStrong)
    draw(tagline, in: ctx, at: CGPoint(x: 560, y: 286),
         fontName: "Helvetica", size: 42, colour: inkMuted)
    draw(strapline, in: ctx, at: CGPoint(x: 562, y: 216),
         fontName: "Helvetica-Bold", size: 20, colour: tealDeep, tracking: 4)

    guard let image = ctx.makeImage() else { fatalError("og render failed") }
    write(image, to: "assets/og-image.png")
}

// ── Apple touch icon ────────────────────────────────────────────────────────
//
// 180×180 covers every current iPhone. iOS applies its own rounding, so this is
// a plain square with the flower inset.

do {
    let side = 180
    let ctx = context(width: side, height: side)
    ctx.setFillColor(tealSoft)
    ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
    drawLotus(
        in: ctx,
        centre: CGPoint(x: CGFloat(side) / 2, y: CGFloat(side) / 2),
        size: CGFloat(side) * 0.82
    )
    guard let image = ctx.makeImage() else { fatalError("touch icon render failed") }
    write(image, to: "assets/apple-touch-icon.png")
}

// Centring reference, printed so the offsets above can be re-checked by eye if
// the wordmark ever changes.
print(
    "wordmark width at 108pt: "
        + String(format: "%.1f", width("Hasu", fontName: "Helvetica-Bold", size: 108))
)
