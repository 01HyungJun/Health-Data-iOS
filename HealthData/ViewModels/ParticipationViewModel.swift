import SwiftUI
import Combine

class ParticipationViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSuccess = false
    @Published var projects: [Project] = []
    
    private let apiService = APIService.shared
    
    func authenticate(email: String, password: String) async {
        await MainActor.run { 
            isLoading = true 
            showError = false
            showSuccess = false
        }
        
        do {
            // 로그인 인증 시도
            let authResult = try await apiService.authenticate(email: email, password: password)
            
            // 인증 성공 시 헬스 데이터 가져오기 시도
            let healthData = try await apiService.fetchHealthData(for: authResult.userId)
            
            await MainActor.run {
                isLoading = false
                showSuccess = true
            }
        } catch let error as APIError {
            await MainActor.run {
                isLoading = false
                showError = true
                switch error {
                case .authenticationError:
                    errorMessage = "인증 실패: 유효하지 않은 계정입니다"
                case .networkError:
                    errorMessage = "네트워크 오류가 발생했습니다"
                case .fetchError:
                    errorMessage = "헬스 데이터를 가져오는데 실패했습니다"
                default:
                    errorMessage = "알 수 없는 오류가 발생했습니다"
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                showError = true
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func authenticateAndFetchHealth(with provider: AuthProvider) async {
        await MainActor.run {
            isLoading = true
            showError = false
            showSuccess = false
        }
        
        do {
            // 인증 처리
            let result = try await apiService.authenticateAndFetchHealthData(with: provider)
            
            // UserDefaults 저장
            UserDefaults.standard.set(result.0.userId, forKey: "userId")
            
            await MainActor.run {
                isLoading = false
                showSuccess = true
            }
        } catch let error as APIError {
            await MainActor.run {
                isLoading = false
                showError = true
                switch error {
                case .authenticationError:
                    errorMessage = "인증 실패: 유효하지 않은 계정입니다"
                case .networkError:
                    errorMessage = "네트워크 오류가 발생했습니다"
                case .fetchError:
                    errorMessage = "헬스 데이터를 가져오는데 실패했습니다"
                default:
                    errorMessage = "알 수 없는 오류가 발생했습니다"
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                showError = true
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func fetchProjects() async {
        do {
            let fetchedProjects = try await apiService.fetchProjects()
            DispatchQueue.main.async {
                self.projects = fetchedProjects
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "프로젝트 목록을 가져오는데 실패했습니다: \(error.localizedDescription)"
                self.showError = true
            }
        }
    }
}