//
//  ContentView.swift
//  HealthDataWatch Watch App
//
//  Created by 박재형 on 12/2/24.
//

import SwiftUI
import HealthKit
import WatchConnectivity

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager.shared
    
    var body: some View {
        VStack {
            Button("Fetch Health Data") {
                Task {
                    do {
                        try await healthKitManager.requestAuthorization()
                        let samples = try await healthKitManager.fetchAllHealthData()
                        sendDataToiPhone(samples: samples)
                    } catch {
                        print("Error fetching health data: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func sendDataToiPhone(samples: [HKSample]) {
        if WCSession.default.isReachable {
            let data = samples.map { sample in
                // 데이터 변환 로직 추가
                return ["identifier": sample.sampleType.identifier, "value": sample.description]
            }
            WCSession.default.sendMessage(["healthData": data], replyHandler: nil) { error in
                print("Error sending data: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    ContentView()
}
