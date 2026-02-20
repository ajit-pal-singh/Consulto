import SwiftUI
import Combine
import Photos
import PhotosUI

struct AttachmentPlatterView: View {
    @StateObject private var photoManager = PhotoManager()
    
    var onCameraTap: (() -> Void)?
    var onGalleryTap: (() -> Void)?
    var onDocumentTap: (() -> Void)?
    var onDismiss: (() -> Void)? // To handle drag down potentially
    
    var body: some View {
        VStack(spacing: 20) {
            // Grabber
            Capsule()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
            
            // Header & ALL Photos Button
            HStack {
                Text("Images")
                    .font(.system(size: 18, weight: .medium))
                
                Spacer()
                
                Button("All Photos") {
                    onGalleryTap?()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 20)
            
            // Photo Grid Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // 1. Camera Button
                    Button(action: {
                        onCameraTap?()
                    }) {
                        VStack {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.primary)
                        }
                        .frame(width: 100, height: 100)
                        .background(.black.opacity(0.05))
                        .cornerRadius(12)
                    }
                    
                    // 2. Recent Photos
                    ForEach(photoManager.recentAssets, id: \.localIdentifier) { asset in
                        PhotoThumbnailView(asset: asset)
                            .frame(width: 100, height: 100)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 100)
            
            // Separator
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 20)
            
            // Document Selection Row
            Button(action: {
                onDocumentTap?()
            }) {
                HStack(spacing: 16) {
                    Image(systemName: "doc") // Document Icon
                        .font(.system(size: 24))
                        .foregroundColor(.black)
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Select File")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Choose record e-PDF")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            
        }
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 55, bottomTrailingRadius: 55, topTrailingRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            photoManager.fetchRecentPhotos()
        }
    }
}

// Helper for Specific Corner Radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Photo Manager to Fetch Recent Images
class PhotoManager: ObservableObject {
    @Published var recentAssets: [PHAsset] = []
    
    func fetchRecentPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 9 // Limit to 9 + 1 Camera = 10 items
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        
        DispatchQueue.main.async {
            self.recentAssets = assets
        }
    }
}

// MARK: - Photo Thumbnail View
struct PhotoThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage? = nil
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.3)
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        
        manager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: options) { result, _ in
            self.image = result
        }
    }
}
