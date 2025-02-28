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
            
            // UserDefaults에 프로젝트 ID와 이메일 저장
            UserDefaults.standard.set(projectId, forKey: "lastProjectId")
            UserDefaults.standard.set(result.0.email, forKey: "userEmail")
            
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
        let backgroundTask = UIApplication.shared.beginBackgroundTask { 
            UIApplication.shared.endBackgroundTask(UIBackgroundTaskIdentifier.invalid)
        }
        
        await MainActor.run {
            isLoading = true
            showError = false
            showSuccess = false
        }
        
        do {
            // 0. 마지막 동기화 시점 확인
            if let lastSyncTime = UserDefaults.standard.object(forKey: "lastDataSyncTime") as? Date {
                print("\n📅 마지막 데이터 동기화 시점: \(lastSyncTime)")
            } else {
                print("\n📱 최초 실행: 이전 동기화 기록 없음")
            }
            
            // 1. userInfo는 한 번만 가져옴
            let userInfo = try await apiService.fetchUserInfo(projectId: projectId)
            
            // 2. 현재 위치 정보 가져오기 (모든 측정값에 사용될 현재 위치)
            let currentLocation = LocationManager.shared.lastLocation
            let latitude = currentLocation?.coordinate.latitude
            let longitude = currentLocation?.coordinate.longitude
            
            var allMeasurements: [TimestampedMeasurement] = []
            
            // 3. 누락된 과거 데이터 수집
            if let lastSyncTimeStamp = UserDefaults.standard.object(forKey: "lastDataSyncTime") as? Date {
                // 이전 동기화 기록이 있는 경우
                print("📅 마지막 동기화 시점: \(lastSyncTimeStamp)")
                
                let now = Date()  // 현재 시간
                let calendar = Calendar.current
                let minutes = calendar.dateComponents([.minute], from: lastSyncTimeStamp, to: now).minute ?? 0
                
                if minutes > 0 {
                    print("⏰ \(minutes)분 동안의 누락된 데이터 수집 시작")
                    
                    // 1분 단위로 데이터 수집
                    for minuteOffset in 0...minutes {
                        let targetDate = calendar.date(byAdding: .minute, value: minuteOffset, to: lastSyncTimeStamp)!
                        if targetDate > now {  // 미래 시간은 건너뛰기
                            break
                        }
                        let measurement = try await apiService.fetchMeasurement(
                            date: targetDate,
                            latitude: latitude,  // 현재 위치 사용
                            longitude: longitude // 현재 위치 사용
                        )
                        allMeasurements.append(measurement)
                    }
                    
                    // 수집된 모든 데이터를 한번에 전송
                    print("📤 누락된 데이터 \(allMeasurements.count)개 전송")
                    let batchData = BatchHealthData(
                        userInfo: userInfo,
                        measurements: allMeasurements
                    )
                    try await apiService.registerBatchHealthData(batchData, projectId: projectId)
                    
                    // 데이터 전송 성공 후 현재 시점을 마지막 동기화 시점으로 저장
                    UserDefaults.standard.set(now, forKey: "lastDataSyncTime")
                }
            } else {
                // 앱을 처음 사용하는 경우
                print("📱 앱 최초 실행: 현재 시점부터 데이터 수집을 시작합니다")
                let now = Date()
                
                // 현재 시점의 데이터만 수집하여 전송
                let measurement = try await apiService.fetchMeasurement(
                    date: now,
                    latitude: latitude,
                    longitude: longitude
                )
                allMeasurements.append(measurement)
                
                let batchData = BatchHealthData(
                    userInfo: userInfo,
                    measurements: allMeasurements
                )
                try await apiService.registerBatchHealthData(batchData, projectId: projectId)
                
                // 데이터 전송 성공 후 현재 시점을 마지막 동기화 시점으로 저장
                UserDefaults.standard.set(now, forKey: "lastDataSyncTime")
            }
            
            // 성공 후 백그라운드 작업 시작 (1분 주기로 데이터 수집)
            BackgroundTaskManager.shared.startBackgroundTaskWithDelay()
            
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
        
        UIApplication.shared.endBackgroundTask(backgroundTask)
    }
    
    func resetForm() {
        // 에러/성공 상태 초기화
        showError = false
        showSuccess = false
        errorMessage = ""
        isLoading = false
    }
}