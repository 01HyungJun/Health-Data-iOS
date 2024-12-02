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
                            formSection
                            socialLoginButtons
                            healthDataSection
                            agreementSection
                            bottomButtons
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
                        .zIndex(1) // 다른 뷰 위에 표시되도록 zIndex 설정
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
        HStack(spacing: 15) {
            ForEach(AuthProvider.allCases, id: \.self) { provider in
                Button(action: {
                    selectedLoginProvider = provider.rawValue
                }) {
                    Text(provider.rawValue.capitalized)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(selectedLoginProvider == provider.rawValue ? 
                            Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
            }
        }
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
    
    private var bottomButtons: some View {
        HStack(spacing: 15) {
            Button(action: {
                resetForm()
            }) {
                Text("Reset")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.gray)
                    .cornerRadius(10)
            }
            
            Button(action: {
                Task {
                    await viewModel.authenticate(email: email, password: password)
                }
            }) {
                Text("Verify")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(isFormValid ? Color.blue : Color.gray)
                    .cornerRadius(10)
            }
            .disabled(!isFormValid)
            
            Button(action: {
                Task {
                    if let provider = selectedLoginProvider {
                        await viewModel.authenticateAndFetchHealth(with: AuthProvider(rawValue: provider)!)
                    }
                }
            }) {
                Text("Login")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(selectedLoginProvider != nil ? Color.blue : Color.gray)
                    .cornerRadius(10)
            }
            .disabled(selectedLoginProvider == nil)
        }
        .padding(.horizontal)
        .padding(.vertical, 20)
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