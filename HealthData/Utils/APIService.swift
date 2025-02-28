import Foundation
import AuthenticationServices // Apple 로그인용
// import GoogleSignIn // Google 로그인용 - 나중에 SDK 설치 후 주석 해제
// Samsung Health SDK import 필요

enum APIError: Error {
    case invalidURL
    case networkError
    case invalidResponse
    case authenticationError
    case socialAuthError(String)
    case unsupportedProvider
    case fetchError
}

class APIService {
    static let shared = APIService()
    private let healthKitManager = HealthKitManager.shared
    private var appleSignInDelegate: AppleSignInDelegate?
    
    // MARK: - API Constants
    private let baseURL = "http://air.monomate.kr:8080"
    private let session: URLSession
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: configuration)
    }
    
    // 소셜 로그인 및 헬스 데이터 가져오기를 한번에 처리
    func authenticateAndFetchHealthData(with provider: AuthProvider, projectId: Int) async throws -> (AuthenticationResult, HealthData) {
        // 1. 소셜 로그인 인증
        let authResult = try await authenticateUser(with: provider)
        
        // UserDefaults에 이메일과 제공자 정보를 저장
        // UserDefaults는 iOS에서 제공하는 간단한 데이터 저장소이다!
        // 앱을 종료하고 다시 실행해도 이 정보가 유지됨
        // 앱을 삭제하면 이 정보도 함께 삭제됨
        UserDefaults.standard.set(authResult.email, forKey: "userEmail")
        UserDefaults.standard.set(provider.rawValue, forKey: "provider")
        
        // 2. 헬스 데이터 가져오기
        let healthData = try await fetchHealthData(for: authResult.email, projectId: projectId)
        
        return (authResult, healthData)
    }
    
    private func authenticateUser(with provider: AuthProvider) async throws -> AuthenticationResult {
        switch provider {
        case .apple:
            return try await authenticateWithApple()
        case .samsung:
            return try await authenticateWithSamsung()
        case .google:
            throw APIError.unsupportedProvider
        }
    }
    
    private func authenticateWithApple() async throws -> AuthenticationResult {
        try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let appleIDProvider = ASAuthorizationAppleIDProvider()
                let request = appleIDProvider.createRequest()
                request.requestedScopes = [.fullName, .email]
                
                let authorizationController = ASAuthorizationController(authorizationRequests: [request])
                
                let delegate = AppleSignInDelegate { credential, error in
                    if let error = error {
                        continuation.resume(throwing: APIError.socialAuthError(error.localizedDescription))
                        return
                    }
                    
                    guard let credential = credential else {
                        continuation.resume(throwing: APIError.authenticationError)
                        return
                    }
                    
                    // 1. 새로 받은 이메일이 있으면 UserDefaults에 저장하고 사용
                    // 이렇게 저장된 이메일은 앱을 재시작해도 유지됨
                    if let email = credential.email {
                        UserDefaults.standard.set(email, forKey: "userEmail")
                        let authResult = AuthenticationResult(
                            email: email,
                            authToken: credential.identityToken?.base64EncodedString() ?? "",
                            provider: .apple
                        )
                        continuation.resume(returning: authResult)
                        return
                    }
                    
                    // 2. 새로 받은 이메일이 없으면 UserDefaults에 저장된 이메일을 사용
                    // 이전에 로그인했던 기록이 있다면 저장된 이메일을 재사용
                    if let savedEmail = UserDefaults.standard.string(forKey: "userEmail") {
                        let authResult = AuthenticationResult(
                            email: savedEmail,
                            authToken: credential.identityToken?.base64EncodedString() ?? "",
                            provider: .apple
                        )
                        continuation.resume(returning: authResult)
                        return
                    }
                    
                    // 3. UserDefaults에 저장된 이메일도 없으면 에러
                    // 이때는 Apple 로그인 설정에서 해당 앱을 삭제한 후 다시 시도.
                    continuation.resume(throwing: APIError.socialAuthError(
                        "이메일 정보를 찾을 수 없습니다. 설정 -> Apple 계정 -> Apple로 로그인 -> 앱 삭제 후 다시 시도해주세요."
                    ))
                }
                
                self.appleSignInDelegate = delegate
                authorizationController.delegate = delegate
                
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first else {
                    continuation.resume(throwing: APIError.authenticationError)
                    return
                }
                
                let contextProvider = AppleSignInPresentationContextProvider(window: window)
                authorizationController.presentationContextProvider = contextProvider
                authorizationController.performRequests()
            }
        }
    }
    
    private func authenticateWithSamsung() async throws -> AuthenticationResult {
        // Samsung Health SDK를 통한 인증
        guard let url = URL(string: "shealth://authorize") else {
            throw APIError.invalidURL
        }
        
        guard await UIApplication.shared.canOpenURL(url) else {
            throw APIError.socialAuthError("Samsung Health app is not installed")
        }
        
        throw APIError.unsupportedProvider
    }
    
    func authenticate(email: String, password: String) async throws -> AuthenticationResult {
        // TODO: 실제 인증 로직 구현
        // 임시로 성공 응답 반환
        return AuthenticationResult(
            email: "test_user_id",
            authToken: "test_token",
            provider: .apple
        )
    }
    
    func fetchHealthData(for email: String, projectId: Int, date: Date? = nil) async throws -> HealthData {
        try await healthKitManager.requestAuthorization()
        
        // 특정 시점의 데이터 수집
        let healthData = try await healthKitManager.fetchAllHealthData(
            projectId: projectId,
            date: date // nil이면 현재 시점, 아니면 지정된 시점의 데이터
        )
        return healthData
    }
    
    func fetchProjects() async throws -> [Project] {
        guard let url = URL(string: "\(baseURL)/api/v1/projects") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        // JSON 디코딩 디버깅
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📝 받은 JSON 데이터: \(jsonString)")
        }
        
        do {
            let decoder = JSONDecoder()
            let projectResponse = try decoder.decode(ProjectResponse.self, from: data)
            let projects = projectResponse.projectList
            print("✅ 프로젝트 파싱 성공: \(projects.count)개")
            return projects
        } catch {
            print("❌ JSON 파싱 에러: \(error)")
            throw error
        }
    }
    
    // 공통으로 사용할 인코딩 로직
    private func encodeHealthData(_ batchData: BatchHealthData) throws -> Data {
        let encoder = JSONEncoder()
    
        // 날짜 포맷 설정
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.locale = Locale(identifier: "ko_KR")
        encoder.dateEncodingStrategy = .formatted(formatter)
        
        // BatchHealthData를 그대로 인코딩
        return try encoder.encode(batchData)
    }
    
    func registerHealthData(_ healthData: HealthData, projectId: Int) async throws {
        let url = URL(string: "\(baseURL)/api/v1/health")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 단일 측정값을 BatchHealthData 형식으로 변환
        let batchData = BatchHealthData(
            userInfo: healthData.userInfo,
            measurements: [TimestampedMeasurement(
                timestamp: Date(),
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
                latitude: healthData.measurements.latitude,
                longitude: healthData.measurements.longitude
            )]
        )
        
        // 데이터 인코딩
        let requestData = try encodeHealthData(batchData)
        request.httpBody = requestData
        
        // 요청 데이터 로깅
        if let jsonString = String(data: requestData, encoding: .utf8) {
            print("\n📤 전송할 데이터:")
            print(jsonString)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("\n📡 서버 응답 상태 코드: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ 서버 에러 응답: \(errorString)")
            }
            throw APIError.invalidResponse
        }
        
        print("✅ 건강 데이터 등록 성공")
    }
    
    // userInfo만 따로 가져오는 함수
    func fetchUserInfo(projectId: Int) async throws -> UserInfo {
        try await healthKitManager.requestAuthorization()
        return try await healthKitManager.fetchUserInfo(projectId: projectId)
    }
    
    // measurements만 가져오는 함수
    func fetchMeasurement(date: Date, latitude: Double?, longitude: Double?) async throws -> TimestampedMeasurement {
        print("\n🔍 건강 데이터 수집 시작: \(date)")
        let healthData = try await healthKitManager.fetchHealthMeasurements(at: date)
        
        // 수집된 데이터 로깅
        print("📊 수집된 건강 데이터:")
        print("- 걸음 수: \(healthData.stepCount ?? -1)")
        print("- 활동 칼로리: \(healthData.activeEnergy ?? -1)")
        print("- 기초 칼로리: \(healthData.basalEnergy ?? -1)")
        
        let measurement = TimestampedMeasurement(
            timestamp: date,
            stepCount: healthData.stepCount,
            heartRate: healthData.heartRate,
            bloodPressureSystolic: healthData.bloodPressureSystolic,
            bloodPressureDiastolic: healthData.bloodPressureDiastolic,
            oxygenSaturation: healthData.oxygenSaturation,
            bodyTemperature: healthData.bodyTemperature,
            respiratoryRate: healthData.respiratoryRate,
            height: healthData.height,
            weight: healthData.weight,  // bodyMass에서 weight로 변경
            runningSpeed: healthData.runningSpeed,
            activeEnergy: healthData.activeEnergy,
            basalEnergy: healthData.basalEnergy,
            latitude: latitude,
            longitude: longitude
        )
        
        return measurement
    }
    
    // 배치 데이터 전송 함수
    func registerBatchHealthData(_ batchData: BatchHealthData, projectId: Int) async throws {
        let url = URL(string: "\(baseURL)/api/v1/health")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 데이터 인코딩
        let requestData = try encodeHealthData(batchData)
        request.httpBody = requestData
        
        print("\n🌐 API 요청 정보:")
        print("URL: \(url)")
        print("Method: POST")
        print("Headers: \(request.allHTTPHeaderFields ?? [:])")
        if let jsonString = String(data: requestData, encoding: .utf8) {
            print("Body: \(jsonString)")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ 잘못된 응답 형식")
            throw APIError.invalidResponse
        }
        
        print("\n📡 서버 응답:")
        print("Status Code: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ 서버 에러 응답: \(errorString)")
            }
            throw APIError.invalidResponse
        }
        
        print("✅ 건강 데이터 등록 성공")
    }
}

// PresentationContextProvider 수정
private class AppleSignInPresentationContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    private let window: UIWindow
    
    init(window: UIWindow) {
        self.window = window
        super.init()
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return window
    }
}

// AppleSignInDelegate 수정
private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let completion: (ASAuthorizationAppleIDCredential?, Error?) -> Void
    
    init(completion: @escaping (ASAuthorizationAppleIDCredential?, Error?) -> Void) {
        self.completion = completion
        super.init()
    }
    
    func authorizationController(controller: ASAuthorizationController, 
                               didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credentials = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completion(nil, APIError.authenticationError)
            return
        }
        completion(credentials, nil)
    }
    
    func authorizationController(controller: ASAuthorizationController, 
                               didCompleteWithError error: Error) {
        completion(nil, error)
    }
}

// 인증 결과를 담는 구조체
struct AuthenticationResult {
    let email: String
    let authToken: String
    let provider: AuthProvider
}
