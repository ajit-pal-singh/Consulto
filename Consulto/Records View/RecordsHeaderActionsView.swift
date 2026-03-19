import SwiftUI

struct HeaderActionsView: View {
    
    var onAddAction: (() -> Void)?
    var onFilterAction: (() -> Void)?
    
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

            Button(action: {
                onFilterAction?()
            }) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive())
            
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.vertical, 4)
    }
}

#Preview {
    ZStack {
        Color.blue.edgesIgnoringSafeArea(.all)
        HeaderActionsView()
    }
}
