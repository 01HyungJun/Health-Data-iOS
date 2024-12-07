import SwiftUI
import Combine

struct ParticipationView: View {
    // MARK: - State Properties
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    
    // 모달 표시 상태
    @State private var showSuccessModal = false
    @State private var showInvalidModal = false
    @State private var showSyncErrorModal = false
    @State private var showAgreementOverlay = false
    
    // 소셜 로그인 선택
    @State private var selectedLoginProvider: String?
    
    // 약관 동의 상태
    @State private var healthDataAgreement = false
    @State private var termsOfUse = false
    @State private var personalInfo = false
    @State private var locationInfo = false
    
    // 헬스데이터 소스 선택
    @State private var samsungHealthEnabled = false
    @State private var appleHealthEnabled = false
    
    // 현재 선택된 약관 타입
    @State private var selectedAgreement: AgreementType?
    
    // ViewModel
    @StateObject private var viewModel = ParticipationViewModel()
    
    // 프로젝트 선택 상태
    @State private var selectedProjectId: Int?
    @State private var showProjectPicker = false
    
    // 약관 동의 유효성 검사
    private var isAgreementValid: Bool {
        healthDataAgreement && termsOfUse && personalInfo && locationInfo
    }
    
    // 폼 유효성 검사
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty &&
        (healthDataAgreement && termsOfUse && personalInfo && locationInfo)
    }
    
    // MARK: - View Body
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    ScrollView {
                        VStack(spacing: 20) {
                            headerSection
                            socialLoginButtons
                            projectSelectionSection
                            agreementSection
                        }
                        .padding()
                        .frame(minWidth: geometry.size.width)
                        .frame(minHeight: geometry.size.height)
                    }
                    .background(Color(UIColor.systemBackground))
                    
                    // 오버레이들
                    if showAgreementOverlay {
                        AgreementOverlay(
                            type: selectedAgreement ?? .terms,
                            isPresented: $showAgreementOverlay
                        )
                        .zIndex(1)
                    }
                    
                    if viewModel.showSuccess {
                        ModalView(message: "Registration Successful", type: .success)
                    }
                    
                    if viewModel.showError {
                        ModalView(message: viewModel.errorMessage, type: .error)
                    }
                    
                    if viewModel.isLoading {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .task {
            // 뷰가 나타날 때 프로젝트 목록 가져오기
            await viewModel.fetchProjects()
        }
    }
    
    // MARK: - View Components
    private var headerSection: some View {
        VStack {
            Text("Participation")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Plz, apply with Account for Samsung Health or Apple Account")
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
    }
    
    private var formSection: some View {
        VStack {
            TextField("ID", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
            
            HStack {
                if showPassword {
                    TextField("PW", text: $password)
                } else {
                    SecureField("PW", text: $password)
                }
                
                Button(action: {
                    showPassword.toggle()
                }) {
                    Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                        .foregroundColor(.gray)
                }
            }
            .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
    
    private var socialLoginButtons: some View {
        VStack(spacing: 15) {
            ForEach(AuthProvider.allCases, id: \.self) { provider in
                Button(action: {
                    if isAgreementValid {
                        Task {
                            await viewModel.authenticateAndFetchHealth(with: provider)
                        }
                    } else {
                        viewModel.errorMessage = "모든 약관에 동의해주세요"
                        viewModel.showError = true
                    }
                }) {
                    HStack {
                        Image(systemName: provider == .samsung ? "s.circle.fill" :
                                       provider == .apple ? "apple.logo" : "g.circle.fill")
                        Text("\(provider.rawValue.capitalized)로 계속하기")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .padding(.vertical, 20)
    }
    
    private var healthDataSection: some View {
        VStack(alignment: .leading) {
            Text("Health Data Source:")
                .font(.headline)
            
            HStack(spacing: 20) {
                Toggle("Samsung Health", isOn: Binding(
                    get: { samsungHealthEnabled },
                    set: { newValue in
                        if newValue {
                            samsungHealthEnabled = true
                            appleHealthEnabled = false
                        }
                    }
                ))
                
                Toggle("Apple Health", isOn: Binding(
                    get: { appleHealthEnabled },
                    set: { newValue in
                        if newValue {
                            appleHealthEnabled = true
                            samsungHealthEnabled = false
                        }
                    }
                ))
            }
        }
    }
    
    private var projectSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("프로젝트 선택")
                .font(.headline)
            
            Menu {
                ForEach(viewModel.projects) { project in
                    Button(action: {
                        selectedProjectId = project.id
                    }) {
                        HStack {
                            Text(project.projectName)
                            if selectedProjectId == project.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedProjectId.flatMap { id in
                        viewModel.projects.first { $0.id == id }?.projectName
                    } ?? "프로젝트를 선택하세요")
                    .foregroundColor(selectedProjectId == nil ? .gray : .primary)
                    
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.5))
                )
            }
        }
        .padding(.horizontal)
    }
    
    // 약관 보기 기능 수정
    private var agreementSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("약관 동의")
                .font(.headline)
            
            VStack(alignment: .leading) {
                HStack {
                    Toggle("건강 데이터 동의", isOn: $healthDataAgreement)
                    Button("[보기]") {
                        selectedAgreement = .terms
                        showAgreementOverlay = true
                    }
                }
                
                HStack {
                    Toggle("이용약관", isOn: $termsOfUse)
                    Button("[보기]") {
                        selectedAgreement = .terms
                        showAgreementOverlay = true
                    }
                }
                
                HStack {
                    Toggle("개인정보 처리방침", isOn: $personalInfo)
                    Button("[보기]") {
                        selectedAgreement = .privacy
                        showAgreementOverlay = true
                    }
                }
                
                HStack {
                    Toggle("위치정보 이용약관", isOn: $locationInfo)
                    Button("[보기]") {
                        selectedAgreement = .location
                        showAgreementOverlay = true
                    }
                }
            }
        }
    }
    
    private func resetForm() {
        email = ""
        password = ""
        healthDataAgreement = false
        termsOfUse = false
        personalInfo = false
        locationInfo = false
        selectedLoginProvider = nil
        samsungHealthEnabled = false
        appleHealthEnabled = false
    }
}