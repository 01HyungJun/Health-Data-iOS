import UIKit

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var isRunning = false
    private var nextCollectionWorkItem: DispatchWorkItem?
    
    private init() {
        // 앱이 백그라운드로 전환될 때 알림 받기
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    func startBackgroundTaskWithDelay() {
        print("\n🚀 백그라운드 작업 시작: \(Date())")
        isRunning = true
        
        // 1분 후부터 시작
        scheduleNextCollection(afterDelay: 60)
        print("⏰ 1분 후 첫 실행 예정: \(Date(timeIntervalSinceNow: 60))")
    }
    
    private func scheduleNextCollection(afterDelay: TimeInterval = 60) {
        guard isRunning else { return }
        
        // 이전 예약된 작업 취소
        nextCollectionWorkItem?.cancel()
        
        // 새로운 작업 생성
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // 새로운 백그라운드 작업 시작
            self.backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                print("⚠️ 백그라운드 작업 시간 만료: \(Date())")
                self?.endBackgroundTask()
            }
            
            // 데이터 수집 및 전송
            Task {
                await self.startNewDataCollection()
                self.endBackgroundTask()
                
                // 다음 수집 예약
                self.scheduleNextCollection()
            }
        }
        
        nextCollectionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + afterDelay, execute: workItem)
    }
    
    @objc private func applicationDidEnterBackground() {
        print("📱 앱이 백그라운드로 전환됨: \(Date())")
        // 백그라운드 전환 시 추가 작업 시작하지 않음
    }
    
    private func startNewDataCollection() async {
        print("\n🔄 새로운 데이터 수집 시작: \(Date())")
        
        do {
            let projectId = UserDefaults.standard.integer(forKey: "lastProjectId")
            guard projectId != 0 else {
                print("❌ 프로젝트 ID가 없음")
                return
            }
            
            let startTime = Date()
            print("📱 데이터 수집 시작: \(startTime)")
            
            // 헬스 데이터 가져오기
            let healthData = try await HealthKitManager.shared.fetchAllHealthData(projectId: projectId)
            
            // JSON 로깅
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let jsonData = try? encoder.encode(healthData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print("\n📤 전송할 데이터:")
                print(jsonString)
            }
            
            // 서버로 전송
            try await APIService.shared.registerHealthData(healthData, projectId: projectId)
            
            let endTime = Date()
            print("✅ 데이터 전송 성공: \(endTime)")
            print("⏱ 전송 소요 시간: \(endTime.timeIntervalSince(startTime))초")
            
        } catch {
            print("❌ 데이터 전송 실패: \(error.localizedDescription)")
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    deinit {
        nextCollectionWorkItem?.cancel()
        NotificationCenter.default.removeObserver(self)
        endBackgroundTask()
    }
}
