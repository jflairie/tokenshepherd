import AppKit

struct StatusBarIcon {
    struct Result {
        let attributedTitle: NSAttributedString
    }

    static func icon(for state: QuotaState) -> Result {
        switch state {
        case .loading, .error:
            return Result(attributedTitle: NSAttributedString(string: "\u{1F411}"))

        case .loaded(let data):
            let binding = data.bindingWindow
            let util = binding.utilization

            if binding.isLocked {
                // Show countdown to reset
                let countdown = binding.resetsInFormatted
                return styled(emoji: "\u{1F411}", suffix: " \(countdown)", color: .systemRed)
            }

            if util >= 0.9 {
                return styled(emoji: "\u{1F411}", suffix: " \(Int(util * 100))%", color: .systemRed)
            }

            if util >= 0.7 {
                return styled(emoji: "\u{1F411}", suffix: " \(Int(util * 100))%", color: .systemOrange)
            }

            // Healthy — just the sheep
            return Result(attributedTitle: NSAttributedString(string: "\u{1F411}"))
        }
    }

    private static func styled(emoji: String, suffix: String, color: NSColor) -> Result {
        let result = NSMutableAttributedString(string: emoji)
        let coloredPart = NSAttributedString(
            string: suffix,
            attributes: [
                .foregroundColor: color,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            ]
        )
        result.append(coloredPart)
        return Result(attributedTitle: result)
    }
}
