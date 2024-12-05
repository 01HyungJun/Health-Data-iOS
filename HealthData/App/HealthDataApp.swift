import SwiftUI
import HealthKit
import WatchConnectivity

@main
struct HealthDataApp: App {    
    var body: some Scene {
        WindowGroup {
            ParticipationView()
        }
    }
}