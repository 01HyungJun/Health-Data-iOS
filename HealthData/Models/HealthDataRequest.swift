import Foundation

struct HealthDataRequest: Codable {
    let projectId: Int
    let healthData: HealthData
    
    enum CodingKeys: String, CodingKey {
        case projectId
        case healthData = "data"
    }
} 