import Foundation

struct HealthDataRequest: Codable {
    let userInfo: UserInfo
    let measurements: Measurements
} 