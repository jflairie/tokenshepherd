import AppKit

struct StatusBarIcon {
    private static let sheepEmoji: NSString = "\u{1F411}"
    private static let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 16)]
    private static let sheepSize = sheepEmoji.size(withAttributes: attrs)

    static func icon(for state: ShepherdState) -> NSImage {
        switch state {
        case .idle:              return renderIdle()
        case .calm:              return renderCalm()
        case .trajectory, .warm: return renderTinted(.systemOrange)
        case .low:               return renderTinted(.systemRed)
        case .locked:            return renderDead()
        }
    }

    private static func renderIdle() -> NSImage {
        renderSheep { ctx, size in
            ctx.translateBy(x: size.width, y: 0)
            ctx.scaleBy(x: -1, y: 1)
            ctx.setAlpha(0.35)
            sheepEmoji.draw(at: .zero, withAttributes: attrs)
        }
    }

    private static func renderCalm() -> NSImage {
        renderSheep { ctx, size in
            ctx.translateBy(x: size.width, y: 0)
            ctx.scaleBy(x: -1, y: 1)
            sheepEmoji.draw(at: .zero, withAttributes: attrs)
        }
    }

    private static func renderTinted(_ tint: NSColor) -> NSImage {
        renderSheep { ctx, size in
            ctx.translateBy(x: size.width, y: 0)
            ctx.scaleBy(x: -1, y: 1)
            sheepEmoji.draw(at: .zero, withAttributes: attrs)

            ctx.setBlendMode(.sourceAtop)
            ctx.setFillColor(tint.withAlphaComponent(0.6).cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private static func renderDead() -> NSImage {
        renderSheep { ctx, size in
            ctx.translateBy(x: size.width, y: size.height)
            ctx.scaleBy(x: -1, y: -1)
            ctx.setAlpha(0.5)
            sheepEmoji.draw(at: .zero, withAttributes: attrs)

            ctx.restoreGState()
            ctx.saveGState()

            let stroke: CGFloat = 2.0
            let inset: CGFloat = 3.0
            ctx.setStrokeColor(NSColor.systemRed.cgColor)
            ctx.setLineWidth(stroke)
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: inset, y: inset))
            ctx.addLine(to: CGPoint(x: size.width - inset, y: size.height - inset))
            ctx.move(to: CGPoint(x: size.width - inset, y: inset))
            ctx.addLine(to: CGPoint(x: inset, y: size.height - inset))
            ctx.strokePath()
        }
    }

    private static func renderSheep(_ draw: (CGContext, CGSize) -> Void) -> NSImage {
        let image = NSImage(size: sheepSize)
        image.lockFocus()
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.saveGState()
        draw(ctx, sheepSize)
        ctx.restoreGState()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
