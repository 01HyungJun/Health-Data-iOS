import Foundation

struct BatchHealthData: Codable {
    let userInfo: UserInfo
    let measurements: [TimestampedMeasurement]
}

struct TimestampedMeasurement: Codable {
    let timestamp: Date
    let stepCount: Double?
    let heartRate: Double?
    let bloodPressureSystolic: Double?
    let bloodPressureDiastolic: Double?
    let oxygenSaturation: Double?
    let bodyTemperature: Double?
    let respiratoryRate: Double?
    let height: Double?
    let weight: Double?
    let runningSpeed: Double?
    let activeEnergy: Double?
    let basalEnergy: Double?
    let latitude: Double?
    let longitude: Double?
} 