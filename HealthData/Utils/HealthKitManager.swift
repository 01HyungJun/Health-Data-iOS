import HealthKit
import Combine
import CoreLocation

class HealthKitManager: NSObject, ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    
    @Published var isAuthorized = false
    
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
    }
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit을 사용할 수 없는 기기입니다")
            throw HealthKitError.notAvailable
        }
        
        print("\n🔐 HealthKit 권한 요청 시작")
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: self.allTypes)
            try await healthStore.requestAuthorization(toShare: [], read: self.characteristicTypes)
            print("✅ HealthKit 권한 획득 성공")
            
            // 현재 권한 상태 확인 및 로깅
            for type in self.allTypes {
                let status = healthStore.authorizationStatus(for: type)
                print("- \(type.identifier): \(status.rawValue)")
            }
            
            for type in self.characteristicTypes {
                let status = healthStore.authorizationStatus(for: type)
                print("- \(type.identifier): \(status.rawValue)")
            }
            
            DispatchQueue.main.async {
                self.isAuthorized = true
            }
        } catch {
            print("❌ HealthKit 권한 획득 실패: \(error.localizedDescription)")
            throw error
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
    
    func fetchAllHealthData(projectId: Int, date: Date? = nil) async throws -> HealthData {
        let samples = try await fetchData(for: allTypes, at: date)
        let userInfo = try await fetchUserInfo(projectId: projectId)
        
        var healthData = HealthData.from(healthKitData: samples, userInfo: userInfo)
        
        if let location = LocationManager.shared.lastLocation {
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
                    weight: healthData.measurements.weight
                    ,
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
    
    private func fetchData(for types: Set<HKSampleType>, at date: Date? = nil) async throws -> [HKSample] {
        var allSamples: [HKSample] = []
        
        // 사용자 정보 로깅 (임시 projectId 0 사용)
        let userInfo = try await fetchUserInfo(projectId: 0)
        print("\n📱 사용자 정보:")
        print("   - 혈액형: \(userInfo.bloodType ?? "Unknown")")
        print("   - 성별: \(userInfo.biologicalSex ?? "Unknown")")
        print("   - 생년월: \(userInfo.birthDate ?? "Unknown")")
        
        print("\n📊 건강 데이터:")
        
        // date 파라미터가 있으면 해당 시점의 데이터를 가져오기 위한 predicate 생성
        let realtimePredicate: NSPredicate?
        let staticPredicate: NSPredicate?
        
        if let date = date {
            let calendar = Calendar.current
            // 실시간 데이터용 (1주일)
            let realtimeStartDate = calendar.date(byAdding: .day, value: -7, to: date)!
            realtimePredicate = HKQuery.predicateForSamples(
                withStart: realtimeStartDate,
                end: date,
                options: .strictEndDate
            )
            
            // 비실시간 데이터용 (1년)
            let staticStartDate = calendar.date(byAdding: .year, value: -1, to: date)!
            staticPredicate = HKQuery.predicateForSamples(
                withStart: staticStartDate,
                end: date,
                options: .strictEndDate
            )
        } else {
            realtimePredicate = nil
            staticPredicate = nil
        }
        
        for type in types {
            if let quantityType = type as? HKQuantityType {
                do {
                    // 데이터 타입에 따라 다른 predicate 사용
                    let predicate = isRealtimeDataType(quantityType) ? realtimePredicate : staticPredicate
                    
                    if let sample = try await fetchLatestData(for: quantityType, predicate: predicate) {
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
    
    private func fetchLatestData<T: HKQuantityType>(
        for type: T,
        predicate: NSPredicate? = nil
    ) async throws -> HKQuantitySample? {
        return try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
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
    
    // 특정 시점의 측정값만 가져오는 함수 추가
    func fetchHealthMeasurements(at date: Date) async throws -> Measurements {
        let calendar = Calendar.current
        
        // 실시간 데이터는 date 시점까지의 가장 최근 데이터만 찾으면 됨
        let realtimePredicate = HKQuery.predicateForSamples(
            withStart: nil,  // 시작 시점 제한 없음
            end: date,       // 목표 시점까지
            options: .strictEndDate
        )
        
        // 비실시간 데이터도 동일하게 처리
        let staticPredicate = realtimePredicate
        
        print("\n⏰ 데이터 수집 시간 범위:")
        print("목표 시간: \(date)")
        
        var samples: [HKSample] = []
        
        // 각 데이터 타입별로 쿼리 실행
        for type in allTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            // 데이터 타입에 따라 다른 predicate 사용
            let predicate = isRealtimeDataType(quantityType) ? realtimePredicate : staticPredicate
            
            if let sample = try await fetchLatestData(for: quantityType, predicate: predicate) {
                print("✅ \(quantityType.identifier) 데이터 발견: \(sample.startDate)")
                samples.append(sample)
            } else {
                print("❌ \(quantityType.identifier) 데이터 없음")
            }
        }
        
        // 수집된 샘플들을 Measurements 구조체로 변환
        let measurements = Measurements(
            stepCount: getValue(from: samples, for: .stepCount),
            heartRate: getValue(from: samples, for: .heartRate),
            bloodPressureSystolic: getValue(from: samples, for: .bloodPressureSystolic),
            bloodPressureDiastolic: getValue(from: samples, for: .bloodPressureDiastolic),
            oxygenSaturation: getValue(from: samples, for: .oxygenSaturation),
            bodyTemperature: getValue(from: samples, for: .bodyTemperature),
            respiratoryRate: getValue(from: samples, for: .respiratoryRate),
            height: getValue(from: samples, for: .height),
            weight: getValue(from: samples, for: .bodyMass),
            runningSpeed: getValue(from: samples, for: .runningSpeed),
            activeEnergy: getValue(from: samples, for: .activeEnergyBurned),
            basalEnergy: getValue(from: samples, for: .basalEnergyBurned),
            latitude: nil,  // 위치 정보는 별도로 주입
            longitude: nil
        )
        
        return measurements
    }
    
    // 실시간 데이터 타입 체크 함수
    private func isRealtimeDataType(_ type: HKQuantityType) -> Bool {
        let realtimeTypes: Set<String> = [
            HKQuantityTypeIdentifier.stepCount.rawValue,
            HKQuantityTypeIdentifier.activeEnergyBurned.rawValue,
            HKQuantityTypeIdentifier.basalEnergyBurned.rawValue,
            HKQuantityTypeIdentifier.heartRate.rawValue
        ]
        return realtimeTypes.contains(type.identifier)
    }
    
    // 헬스킷 샘플에서 값을 추출하는 헬퍼 함수
    private func getValue(from samples: [HKSample], for identifier: HKQuantityTypeIdentifier) -> Double? {
        guard let sample = samples.first(where: { $0.sampleType.identifier == identifier.rawValue }) as? HKQuantitySample else {
            return nil
        }
        return sample.quantity.doubleValue(for: preferredUnit(for: sample.quantityType))
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
