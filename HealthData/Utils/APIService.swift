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
    
    private init() {
        // Google Sign In 초기화 - 나중에 SDK 설치 후 주석 해제
        // GIDSignIn.sharedInstance.configuration = GIDConfiguration(
        //     clientID: Config.googleClientId
        // )
    }
    
    // 소셜 로그인 및 헬스 데이터 가져오기를 한번에 처리
    func authenticateAndFetchHealthData(with provider: AuthProvider) async throws -> (AuthenticationResult, HealthData) {
        // 1. 소셜 로그인 인증
        let authResult = try await authenticateUser(with: provider)
        
        // 2. 헬스 데이터 가져오기
        let healthData = try await fetchHealthData(for: authResult.userId)
        
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
                
                // delegate 객체를 강한 참조로 유지
                let delegate = AppleSignInDelegate { credential, error in
                    if let error = error {
                        continuation.resume(throwing: APIError.socialAuthError(error.localizedDescription))
                        return
                    }
                    
                    guard let credential = credential else {
                        continuation.resume(throwing: APIError.authenticationError)
                        return
                    }
                    
                    let authResult = AuthenticationResult(
                        userId: credential.user,
                        authToken: credential.identityToken?.base64EncodedString() ?? "",
                        provider: .apple
                    )
                    continuation.resume(returning: authResult)
                }
                
                // delegate를 속성에 저장하고 컨트롤러에 설정
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
            userId: "test_user_id",
            authToken: "test_token",
            provider: .apple
        )
    }
    
    func fetchHealthData(for userId: String) async throws -> HealthData {
        // HealthKit에서 데이터 가져오기
        try await healthKitManager.requestAuthorization()
        let samples = try await healthKitManager.fetchAllHealthData()
        return HealthData.from(healthKitData: samples)
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
    let userId: String
    let authToken: String
    let provider: AuthProvider
}