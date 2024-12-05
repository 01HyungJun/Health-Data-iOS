import HealthKit
import Combine

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    
    @Published var isAuthorized = false
    
    // 수집할 데이터 유형
    private lazy var allTypes: Set<HKSampleType> = {
        guard let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount),
              let runningSpeed = HKObjectType.quantityType(forIdentifier: .runningSpeed),
              let basalEnergy = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned),
              let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
              let sleepAnalysis = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let height = HKObjectType.quantityType(forIdentifier: .height),
              let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass),
              let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate),
              let oxygenSaturation = HKObjectType.quantityType(forIdentifier: .oxygenSaturation),
              let bloodPressureSystolic = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
              let bloodPressureDiastolic = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic),
              let respiratoryRate = HKObjectType.quantityType(forIdentifier: .respiratoryRate),
              let bodyTemperature = HKObjectType.quantityType(forIdentifier: .bodyTemperature) else {
            return Set()
        }
        
        return [stepCount, runningSpeed, basalEnergy, activeEnergy, sleepAnalysis, height, bodyMass, heartRate, oxygenSaturation, bloodPressureSystolic, bloodPressureDiastolic, respiratoryRate, bodyTemperature]
    }()
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        try await healthStore.requestAuthorization(toShare: [], read: allTypes)
        DispatchQueue.main.async {
            self.isAuthorized = true
        }
    }
    
    func fetchAllHealthData() async throws -> [HKSample] {
        return try await fetchData(for: allTypes)
    }
    
    private func fetchData(for types: Set<HKSampleType>) async throws -> [HKSample] {
        var allSamples: [HKSample] = []
        
        for type in types {
            if let quantityType = type as? HKQuantityType {
                do {
                    if let sample = try await fetchLatestData(for: quantityType) {
                        allSamples.append(sample)
                        // 데이터 로깅
                        let value = sample.quantity.doubleValue(for: preferredUnit(for: quantityType))
                        print("✅ 데이터: \(quantityType.identifier)")
                        print("   - 값: \(value)")
                        print("   - 날짜: \(sample.startDate)")
                    } else {
                        print("⚠️ 데이터 없음: \(quantityType.identifier)")
                    }
                } catch {
                    print("❌ 에러 발생: \(quantityType.identifier)")
                    print("   - \(error.localizedDescription)")
                }
            }
        }
        
        return allSamples
    }
    
    private func fetchLatestData<T: HKQuantityType>(for type: T) async throws -> HKQuantitySample? {
        return try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { (_, samples, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                
                continuation.resume(returning: sample)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func preferredUnit(for quantityType: HKQuantityType) -> HKUnit {
        switch quantityType.identifier {
        case HKQuantityTypeIdentifier.stepCount.rawValue:
            return .count()
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            return HKUnit.count().unitDivided(by: .minute())
        case HKQuantityTypeIdentifier.oxygenSaturation.rawValue:
            return .percent()
        case HKQuantityTypeIdentifier.bodyTemperature.rawValue:
            return .degreeCelsius()
        case HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue,
             HKQuantityTypeIdentifier.bloodPressureDiastolic.rawValue:
            return .millimeterOfMercury()
        case HKQuantityTypeIdentifier.respiratoryRate.rawValue:
            return HKUnit.count().unitDivided(by: .minute())
        case HKQuantityTypeIdentifier.height.rawValue:
            return .meter()
        case HKQuantityTypeIdentifier.bodyMass.rawValue:
            return .gramUnit(with: .kilo)
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue,
             HKQuantityTypeIdentifier.basalEnergyBurned.rawValue:
            return .kilocalorie()
        case HKQuantityTypeIdentifier.runningSpeed.rawValue:
            return HKUnit.meter().unitDivided(by: .second())
        default:
            return .count()
        }
    }
}

enum HealthKitError: Error {
    case notAvailable
    case notAuthorized
    case fetchError
}
