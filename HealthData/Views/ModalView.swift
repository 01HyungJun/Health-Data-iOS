import SwiftUI

struct ModalView: View {
    let message: String
    let type: ModalType
    
    enum ModalType {
        case success
        case error
    }
    
    var body: some View {
        VStack {
            Text(message)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(type == .success ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                )
        }
        .padding()
    }
}