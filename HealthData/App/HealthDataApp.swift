import SwiftUI
import HealthKit
import WatchConnectivity

@main
struct HealthDataApp: App {
    init() {
        WatchSessionManager.shared.startSession()
    }
    
    var body: some Scene {
        WindowGroup {
            ParticipationView()
        }
    }
}

class WatchSessionManager: NSObject, WCSessionDelegate {
    static let shared = WatchSessionManager()
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func startSession() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let healthData = message["healthData"] as? [[String: String]] {
            // 수신한 데이터 처리 로직 추가
            for data in healthData {
                print("Received data: \(data)")
            }
        }
    }
    
    // WCSessionDelegate methods
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}
}