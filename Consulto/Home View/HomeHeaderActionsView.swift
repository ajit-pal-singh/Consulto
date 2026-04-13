import SwiftUI

struct HomeHeaderActionsView: View {

    var onProfileTap: (() -> Void)?

    var body: some View {
        Button(action: {
            onProfileTap?()
        }) {
            Image("DefaultProfile")
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.vertical, 4)
    }
}

#Preview {
    ZStack {
        Color.blue.ignoresSafeArea()
        HomeHeaderActionsView()
    }
}
