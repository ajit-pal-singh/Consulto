import SwiftUI

struct VitalsHeaderActionsView: View {
    // Add closure or binding for action handling if needed later
    var onAddAction: (() -> Void)?

    
    var body: some View {
        HStack(spacing: 12) {
         
            // Add Button
            Button(action: {
                // Action
                onAddAction?()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain) // Remove default button tap style
            .glassEffect(.regular.interactive()) // The requested modifier
        }
        .frame(maxWidth: .infinity, alignment: .trailing) // Align content to the right
        .padding(.vertical, 4) // Breathing room
        .ignoresSafeArea() // Prevent UIHostingController from adding safe area margin
    }
}

// Preview to verify design
#Preview {
    ZStack {
        Color.blue.edgesIgnoringSafeArea(.all)
        VitalsHeaderActionsView()
    }
}
