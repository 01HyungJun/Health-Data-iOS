import Foundation
import HealthKit

struct HealthData: Codable {
    let userId: String
    let provider: HealthProvider
    let measurements: [HealthMeasurement]
    let timestamp: Date
    
    enum HealthProvider: String, Codable {
        case samsung
        case apple
        case google
    }
}

struct HealthMeasurement: Codable {
    let type: MeasurementType
    let value: Double
    let unit: String
    let date: Date
    
    enum MeasurementType: String, Codable {
        case stepCount
        case heartRate
        case bloodPressure
        case oxygenSaturation
        case bodyTemperature
        case respiratoryRate
        case height
        case weight
        case sleepAnalysis
        case runningSpeed
        case activeEnergy
        case basalEnergy
    }
}

extension HealthData {
    static func from(healthKitData: [HKSample]) -> HealthData {
        // HKSample 데이터를 HealthData 모델로 변환
        let measurements = healthKitData.compactMap { sample -> HealthMeasurement? in
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            
            let type = getMeasurementType(from: quantitySample.quantityType)
            let value = quantitySample.quantity.doubleValue(for: getUnit(for: type))
            
            return HealthMeasurement(
                type: type,
                value: value,
                unit: getUnitString(for: type),
                date: sample.startDate
            )
        }
        
        return HealthData(
            userId: UserDefaults.standard.string(forKey: "userId") ?? "",
            provider: .apple,
            measurements: measurements,
            timestamp: Date()
        )
    }
    
    private static func getMeasurementType(from quantityType: HKQuantityType) -> HealthMeasurement.MeasurementType {
        switch quantityType.identifier {
        case HKQuantityTypeIdentifier.stepCount.rawValue:
            return .stepCount
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            return .heartRate
        case HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue:
            return .bloodPressure
        case HKQuantityTypeIdentifier.oxygenSaturation.rawValue:
            return .oxygenSaturation
        case HKQuantityTypeIdentifier.bodyTemperature.rawValue:
            return .bodyTemperature
        case HKQuantityTypeIdentifier.respiratoryRate.rawValue:
            return .respiratoryRate
        case HKQuantityTypeIdentifier.height.rawValue:
            return .height
        case HKQuantityTypeIdentifier.bodyMass.rawValue:
            return .weight
        case HKQuantityTypeIdentifier.runningSpeed.rawValue:
            return .runningSpeed
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            return .activeEnergy
        case HKQuantityTypeIdentifier.basalEnergyBurned.rawValue:
            return .basalEnergy
        default:
            fatalError("Unsupported quantity type: \(quantityType.identifier)")
        }
    }
    
    private static func getUnit(for type: HealthMeasurement.MeasurementType) -> HKUnit {
        switch type {
        case .stepCount:
            return .count()
        case .heartRate:
            return HKUnit.count().unitDivided(by: .minute())
        case .bloodPressure:
            return .millimeterOfMercury()
        case .oxygenSaturation:
            return .percent()
        case .bodyTemperature:
            return .degreeCelsius()
        case .respiratoryRate:
            return HKUnit.count().unitDivided(by: .minute())
        case .height:
            return .meter()
        case .weight:
            return .gramUnit(with: .kilo)
        case .runningSpeed:
            return HKUnit.meter().unitDivided(by: .second())
        case .activeEnergy, .basalEnergy:
            return .kilocalorie()
        case .sleepAnalysis:
            return .count() // Sleep analysis doesn't use units
        }
    }
    
    private static func getUnitString(for type: HealthMeasurement.MeasurementType) -> String {
        switch type {
        case .stepCount:
            return "count"
        case .heartRate:
            return "bpm"
        case .bloodPressure:
            return "mmHg"
        case .oxygenSaturation:
            return "%"
        case .bodyTemperature:
            return "°C"
        case .respiratoryRate:
            return "breaths/min"
        case .height:
            return "m"
        case .weight:
            return "kg"
        case .runningSpeed:
            return "m/s"
        case .activeEnergy, .basalEnergy:
            return "kcal"
        case .sleepAnalysis:
            return "hours"
        }
    }
}