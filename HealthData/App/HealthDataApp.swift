import SwiftUI
import HealthKit
import WatchConnectivity
import BackgroundTasks

@main
struct HealthDataApp: App {
    init() {
        // 백그라운드 태스크 등록
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.jaehyoung.healthdata.refresh",
            using: nil
        ) { task in
            // 백그라운드 작업 처리
            if let task = task as? BGAppRefreshTask {
                BackgroundTaskManager.shared.handleAppRefresh(task: task)
            }
        }
        
        // 위치 업데이트 시작
        LocationManager.shared.startUpdatingLocation()
    }
    
    var body: some Scene {
        WindowGroup {
            ParticipationView()
        }
    }
}