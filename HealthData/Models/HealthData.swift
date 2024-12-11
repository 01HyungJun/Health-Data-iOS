import Foundation
import HealthKit
import CoreLocation

struct UserInfo: Codable {
    let projectId: Int
    let email: String
    let provider: String
    let bloodType: String?
    let biologicalSex: String?
    let birthDate: String?
}

struct HealthData: Codable {
    let userInfo: UserInfo
    let measurements: Measurements
}

struct Measurements: Codable {
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

extension HealthData {
    static func from(healthKitData: [HKSample], userInfo: UserInfo) -> HealthData {
        let measurements = Measurements(
            stepCount: getValue(from: healthKitData, for: .stepCount),
            heartRate: getValue(from: healthKitData, for: .heartRate),
            bloodPressureSystolic: getValue(from: healthKitData, for: .bloodPressureSystolic),
            bloodPressureDiastolic: getValue(from: healthKitData, for: .bloodPressureDiastolic),
            oxygenSaturation: getValue(from: healthKitData, for: .oxygenSaturation),
            bodyTemperature: getValue(from: healthKitData, for: .bodyTemperature),
            respiratoryRate: getValue(from: healthKitData, for: .respiratoryRate),
            height: getValue(from: healthKitData, for: .height),
            weight: getValue(from: healthKitData, for: .bodyMass),
            runningSpeed: getValue(from: healthKitData, for: .runningSpeed),
            activeEnergy: getValue(from: healthKitData, for: .activeEnergyBurned),
            basalEnergy: getValue(from: healthKitData, for: .basalEnergyBurned),
            latitude: nil,
            longitude: nil
        )
        
        return HealthData(
            userInfo: userInfo,
            measurements: measurements
        )
    }
    
    private static func getValue(from samples: [HKSample], for identifier: HKQuantityTypeIdentifier) -> Double? {
        guard let sample = samples.first(where: { $0.sampleType.identifier == identifier.rawValue }) as? HKQuantitySample else {
            return nil
        }
        return sample.quantity.doubleValue(for: getUnit(for: sample.quantityType))
    }
    
    private static func getUnit(for quantityType: HKQuantityType) -> HKUnit {
        switch quantityType.identifier {
        case HKQuantityTypeIdentifier.stepCount.rawValue:
            return .count()
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            return HKUnit.count().unitDivided(by: .minute())
        case HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue,
             HKQuantityTypeIdentifier.bloodPressureDiastolic.rawValue:
            return .millimeterOfMercury()
        case HKQuantityTypeIdentifier.oxygenSaturation.rawValue:
            return .percent()
        case HKQuantityTypeIdentifier.bodyTemperature.rawValue:
            return .degreeCelsius()
        case HKQuantityTypeIdentifier.respiratoryRate.rawValue:
            return HKUnit.count().unitDivided(by: .minute())
        case HKQuantityTypeIdentifier.height.rawValue:
            return .meterUnit(with: .centi)
        case HKQuantityTypeIdentifier.bodyMass.rawValue:
            return .gramUnit(with: .kilo)
        case HKQuantityTypeIdentifier.runningSpeed.rawValue:
            return HKUnit.meter().unitDivided(by: .second())
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue,
             HKQuantityTypeIdentifier.basalEnergyBurned.rawValue:
            return .kilocalorie()
        default:
            return .count()
        }
    }
}