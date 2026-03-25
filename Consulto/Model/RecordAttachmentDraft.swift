import UIKit

struct RecordAttachmentDraft {
    let fileType: FileType
    let thumbnail: UIImage
    let image: UIImage?
    let fileURL: URL?

    static func image(_ image: UIImage, fileURL: URL? = nil) -> RecordAttachmentDraft {
        RecordAttachmentDraft(fileType: .image, thumbnail: image, image: image, fileURL: fileURL)
    }

    static func pdf(url: URL, thumbnail: UIImage) -> RecordAttachmentDraft {
        RecordAttachmentDraft(fileType: .pdf, thumbnail: thumbnail, image: nil, fileURL: url)
    }
}
