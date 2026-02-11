import AppKit
import SwiftUI

enum ShepherdState {
    case calm
    case trajectory   // projected ≥ 70%, util < 70%
    case warm         // util 70-89%
    case low          // util 90-99%
    case locked       // util ≥ 100%

    var color: Color {
        switch self {
        case .calm:                  return .primary
        case .trajectory, .warm:     return .orange
        case .low, .locked:          return .red
        }
    }

    var nsColor: NSColor? {
        switch self {
        case .calm:                  return nil
        case .trajectory, .warm:     return .systemOrange
        case .low, .locked:          return .systemRed
        }
    }

    var isWarning: Bool {
        switch self {
        case .calm: return false
        default: return true
        }
    }

    var chartColor: Color {
        switch self {
        case .calm:                  return .green
        case .trajectory, .warm:     return .orange
        case .low, .locked:          return .red
        }
    }

    static func from(
        window: QuotaWindow,
        pace: PaceInfo?,
        projectedAtReset: Double?,
        trend: TrendInfo?
    ) -> ShepherdState {
        // Window expired — data is stale, treat as calm
        if window.resetsAt.timeIntervalSinceNow <= 0 { return .calm }

        if window.isLocked { return .locked }

        let util = window.utilization
        if util >= 0.9 { return .low }

        // Projection into red zone overrides current-util severity
        if let projected = projectedAtReset, projected >= 0.9 { return .low }

        if util >= 0.7 { return .warm }

        // Below 70% — check trajectory
        let paceWarning = pace?.showWarning ?? false
        if paceWarning { return .trajectory }
        if let projected = projectedAtReset, projected >= 0.7 { return .trajectory }

        return .calm
    }
}
