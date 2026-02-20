import SwiftUI

struct ConsultHeaderActionsView: View {
    // Add closure or binding for action handling
    var onAddAction: (() -> Void)?
    
    var body: some View {
        HStack {
            Spacer() // Push to the right
            
            // Add Button
            Button(action: {
                onAddAction?()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive())
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ZStack {
        Color.blue.edgesIgnoringSafeArea(.all)
        ConsultHeaderActionsView()
    }
}
