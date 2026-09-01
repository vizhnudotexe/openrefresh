import Foundation
import BackgroundTasks
import Network

// MARK: - RefreshManager
// Core engine: decides when to refresh and drives SideStore via Shortcuts URL scheme.
// Approach:
//   1. BGProcessingTask fires when charging + network available (system decides exact moment)
//   2. On fire: check if last SideStore refresh was >= 3 days ago
//   3. If yes: open the "SideStore Refresh" shortcut via shortcuts:// URL scheme
//   4. Store last-refresh timestamp after triggering
//   5. Re-schedule for next cycle

final class RefreshManager {

    static let shared = RefreshManager()
    private init() {}

    // MARK: - Constants
    static let backgroundTaskID = "com.autorefresh.sidestore.process"

    // UserDefaults keys
    private let kLastRefreshDate   = "ar_last_refresh_date"
    private let kShortcutName      = "ar_shortcut_name"
    private let kRefreshThresholdDays = "ar_refresh_threshold_days"
    private let kChargingMinThresh  = "ar_charging_min_threshold"

    // MARK: - User-configurable settings (editable via ContentView)
    var shortcutName: String {
        get { UserDefaults.standard.string(forKey: kShortcutName) ?? "SideStore Refresh" }
        set { UserDefaults.standard.set(newValue, forKey: kShortcutName) }
    }

    var refreshThresholdDays: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: kRefreshThresholdDays)
            return v == 0 ? 3 : v
        }
        set { UserDefaults.standard.set(newValue, forKey: kRefreshThresholdDays) }
    }

    /// Minutes of charge required before we consider triggering
    var chargingMinThreshold: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: kChargingMinThresh)
            return v == 0 ? 15 : v
        }
        set { UserDefaults.standard.set(newValue, forKey: kChargingMinThresh) }
    }

    // MARK: - State

    var lastRefreshDate: Date? {
        get { UserDefaults.standard.object(forKey: kLastRefreshDate) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: kLastRefreshDate) }
    }

    var daysSinceLastRefresh: Int? {
        guard let last = lastRefreshDate else { return nil }
        let diff = Calendar.current.dateComponents([.day], from: last, to: Date())
        return diff.day
    }

    var needsRefresh: Bool {
        guard let days = daysSinceLastRefresh else {
            // Never refreshed — need to run
            return true
        }
        return days >= refreshThresholdDays
    }

    // MARK: - Schedule BGProcessingTask

    func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: RefreshManager.backgroundTaskID)
        // Fire only when on external power and network available
        request.requiresExternalPower = true
        request.requiresNetworkConnectivity = true
        // Earliest time: respect the charging threshold (minimum minutes plugged in)
        // We can't truly detect "plugged in for X minutes" in BGTask, but
        // setting earliestBeginDate to a future point ensures the device has
        // had time to stabilize on the charger.
        request.earliestBeginDate = Date(timeIntervalSinceNow: Double(chargingMinThreshold) * 60.0)

        do {
            try BGTaskScheduler.shared.submit(request)
            log("BGProcessingTask scheduled. Earliest: \(chargingMinThreshold) min from now.")
        } catch let err as BGTaskScheduler.Error {
            switch err.code {
            case .notPermitted:
                log("ERROR: Background processing not permitted. Enable in Settings > General > Background App Refresh.")
            case .tooManyPendingTaskRequests:
                // Already queued — fine
                log("Task already queued.")
            case .unavailable:
                log("BGTaskScheduler unavailable on this device/config.")
            @unknown default:
                log("BGTaskScheduler error: \(err.localizedDescription)")
            }
        } catch {
            log("Unexpected error scheduling task: \(error)")
        }
    }

    // MARK: - Handle BGProcessingTask

    func handleBackgroundTask(task: BGProcessingTask) {
        log("BGProcessingTask fired.")

        // Reschedule immediately so the cycle continues
        scheduleBackgroundTask()

        task.expirationHandler = {
            self.log("Task expired before completion.")
            task.setTaskCompleted(success: false)
        }

        // Step 1: Check if refresh needed
        guard needsRefresh else {
            log("Last refresh was \(daysSinceLastRefresh ?? 0) days ago. Threshold not met. Skipping.")
            task.setTaskCompleted(success: true)
            return
        }

        // Step 2: Verify network (belt-and-suspenders, BGTask already requires connectivity)
        checkNetworkAndRefresh { [weak self] success in
            guard let self = self else { return }
            if success {
                self.log("Refresh triggered successfully.")
                self.lastRefreshDate = Date()
            } else {
                self.log("Refresh trigger failed.")
            }
            task.setTaskCompleted(success: success)
        }
    }

    // MARK: - Network check + trigger

    private func checkNetworkAndRefresh(completion: @escaping (Bool) -> Void) {
        let monitor = NWPathMonitor()
        let queue   = DispatchQueue(label: "com.autorefresh.netcheck")

        monitor.pathUpdateHandler = { [weak self] path in
            monitor.cancel()
            guard let self = self else { return }

            if path.status == .satisfied {
                self.log("Network available. Triggering SideStore refresh shortcut.")
                self.triggerSideStoreRefresh(completion: completion)
            } else {
                self.log("No network. Skipping.")
                completion(false)
            }
        }
        monitor.start(queue: queue)

        // Timeout: if no path event in 10s, bail
        queue.asyncAfter(deadline: .now() + 10) {
            monitor.cancel()
        }
    }

    // MARK: - Trigger SideStore via Shortcuts URL scheme
    //
    // Strategy (tried in order):
    //   A) shortcuts://run-shortcut?name=<shortcut_name>
    //      → opens Shortcuts app and runs the named shortcut
    //      → Works in foreground; in background iOS may block openURL
    //
    //   B) If A is blocked: post a local notification so the user sees it
    //      and taps it, which brings app to foreground then triggers A.
    //
    // Note: In a BGProcessingTask, UIApplication.shared.open() is not
    // available. We must use a notification to wake the user or rely on
    // the system running SideStore's own AppIntent via a different path.
    // The notification approach is the most reliable no-jailbreak path.

    func triggerSideStoreRefresh(completion: @escaping (Bool) -> Void) {
        // Try direct open first (works if app is active/recently foregrounded)
        let encoded = shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? shortcutName
        let urlStr  = "shortcuts://run-shortcut?name=\(encoded)"

        DispatchQueue.main.async {
            if let url = URL(string: urlStr),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { opened in
                    if opened {
                        self.log("Opened Shortcuts URL: \(urlStr)")
                        completion(true)
                    } else {
                        self.log("openURL returned false. Posting notification fallback.")
                        self.postRefreshNotification()
                        // Count as partial success — notification will drive user
                        completion(true)
                    }
                }
            } else {
                self.log("Cannot open Shortcuts URL. Posting notification.")
                self.postRefreshNotification()
                completion(true)
            }
        }
    }

    // MARK: - Notification fallback

    func postRefreshNotification() {
        let content         = UNMutableNotificationContent()
        content.title       = "SideStore Refresh Due"
        content.body        = "Tap to auto-refresh your sideloaded apps now."
        content.sound       = .default
        content.categoryIdentifier = "SIDESTORE_REFRESH"

        let request = UNNotificationRequest(
            identifier: "ar_refresh_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil   // deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.log("Notification error: \(error)")
            }
        }
    }

    // MARK: - Manual trigger (called from UI)

    func triggerNow(completion: @escaping (Bool) -> Void) {
        log("Manual trigger requested.")
        checkNetworkAndRefresh { success in
            if success {
                self.lastRefreshDate = Date()
            }
            completion(success)
        }
    }

    // MARK: - Logging

    private var logBuffer: [String] = []

    func log(_ msg: String) {
        let ts  = ISO8601DateFormatter().string(from: Date())
        let line = "[\(ts)] \(msg)"
        print(line)
        DispatchQueue.main.async {
            self.logBuffer.append(line)
            if self.logBuffer.count > 200 {
                self.logBuffer.removeFirst()
            }
            NotificationCenter.default.post(name: .arLogUpdated, object: nil)
        }
    }

    func getLogs() -> [String] { logBuffer }
}

extension Notification.Name {
    static let arLogUpdated = Notification.Name("com.autorefresh.logUpdated")
}
