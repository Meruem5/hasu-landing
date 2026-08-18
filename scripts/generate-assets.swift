#!/usr/bin/env swift
//
// Generates the two raster assets the pages reference:
//
//   assets/og-image.png         1200×630  social preview card
//   assets/apple-touch-icon.png  180×180  iOS home-screen bookmark
//   favicon.ico                 16/32/48  tab icon, and the file clients guess
//
// Raster rather than SVG because Open Graph consumers (iMessage, Slack, X,
// WhatsApp) will not render an SVG preview, and apple-touch-icon has never
// supported it. `assets/favicon.svg` remains the favicon modern browsers use;
// the .ico exists because a great many clients — older Safari, feed readers,
// link unfurlers, crawlers building a thumbnail — ask for /favicon.ico at the
// site root without reading the HTML at all, and until now that 404'd.
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

/// As above but with an alpha channel, for the favicon: the plate is a circle,
/// so the corners have to be transparent rather than white — white corners are
/// visible as a square patch on a dark tab bar.
func transparentContext(width: Int, height: Int) -> CGContext {
    guard
        let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
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

/// How much of the flower to draw.
///
/// `full` is the real drawing: two offset petal rings and a pale heart. Below
/// about 24px the inner ring lands inside the gaps of the outer one and the two
/// tones average into a single blur, so `outline` drops it and keeps a legible
/// six-petal silhouette instead. This is the reason a favicon is a multi-size
/// file rather than one image scaled down.
enum LotusDetail {
    case full
    case outline
}

func drawLotus(
    in ctx: CGContext, centre: CGPoint, size: CGFloat, detail: LotusDetail = .full
) {
    drawPetalRing(
        in: ctx, centre: centre, count: 6,
        radiusX: size * 0.113, radiusY: size * 0.204,
        distance: size * 0.240, angleOffset: 0, colour: tealDeep
    )
    if detail == .full {
        drawPetalRing(
            in: ctx, centre: centre, count: 6,
            radiusX: size * 0.088, radiusY: size * 0.138,
            distance: size * 0.146, angleOffset: 0.5, colour: tealMid
        )
    }
    // With the inner ring gone the heart is the only thing left marking the
    // centre, so it takes the mid tone — pale teal on white loses it entirely.
    let heartColour = detail == .full ? tealEdge : tealMid
    let heartRadius = size * (detail == .full ? 0.092 : 0.070)
    ctx.setFillColor(heartColour)
    ctx.fillEllipse(
        in: CGRect(
            x: centre.x - heartRadius, y: centre.y - heartRadius,
            width: heartRadius * 2, height: heartRadius * 2
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

/// Writes several images into one .ico. ImageIO does the container; the point of
/// passing more than one image is that the client picks the size it wants
/// instead of scaling a single bitmap and blurring it.
func writeICO(_ images: [CGImage], to relativePath: String) {
    let url = repoRoot.appending(path: relativePath)
    guard
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.ico.identifier as CFString, images.count, nil
        )
    else { fatalError("could not create \(url.path)") }
    for image in images { CGImageDestinationAddImage(destination, image, nil) }
    guard CGImageDestinationFinalize(destination) else {
        fatalError("could not write \(url.path)")
    }
    let sizes = images.map { "\($0.width)" }.joined(separator: "/")
    print("wrote \(relativePath) — \(sizes) px")
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

// ── favicon.ico ─────────────────────────────────────────────────────────────
//
// At the repository root, not in assets/, because the whole reason this file
// exists is the clients that request /favicon.ico without being told to.
//
// The flower sits on a pale teal disc rather than on nothing. A bare dark-teal
// silhouette is what assets/favicon.svg draws, and that page can invert itself
// for dark mode with a media query — an .ico cannot, and #0F6E56 on a dark tab
// bar is close to invisible. The disc keeps one appearance that works on both.

do {
    // 16 and 32 are the tab-bar sizes — 32 is what a 2× display uses to fill
    // those same 16 logical points, so both take the simplified drawing or the
    // icon would change character between a retina screen and an external one.
    // 48 is for bookmark bars and shortcuts, where the full flower fits.
    let plan: [(side: Int, detail: LotusDetail)] = [
        (16, .outline), (32, .outline), (48, .full),
    ]

    let images: [CGImage] = plan.map { side, detail in
        let ctx = transparentContext(width: side, height: side)
        let extent = CGFloat(side)
        let centre = CGPoint(x: extent / 2, y: extent / 2)
        ctx.setFillColor(tealSoft)
        ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: extent, height: extent))
        // 0.9 of the disc: the flower reaches close to the edge, since a
        // generous margin at 16px spends pixels that the drawing needs.
        drawLotus(in: ctx, centre: centre, size: extent * 0.9, detail: detail)
        guard let image = ctx.makeImage() else {
            fatalError("favicon render failed at \(side)px")
        }
        return image
    }

    writeICO(images, to: "favicon.ico")
}

// Centring reference, printed so the offsets above can be re-checked by eye if
// the wordmark ever changes.
print(
    "wordmark width at 108pt: "
        + String(format: "%.1f", width("Hasu", fontName: "Helvetica-Bold", size: 108))
)
