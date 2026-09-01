import UIKit
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // Register background processing task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: RefreshManager.backgroundTaskID,
            using: nil
        ) { task in
            RefreshManager.shared.handleBackgroundTask(task: task as! BGProcessingTask)
        }

        // Schedule first run on launch
        RefreshManager.shared.scheduleBackgroundTask()

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        RefreshManager.shared.scheduleBackgroundTask()
    }
}
