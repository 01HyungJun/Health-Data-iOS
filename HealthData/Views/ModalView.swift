import SwiftUI

struct ModalView: View {
    let message: String
    let type: ModalType
    @State private var isVisible = true
    
    enum ModalType {
        case success
        case error
    }
    
    var body: some View {
        VStack {
            if isVisible {
                Text(message)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(type == .success ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    )
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                isVisible = false
                            }
                        }
                    }
            }
        }
        .padding()
    }
}