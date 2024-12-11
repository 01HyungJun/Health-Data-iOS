import SwiftUI
import Combine

class ParticipationViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSuccess = false
    @Published var projects: [Project] = []
    
    private let apiService = APIService.shared
    
    func authenticate(email: String, password: String, projectId: Int) async {
        await MainActor.run { 
            isLoading = true 
            showError = false
            showSuccess = false
        }
        
        do {
            // 로그인 인증 시도
            let authResult = try await apiService.authenticate(email: email, password: password)
            
            // 인증 성공 시 헬스 데이터 가져오기 시도
            let healthData = try await apiService.fetchHealthData(for: authResult.email, projectId: projectId)
            
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
    
    func authenticateAndFetchHealth(with provider: AuthProvider, projectId: Int) async {
        await MainActor.run {
            isLoading = true
            showError = false
            showSuccess = false
        }
        
        do {
            // 인증 처리
            let result = try await apiService.authenticateAndFetchHealthData(with: provider, projectId: projectId)
            
            // UserDefaults 저장
            UserDefaults.standard.set(result.0.email, forKey: "email")
            
            await MainActor.run {
                isLoading = false
                showSuccess = true
            }
        } catch let error as APIError {
            await MainActor.run {
                isLoading = false
                showError = true
                switch error {
                case .socialAuthError(let message):
                    errorMessage = message
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
            await MainActor.run {
                self.projects = fetchedProjects
                print("📋 프로젝트 목록 가져오기 성공: \(fetchedProjects.count)개")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "프로젝트 목록을 가져오는데 실패했습니다: \(error.localizedDescription)"
                self.showError = true
                print("❌ 프로젝트 목록 가져오기 실패: \(error.localizedDescription)")
            }
        }
    }
    
    func registerHealthData(projectId: Int) async {
        await MainActor.run {
            isLoading = true
            showError = false
            showSuccess = false
        }
        
        do {
            // 헬스 데이터 가져오기
            let healthData = try await apiService.fetchHealthData(
                for: UserDefaults.standard.string(forKey: "email") ?? "",
                projectId: projectId
            )
            
            // 서버에 데이터 전송
            try await apiService.registerHealthData(healthData, projectId: projectId)
            
            await MainActor.run {
                isLoading = false
                showSuccess = true
            }
        } catch {
            await MainActor.run {
                isLoading = false
                showError = true
                errorMessage = "데이터 등록 실패: \(error.localizedDescription)"
            }
        }
    }
    
    func resetForm() {
        // 에러/성공 상태 초기화
        showError = false
        showSuccess = false
        errorMessage = ""
        isLoading = false
    }
}