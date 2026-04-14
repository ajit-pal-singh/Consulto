import SwiftUI
import UIKit

struct HomeHeaderActionsView: View {

    var onProfileTap: (() -> Void)?

    @State private var profileImage: UIImage? = ProfileImageManager.shared.fetchImage()

    var body: some View {
        Button(action: {
            onProfileTap?()
        }) {
            if let img = profileImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                Image("DefaultProfile")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            }
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.vertical, 4)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProfileImageUpdated"))) { _ in
            profileImage = ProfileImageManager.shared.fetchImage()
        }
    }
}

#Preview {
    ZStack {
        Color.blue.ignoresSafeArea()
        HomeHeaderActionsView()
    }
}
