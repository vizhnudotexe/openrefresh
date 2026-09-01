import UIKit
import BackgroundTasks

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
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

    // MARK: UISceneSession Lifecycle
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
