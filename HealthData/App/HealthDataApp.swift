import SwiftUI
import HealthKit
import WatchConnectivity
import BackgroundTasks

@main
struct HealthDataApp: App {
    init() {
        // 앱 시작 시 백그라운드 태스크 등록
        BackgroundTaskManager.shared.registerBackgroundTask()
    }
    
    var body: some Scene {
        WindowGroup {
            ParticipationView()
        }
    }
}