import AppKit

struct StatusBarIcon {
    private static let sheepEmoji = "\u{1F411}"
    private static let sheepFont = NSFont.systemFont(ofSize: 16)

    static func icon(for state: ShepherdState) -> NSImage {
        switch state {
        case .calm:
            return renderCalm()
        case .trajectory, .warm:
            return renderTinted(.systemOrange)
        case .low:
            return renderTinted(.systemRed)
        case .locked:
            return renderDead()
        }
    }

    /// Plain sheep — template mode lets macOS handle light/dark
    private static func renderCalm() -> NSImage {
        let attrs: [NSAttributedString.Key: Any] = [.font: sheepFont]
        let size = (sheepEmoji as NSString).size(withAttributes: attrs)
        let image = NSImage(size: size)
        image.lockFocus()

        let ctx = NSGraphicsContext.current!.cgContext
        ctx.saveGState()
        ctx.translateBy(x: size.width, y: 0)
        ctx.scaleBy(x: -1, y: 1)
        (sheepEmoji as NSString).draw(at: .zero, withAttributes: attrs)
        ctx.restoreGState()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    /// Sheep with color tint via sourceAtop blend
    private static func renderTinted(_ tint: NSColor) -> NSImage {
        let attrs: [NSAttributedString.Key: Any] = [.font: sheepFont]
        let size = (sheepEmoji as NSString).size(withAttributes: attrs)
        let image = NSImage(size: size)
        image.lockFocus()

        let ctx = NSGraphicsContext.current!.cgContext

        // Draw flipped sheep
        ctx.saveGState()
        ctx.translateBy(x: size.width, y: 0)
        ctx.scaleBy(x: -1, y: 1)
        (sheepEmoji as NSString).draw(at: .zero, withAttributes: attrs)
        ctx.restoreGState()

        // Tint overlay
        ctx.saveGState()
        ctx.setBlendMode(.sourceAtop)
        ctx.setFillColor(tint.withAlphaComponent(0.4).cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        ctx.restoreGState()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    /// Dead sheep — flipped vertically, faded
    private static func renderDead() -> NSImage {
        let attrs: [NSAttributedString.Key: Any] = [.font: sheepFont]
        let size = (sheepEmoji as NSString).size(withAttributes: attrs)
        let image = NSImage(size: size)
        image.lockFocus()

        let ctx = NSGraphicsContext.current!.cgContext

        // Flip horizontal (facing right) + vertical (upside down)
        ctx.saveGState()
        ctx.translateBy(x: size.width, y: size.height)
        ctx.scaleBy(x: -1, y: -1)
        ctx.setAlpha(0.12)
        (sheepEmoji as NSString).draw(at: .zero, withAttributes: attrs)
        ctx.restoreGState()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
