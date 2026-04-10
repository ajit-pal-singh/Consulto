import SwiftUI

struct VitalsHeaderActionsView: View {
    var onAddAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
    
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
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.vertical, 4)
        .ignoresSafeArea()
    }
}

#Preview {
    ZStack {
        Color.blue.edgesIgnoringSafeArea(.all)
        VitalsHeaderActionsView()
    }
}
