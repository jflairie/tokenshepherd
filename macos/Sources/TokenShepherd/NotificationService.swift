import Foundation
import UserNotifications

enum NotificationThreshold: Int, Comparable {
    case paceWarning = 1
    case runningLow = 2
    case locked = 3

    static func < (lhs: NotificationThreshold, rhs: NotificationThreshold) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private struct WindowNotificationState {
        var highestThreshold: NotificationThreshold?
        var resetsAt: Date
        var wasLocked: Bool
    }

    private var fiveHourState: WindowNotificationState?
    private var sevenDayState: WindowNotificationState?

    private var center: UNUserNotificationCenter?

    func requestPermission() {
        // UNUserNotificationCenter requires a proper app bundle.
        // When running via `swift run` there's no bundle, so catch the crash.
        guard Bundle.main.bundleIdentifier != nil else {
            NSLog("[TokenShepherd] No bundle identifier — notifications disabled (use `make run` for notifications)")
            return
        }
        let c = UNUserNotificationCenter.current()
        c.delegate = self
        center = c
        c.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                NSLog("[TokenShepherd] Notification permission error: \(error.localizedDescription)")
            } else {
                NSLog("[TokenShepherd] Notification permission \(granted ? "granted" : "denied")")
            }
        }
    }

    func evaluate(state: QuotaState) {
        guard case .loaded(let data) = state else { return }

        let fiveHourPace = PaceCalculator.pace(for: data.fiveHour, windowDuration: PaceCalculator.fiveHourDuration)
        let sevenDayPace = PaceCalculator.pace(for: data.sevenDay, windowDuration: PaceCalculator.sevenDayDuration)

        evaluateWindow(
            window: data.fiveHour,
            pace: fiveHourPace,
            label: "5-hour",
            id: "five-hour",
            state: &fiveHourState
        )
        evaluateWindow(
            window: data.sevenDay,
            pace: sevenDayPace,
            label: "7-day",
            id: "seven-day",
            state: &sevenDayState
        )
    }

    private func evaluateWindow(
        window: QuotaWindow,
        pace: PaceInfo?,
        label: String,
        id: String,
        state: inout WindowNotificationState?
    ) {
        // Reset tracking when window cycle changes
        if let existing = state, !datesMatchWithinTolerance(existing.resetsAt, window.resetsAt) {
            // Check for restored notification before resetting
            if existing.wasLocked && !window.isLocked {
                send(
                    id: "\(id)-restored",
                    title: "TokenShepherd",
                    body: "Quota restored."
                )
            }
            state = nil
        }

        if state == nil {
            state = WindowNotificationState(
                highestThreshold: nil,
                resetsAt: window.resetsAt,
                wasLocked: window.isLocked
            )
        }

        // Track locked state for restored detection
        state?.wasLocked = window.isLocked

        // Determine current threshold
        let threshold: NotificationThreshold?
        if window.isLocked {
            threshold = .locked
        } else if window.utilization >= 0.9 {
            threshold = .runningLow
        } else if let pace, pace.showWarning, window.utilization > 0.5 {
            threshold = .paceWarning
        } else {
            threshold = nil
        }

        guard let threshold else { return }

        // Only notify if this is a new/higher threshold in this cycle
        if let highest = state?.highestThreshold, threshold <= highest {
            return
        }

        state?.highestThreshold = threshold

        switch threshold {
        case .paceWarning:
            guard let pace else { return }
            send(
                id: "\(id)-pace",
                title: "TokenShepherd",
                body: "At current pace, \(label) limit around \(pace.limitAtFormatted). Resets in \(window.resetsInFormatted)."
            )
        case .runningLow:
            send(
                id: "\(id)-low",
                title: "TokenShepherd",
                body: "\(label.capitalized) window at 90%. Resets in \(window.resetsInFormatted)."
            )
        case .locked:
            send(
                id: "\(id)-locked",
                title: "TokenShepherd",
                body: "Limit reached. Back at \(formatTime(window.resetsAt))."
            )
        }
    }

    private func send(id: String, title: String, body: String) {
        guard let center else {
            NSLog("[TokenShepherd] Would notify: \(body)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error {
                NSLog("[TokenShepherd] Notification error: \(error.localizedDescription)")
            } else {
                NSLog("[TokenShepherd] Sent notification: \(body)")
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: Date()) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: Date())!) {
            formatter.dateFormat = "'tomorrow' h:mm a"
        } else {
            formatter.dateFormat = "EEE h:mm a"
        }
        return formatter.string(from: date)
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
