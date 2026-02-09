import AppKit

struct StatusBarIcon {
    struct Result {
        let image: NSImage
    }

    private static let sheepEmoji = "\u{1F411}"
    private static let sheepFont = NSFont.systemFont(ofSize: 16)
    private static let suffixFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)

    static func icon(for state: QuotaState, trajectoryWarning: Bool = false) -> Result {
        switch state {
        case .loading, .error:
            return Result(image: renderIcon(suffix: nil, color: nil, sheepTint: nil))

        case .loaded(let data):
            let binding = data.bindingWindow
            let util = binding.utilization

            if binding.isLocked {
                let countdown = binding.resetsInFormatted
                return Result(image: renderIcon(suffix: "\(countdown)", color: .systemRed, sheepTint: nil))
            }

            if util >= 0.9 {
                return Result(image: renderIcon(suffix: "\(Int(util * 100))%", color: .systemRed, sheepTint: nil))
            }

            if util >= 0.7 {
                return Result(image: renderIcon(suffix: "\(Int(util * 100))%", color: .systemOrange, sheepTint: nil))
            }

            if trajectoryWarning {
                return Result(image: renderIcon(suffix: nil, color: nil, sheepTint: .systemOrange))
            }

            return Result(image: renderIcon(suffix: nil, color: nil, sheepTint: nil))
        }
    }

    private static func renderIcon(suffix: String?, color: NSColor?, sheepTint: NSColor?) -> NSImage {
        let sheepAttrs: [NSAttributedString.Key: Any] = [.font: sheepFont]
        let sheepSize = (sheepEmoji as NSString).size(withAttributes: sheepAttrs)

        var suffixSize = NSSize.zero
        var suffixAttrs: [NSAttributedString.Key: Any] = [:]
        if let suffix, let color {
            suffixAttrs = [.font: suffixFont, .foregroundColor: color]
            suffixSize = (suffix as NSString).size(withAttributes: suffixAttrs)
        }

        let gap: CGFloat = -3
        let totalWidth = sheepSize.width + (suffix != nil ? gap + suffixSize.width : 0)
        let height = max(sheepSize.height, suffixSize.height)

        let image = NSImage(size: NSSize(width: totalWidth, height: height))
        image.lockFocus()

        // Draw flipped sheep
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.saveGState()
        ctx.translateBy(x: sheepSize.width, y: 0)
        ctx.scaleBy(x: -1, y: 1)
        (sheepEmoji as NSString).draw(
            at: CGPoint(x: 0, y: (height - sheepSize.height) / 2),
            withAttributes: sheepAttrs
        )
        ctx.restoreGState()

        // Tint sheep (trajectory warning — orange wash over the emoji)
        if let sheepTint {
            ctx.saveGState()
            ctx.setBlendMode(.sourceAtop)
            ctx.setFillColor(sheepTint.withAlphaComponent(0.4).cgColor)
            ctx.fill(CGRect(x: 0, y: (height - sheepSize.height) / 2, width: sheepSize.width, height: sheepSize.height))
            ctx.restoreGState()
        }

        // Draw suffix
        if let suffix {
            (suffix as NSString).draw(
                at: CGPoint(x: sheepSize.width + gap, y: (height - suffixSize.height) / 2),
                withAttributes: suffixAttrs
            )
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
