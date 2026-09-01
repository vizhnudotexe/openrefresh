import SwiftUI
import UserNotifications
import BackgroundTasks

struct ContentView: View {

    @StateObject private var vm = ContentViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(hue: 0.62, saturation: 0.85, brightness: 0.18),
                             Color(hue: 0.60, saturation: 0.90, brightness: 0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // MARK: - Status Card
                        StatusCard(vm: vm)

                        // MARK: - Settings Card
                        SettingsCard(vm: vm)

                        // MARK: - Manual Trigger
                        Button {
                            vm.triggerNow()
                        } label: {
                            HStack {
                                if vm.isTriggering {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                }
                                Text(vm.isTriggering ? "Triggering…" : "Trigger Refresh Now")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color(hue: 0.55, saturation: 0.85, brightness: 0.75),
                                             Color(hue: 0.58, saturation: 0.90, brightness: 0.65)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .shadow(color: .cyan.opacity(0.3), radius: 8, y: 4)
                        }
                        .disabled(vm.isTriggering)
                        .padding(.horizontal)
                        .animation(.easeInOut, value: vm.isTriggering)

                        // MARK: - Log Card
                        LogCard(vm: vm)

                        // MARK: - Help Card
                        HelpCard()

                    }
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("AutoRefresh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .onAppear { vm.onAppear() }
    }
}

// MARK: - ViewModel

final class ContentViewModel: ObservableObject {

    @Published var lastRefreshText: String = "Never"
    @Published var nextStatus: String      = "Unknown"
    @Published var needsRefresh: Bool      = false
    @Published var isTriggering: Bool      = false
    @Published var logs: [String]          = []
    @Published var triggerResult: String?  = nil

    @Published var shortcutName: String    = RefreshManager.shared.shortcutName
    @Published var thresholdDays: Int      = RefreshManager.shared.refreshThresholdDays
    @Published var chargingMins: Int       = RefreshManager.shared.chargingMinThreshold

    private var logObserver: NSObjectProtocol?

    func onAppear() {
        requestNotificationPermission()
        refresh()
        logObserver = NotificationCenter.default.addObserver(
            forName: .arLogUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logs = RefreshManager.shared.getLogs()
        }
    }

    deinit {
        if let obs = logObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    func refresh() {
        let rm = RefreshManager.shared
        if let date = rm.lastRefreshDate {
            let fmt        = RelativeDateTimeFormatter()
            fmt.unitsStyle = .full
            lastRefreshText = fmt.localizedString(for: date, relativeTo: Date())
        } else {
            lastRefreshText = "Never"
        }
        needsRefresh = rm.needsRefresh
        if let days = rm.daysSinceLastRefresh {
            nextStatus = days >= rm.refreshThresholdDays
                ? "Overdue — will refresh on next charge"
                : "OK — \(rm.refreshThresholdDays - days) day(s) left"
        } else {
            nextStatus = "First run pending"
        }
        logs = rm.getLogs()
    }

    func saveSettings() {
        RefreshManager.shared.shortcutName        = shortcutName
        RefreshManager.shared.refreshThresholdDays = thresholdDays
        RefreshManager.shared.chargingMinThreshold = chargingMins
        RefreshManager.shared.scheduleBackgroundTask()
        refresh()
    }

    func triggerNow() {
        isTriggering = true
        triggerResult = nil
        RefreshManager.shared.triggerNow { [weak self] success in
            DispatchQueue.main.async {
                self?.isTriggering    = false
                self?.triggerResult   = success ? "✓ Triggered" : "✗ Failed"
                self?.refresh()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self?.triggerResult = nil
                }
            }
        }
    }

    private func requestNotificationPermission() {
        // Register refresh notification category with action
        let action   = UNNotificationAction(
            identifier: "REFRESH_NOW",
            title: "Refresh Now",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: "SIDESTORE_REFRESH",
            actions: [action],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}

// MARK: - Sub-views

struct StatusCard: View {
    @ObservedObject var vm: ContentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Status", systemImage: "circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundColor(.cyan.opacity(0.8))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Refresh")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Text(vm.lastRefreshText)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                Spacer()
                Circle()
                    .fill(vm.needsRefresh ? Color.orange : Color.green)
                    .frame(width: 12, height: 12)
                    .shadow(color: vm.needsRefresh ? .orange : .green, radius: 4)
            }

            Divider().background(Color.white.opacity(0.15))

            Text(vm.nextStatus)
                .font(.subheadline)
                .foregroundColor(vm.needsRefresh ? .orange : .green)

            if let result = vm.triggerResult {
                Text(result)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(result.hasPrefix("✓") ? .green : .red)
                    .transition(.opacity)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
        .onTapGesture { vm.refresh() }
    }
}

struct SettingsCard: View {
    @ObservedObject var vm: ContentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Configuration", systemImage: "gear")
                .font(.caption.weight(.semibold))
                .foregroundColor(.cyan.opacity(0.8))

            // Shortcut name
            VStack(alignment: .leading, spacing: 4) {
                Text("Shortcut Name")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                TextField("e.g. SideStore Refresh", text: $vm.shortcutName)
                    .textFieldStyle(.roundedBorder)
                    .colorScheme(.dark)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            // Threshold days stepper
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Refresh Threshold")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(vm.thresholdDays) day\(vm.thresholdDays == 1 ? "" : "s")")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                Spacer()
                Stepper("", value: $vm.thresholdDays, in: 1...6)
                    .labelsHidden()
            }

            // Charging minutes stepper
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Min. Charging Time")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(vm.chargingMins) min")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                Spacer()
                Stepper("", value: $vm.chargingMins, in: 5...60, step: 5)
                    .labelsHidden()
            }

            Button("Save & Reschedule") {
                vm.saveSettings()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.cyan.opacity(0.25))
            .foregroundColor(.cyan)
            .cornerRadius(10)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

struct LogCard: View {
    @ObservedObject var vm: ContentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Activity Log", systemImage: "doc.text")
                .font(.caption.weight(.semibold))
                .foregroundColor(.cyan.opacity(0.8))

            if vm.logs.isEmpty {
                Text("No activity yet.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(vm.logs.reversed(), id: \.self) { line in
                            Text(line)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

struct HelpCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Setup Checklist", systemImage: "checkmark.shield")
                .font(.caption.weight(.semibold))
                .foregroundColor(.cyan.opacity(0.8))

            ForEach(helpItems, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(.cyan)
                    Text(item)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    let helpItems = [
        "Settings > General > Background App Refresh → ON for AutoRefresh",
        "Create a Shortcut named exactly as configured above that: (1) connects StosVPN, (2) waits 30s, (3) runs SideStore 'Refresh All Apps', (4) disconnects VPN",
        "Allow notifications when prompted (fallback path when background is blocked)",
        "Keep AutoRefresh installed — SideStore will refresh it along with your other apps",
        "Plug in to charge → AutoRefresh fires after the configured minimum charging time",
        "If shortcut open is blocked in background, tap the notification to trigger manually",
    ]
}

#Preview {
    ContentView()
}
