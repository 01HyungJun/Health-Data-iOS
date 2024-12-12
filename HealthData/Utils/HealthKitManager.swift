import HealthKit
import Combine
import CoreLocation

class HealthKitManager: NSObject, ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    private let locationManager = CLLocationManager()
    
    @Published var isAuthorized = false
    @Published var currentLocation: CLLocation?
    
    // 수집할 데이터 유형들
    private lazy var allTypes: Set<HKSampleType> = {
        let types: [HKSampleType] = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .runningSpeed)!,
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .height)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!
        ]
        return Set(types)
    }()
    
    // 사용자 특성 데이터 유형들
    private lazy var characteristicTypes: Set<HKObjectType> = {
        let types: [HKObjectType] = [
            HKObjectType.characteristicType(forIdentifier: .bloodType)!,
            HKObjectType.characteristicType(forIdentifier: .biologicalSex)!,
            HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!
        ]
        return Set(types)
    }()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        // HealthKit 권한 요청 (건강 데이터와 특성 데이터 모두)
        let readTypes = Set([
            // 특성 데이터
            HKObjectType.characteristicType(forIdentifier: .bloodType)!,
            HKObjectType.characteristicType(forIdentifier: .biologicalSex)!,
            HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!
        ]).union(allTypes)
        
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        
        DispatchQueue.main.async {
            self.isAuthorized = true
            if self.locationManager.authorizationStatus == .authorizedWhenInUse {
                self.locationManager.startUpdatingLocation()
            }
        }
    }
    
    func fetchUserInfo(projectId: Int) async throws -> UserInfo {
        // 혈액형 가져오기
        let bloodTypeObject = try? healthStore.bloodType()
        let bloodType = bloodTypeObject?.bloodType.toString() ?? "Unknown"
        
        // 성별 가져오기
        let biologicalSexObject = try? healthStore.biologicalSex()
        let biologicalSex = biologicalSexObject?.biologicalSex.toString() ?? "Unknown"
        
        // 생년월일 가져오기
        let birthComponents = try? healthStore.dateOfBirthComponents()
        let year = birthComponents?.year ?? 0
        let month = birthComponents?.month ?? 0
        let day = birthComponents?.day ?? 1
        let birthDateString = String(format: "%04d-%02d-%02d", year, month, day)
        
        // UserDefaults에서 저장된 이메일과 provider 정보를 가져옴
        // 앱이 실행 중이지 않았어도 이전에 저장한 값을 읽어올 수 있음
        let email = UserDefaults.standard.string(forKey: "userEmail") ?? "unknown@example.com"
        let provider = UserDefaults.standard.string(forKey: "provider") ?? "unknown"
        
        return UserInfo(
            projectId: projectId,
            email: email,  // UserDefaults에서 가져온 이메일 사용
            provider: provider,
            bloodType: bloodType,
            biologicalSex: biologicalSex,
            birthDate: birthDateString
        )
    }
    
    func fetchAllHealthData(projectId: Int) async throws -> HealthData {
        let samples = try await fetchData(for: allTypes)
        let userInfo = try await fetchUserInfo(projectId: projectId)
        
        // 위치 정보를 포함한 HealthData 생성
        var healthData = HealthData.from(healthKitData: samples, userInfo: userInfo)
        
        // 위치 정보를 measurements에 추가
        if let location = currentLocation {
            healthData = HealthData(
                userInfo: healthData.userInfo,
                measurements: Measurements(
                    stepCount: healthData.measurements.stepCount,
                    heartRate: healthData.measurements.heartRate,
                    bloodPressureSystolic: healthData.measurements.bloodPressureSystolic,
                    bloodPressureDiastolic: healthData.measurements.bloodPressureDiastolic,
                    oxygenSaturation: healthData.measurements.oxygenSaturation,
                    bodyTemperature: healthData.measurements.bodyTemperature,
                    respiratoryRate: healthData.measurements.respiratoryRate,
                    height: healthData.measurements.height,
                    weight: healthData.measurements.weight,
                    runningSpeed: healthData.measurements.runningSpeed,
                    activeEnergy: healthData.measurements.activeEnergy,
                    basalEnergy: healthData.measurements.basalEnergy,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            )
        }
        
        return healthData
    }
    
    private func fetchData(for types: Set<HKSampleType>) async throws -> [HKSample] {
        var allSamples: [HKSample] = []
        
        // 사용자 정보 로깅 (임시 projectId 0 사용)
        let userInfo = try await fetchUserInfo(projectId: 0)  // 로깅용이라 임시값 사용
        print("\n📱 사용자 정보:")
        print("   - 혈액형: \(userInfo.bloodType ?? "Unknown")")
        print("   - 성별: \(userInfo.biologicalSex ?? "Unknown")")
        print("   - 생년월: \(userInfo.birthDate ?? "Unknown")")
        
        print("\n📊 건강 데이터:")
        
        for type in types {
            if let quantityType = type as? HKQuantityType {
                do {
                    if let sample = try await fetchLatestData(for: quantityType) {
                        allSamples.append(sample)
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

extension HealthKitManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            print("📍 위치 정보: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            self.currentLocation = location
            // 위치를 받았으면 업데이트 중지
            locationManager.stopUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 위치 오류: \(error.localizedDescription)")
    }
}

extension HKBloodType {
    func toString() -> String {
        switch self {
        case .notSet: return "Unknown"
        case .aPositive: return "A+"
        case .aNegative: return "A-"
        case .bPositive: return "B+"
        case .bNegative: return "B-"
        case .abPositive: return "AB+"
        case .abNegative: return "AB-"
        case .oPositive: return "O+"
        case .oNegative: return "O-"
        @unknown default: return "Unknown"
        }
    }
}

extension HKBiologicalSex {
    func toString() -> String {
        switch self {
        case .notSet: return "Unknown"
        case .female: return "Female"
        case .male: return "Male"
        case .other: return "Other"
        @unknown default: return "Unknown"
        }
    }
}

enum HealthKitError: Error {
    case notAvailable
    case notAuthorized
    case fetchError
}
