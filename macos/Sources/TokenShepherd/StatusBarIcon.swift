import AppKit

struct StatusBarIcon {
    private static let sheepEmoji: NSString = "\u{1F411}"
    private static let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 16)]
    private static let sheepSize = sheepEmoji.size(withAttributes: attrs)

    static func icon(for state: ShepherdState, blind: Bool = false) -> NSImage {
        // Blind = no trustworthy current reading (stale or cold). Preserve the quota
        // color (a stale-red sheep stays red — never mute the loudest alarm) and flag
        // "not live" with a corner status dot. Brightness alone is not discriminable
        // from the idle/dead sheep at 16pt, so we separate on shape, not alpha.
        if blind { return renderBlind(tint: tint(for: state)) }
        switch state {
        case .idle:              return renderIdle()
        case .calm:              return renderCalm()
        case .trajectory, .warm: return renderTinted(.systemOrange)
        case .low:               return renderTinted(.systemRed)
        case .locked:            return renderDead()
        }
    }

    /// Quota-severity fill for the blind sheep; nil = no tint (calm/idle base).
    private static func tint(for state: ShepherdState) -> NSColor? {
        switch state {
        case .idle, .calm:       return nil
        case .trajectory, .warm: return .systemOrange
        case .low, .locked:      return .systemRed
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

    private static func renderBlind(tint: NSColor?) -> NSImage {
        renderSheep { ctx, size in
            // Upright sheep (same orientation as calm), quota color preserved.
            ctx.saveGState()
            ctx.translateBy(x: size.width, y: 0)
            ctx.scaleBy(x: -1, y: 1)
            sheepEmoji.draw(at: .zero, withAttributes: attrs)
            if let tint {
                ctx.setBlendMode(.sourceAtop)
                ctx.setFillColor(tint.withAlphaComponent(0.6).cgColor)
                ctx.fill(CGRect(origin: .zero, size: size))
            }
            ctx.restoreGState()

            // "Not live" status dot, top-right, in screen space. Two-tone (dark core +
            // light rim) so it reads against a light or dark menu bar and against the
            // sheep's own white body. A dot, not a stroke — X-vs-anything is unreadable
            // at 16pt and the X already means "locked/dead".
            let r = max(size.height * 0.15, 2.5)
            let cx = size.width - r - 0.5
            let cy = size.height - r - 0.5
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.95).cgColor)
            ctx.fillEllipse(in: CGRect(x: cx - r - 1, y: cy - r - 1, width: 2 * (r + 1), height: 2 * (r + 1)))
            ctx.setFillColor(NSColor(white: 0.25, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
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
