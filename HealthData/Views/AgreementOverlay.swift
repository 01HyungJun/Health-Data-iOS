import SwiftUI

struct AgreementOverlay: View {
    let type: AgreementType
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isPresented = false
                }
            
            VStack(spacing: 16) {
                Text(type.title)
                    .font(.headline)
                    .padding()
                    .foregroundColor(.primary)
                
                ScrollView {
                    Text(type.content)
                        .foregroundColor(.primary)
                        .padding()
                        .multilineTextAlignment(.leading)
                }
                .frame(maxHeight: UIScreen.main.bounds.height * 0.6)
                
                Button(action: {
                    isPresented = false
                }) {
                    Text("닫기")
                        .foregroundColor(.white)
                        .frame(width: 100)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.bottom)
            }
            .frame(width: UIScreen.main.bounds.width * 0.9)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(radius: 10)
            )
            .padding()
        }
    }
}

enum AgreementType {
    case terms
    case privacy
    case location
    
    var title: String {
        switch self {
        case .terms:
            return "이용약관"
        case .privacy:
            return "개인정보 처리방침"
        case .location:
            return "위치정보 이용약관"
        }
    }
    
    var content: String {
        switch self {
        case .terms:
            return """
            제1조 (목적)
            이 약관은 회사가 제공하는 서비스의 이용조건 및 절차, 이용자와 회사의 권리, 의무, 책임사항을 규정함을 목적으로 합니다.

            제2조 (정의)
            1. "서비스"란 회사가 제공하는 모든 서비스를 의미합니다.
            2. "이용자"란 이 약관에 따라 서비스를 이용하는 회원을 말합니다.
            """
        case .privacy:
            return """
            1. 수집하는 개인정보 항목
            - 필수항목: 이름, 이메일, 건강데이터
            - 선택항목: 위치정보

            2. 개인정보의 수집 및 이용목적
            - 서비스 제공 및 개선
            - 건강상태 분석 및 맞춤 서비스 제공
            """
        case .location:
            return """
            1. 위치정보 수집 목적
            - 사용자 맞춤형 서비스 제공
            - 운동 경로 기록 및 분석

            2. 위치정보 보유기간
            - 서비스 제공 기간 동안 보관
            """
        }
    }
}