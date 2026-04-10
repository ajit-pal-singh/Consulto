import SwiftUI

struct ConsultHeaderActionsView: View {
    // Add closure or binding for action handling
    var onAddAction: (() -> Void)?
    var filterMenu: UIMenu
    
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

            ZStack {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive())
                
                UIKitMenuButton(menu: filterMenu)
                    .frame(width: 44, height: 44)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.vertical, 4)
    }
}

    #Preview {
    ZStack {
        Color.blue.edgesIgnoringSafeArea(.all)
        ConsultHeaderActionsView(filterMenu: UIMenu())
    }
}
