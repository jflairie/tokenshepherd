import SwiftUI

enum ShepherdState {
    case idle         // window expired — nothing to monitor
    case calm
    case trajectory   // projected ≥ 70%, util < 70%
    case warm         // util 70-89%
    case low          // util 90-99%
    case locked       // util ≥ 100%

    var severity: Int {
        switch self {
        case .idle:       return -1
        case .calm:       return 0
        case .trajectory: return 1
        case .warm:       return 2
        case .low:        return 3
        case .locked:     return 4
        }
    }

    var color: Color {
        switch self {
        case .idle, .calm:           return .primary
        case .trajectory, .warm:     return .orange
        case .low, .locked:          return .red
        }
    }

    var chartColor: Color {
        switch self {
        case .idle, .calm:           return .green
        case .trajectory, .warm:     return .orange
        case .low, .locked:          return .red
        }
    }

    static func from(
        window: QuotaWindow,
        pace: PaceInfo?,
        projectedAtReset: Double?
    ) -> ShepherdState {
        // Window expired — nothing to monitor
        if window.resetsAt.timeIntervalSinceNow <= 0 { return .idle }

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
