import Foundation
import PDFKit
import UIKit

final class HealthRecordStore {
    static let shared = HealthRecordStore()

    private let fileManager = FileManager.default
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let seededUserID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    private init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadRecords() throws -> [HealthRecord] {
        try ensureWritableStoreExists()

        do {
            let data = try Data(contentsOf: recordsFileURL())
            return try decoder.decode([HealthRecord].self, from: data)
        } catch {
            let seedRecords = try loadSeedRecords()
            try persist(seedRecords)
            return seedRecords
        }
    }

    @discardableResult
    func addRecord(
        title: String,
        recordType: RecordType,
        healthFacilityName: String?,
        summary: String?,
        documentDate: Date?,
        attachments: [RecordAttachmentDraft]
    ) throws -> HealthRecord {
        let recordID = UUID()
        let files = try saveAttachments(attachments, for: recordID)

        var records = try loadRecords()
        let newRecord = HealthRecord(
            id: recordID,
            userID: seededUserID,
            title: title,
            recordType: recordType,
            healthFacilityName: healthFacilityName,
            summary: summary,
            dateAdded: Date(),
            documentDate: documentDate,
            files: files,
            extractedData: nil
        )
        records.insert(newRecord, at: 0)
        try persist(records)
        return newRecord
    }
    
    // Updates an existing record in place
    func updateRecord(_ updatedRecord: HealthRecord) throws {
        var records = try loadRecords()
        guard let index = records.firstIndex(where: { $0.id == updatedRecord.id }) else { return }
        
        records[index] = updatedRecord
        try persist(records)
    }

    func deleteRecord(id: UUID) throws {
        var records = try loadRecords()
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }

        records.remove(at: index)
        try persist(records)

        let recordFolder = recordFilesDirectory().appendingPathComponent(id.uuidString, isDirectory: true)
        if fileManager.fileExists(atPath: recordFolder.path) {
            try fileManager.removeItem(at: recordFolder)
        }
    }

    // MARK: - Asset path helper
    // Seed records use "asset:imageName" convention to reference images bundled in Assets.xcassets
    private func isAssetPath(_ path: String) -> Bool {
        return path.hasPrefix("asset:")
    }

    private func assetName(from path: String) -> String {
        return String(path.dropFirst("asset:".count))
    }

    func previewImage(for record: HealthRecord) -> UIImage? {
        if let imageFile = record.files.first(where: { $0.fileType == .image }) {
            // Check if this is a bundled asset image (from seed data)
            if isAssetPath(imageFile.filePath) {
                return UIImage(named: assetName(from: imageFile.filePath))
            }
            // Otherwise load from the Documents directory (user-added record)
            if let url = try? absoluteURL(forRelativePath: imageFile.filePath),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }

        if let pdfFile = record.files.first(where: { $0.fileType == .pdf }),
           let url = try? absoluteURL(forRelativePath: pdfFile.filePath) {
            return previewImage(forPDFAt: url)
        }

        return nil
    }
    
    // Fetches all images associated with the record (resolves the single-image bug)
    func allImages(for record: HealthRecord) -> [UIImage] {
        var images: [UIImage] = []
        
        for file in record.files {
            if file.fileType == .image {
                // Check for bundled asset image first
                if isAssetPath(file.filePath),
                   let image = UIImage(named: assetName(from: file.filePath)) {
                    images.append(image)
                } else if let url = try? absoluteURL(forRelativePath: file.filePath),
                          let image = UIImage(contentsOfFile: url.path) {
                    images.append(image)
                }
            } else if file.fileType == .pdf,
                      let url = try? absoluteURL(forRelativePath: file.filePath),
                      let image = previewImage(forPDFAt: url) {
                images.append(image)
            }
        }
        
        return images
    }
    
    // Extracted absolute URL exposed for QuickLook native previewing
    func url(for file: RecordFile) -> URL? {
        // Handle bundled asset images by saving them to a temporary URL for QuickLook
        if isAssetPath(file.filePath) {
            let name = assetName(from: file.filePath)
            guard let image = UIImage(named: name),
                  let data = image.jpegData(compressionQuality: 1.0) else { return nil }
            
            let tempURL = fileManager.temporaryDirectory.appendingPathComponent("\(name).jpg")
            do {
                try data.write(to: tempURL, options: .atomic)
                return tempURL
            } catch {
                print("Failed to save temporary asset preview: \(error)")
                return nil
            }
        }
        
        return try? absoluteURL(forRelativePath: file.filePath)
    }

    private func loadSeedRecords() throws -> [HealthRecord] {
        guard let url = Bundle.main.url(forResource: "seed_records", withExtension: "json") else {
            throw NSError(domain: "HealthRecordStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing seed_records.json"])
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode([HealthRecord].self, from: data)
    }

    private func persist(_ records: [HealthRecord]) throws {
        try ensureDirectoriesExist()
        let data = try encoder.encode(records)
        try data.write(to: recordsFileURL(), options: .atomic)
    }

    private func ensureWritableStoreExists() throws {
        try ensureDirectoriesExist()
        let recordsURL = recordsFileURL()
        guard !fileManager.fileExists(atPath: recordsURL.path) else { return }

        guard let seedURL = Bundle.main.url(forResource: "seed_records", withExtension: "json") else {
            throw NSError(domain: "HealthRecordStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing seed_records.json"])
        }
        try fileManager.copyItem(at: seedURL, to: recordsURL)
    }

    private func ensureDirectoriesExist() throws {
        try fileManager.createDirectory(at: documentDirectory(), withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: recordFilesDirectory(), withIntermediateDirectories: true, attributes: nil)
    }

    private func saveAttachments(_ attachments: [RecordAttachmentDraft], for recordID: UUID) throws -> [RecordFile] {
        guard !attachments.isEmpty else { return [] }

        let recordFolder = recordFilesDirectory().appendingPathComponent(recordID.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: recordFolder, withIntermediateDirectories: true, attributes: nil)

        var savedFiles: [RecordFile] = []

        for (index, attachment) in attachments.enumerated() {
            switch attachment.fileType {
            case .image:
                if let sourceURL = attachment.fileURL {
                    let rawExtension = sourceURL.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
                    let fileExtension = rawExtension.isEmpty ? "jpg" : rawExtension.lowercased()
                    let fileName = "page-\(index + 1).\(fileExtension)"
                    let destinationURL = recordFolder.appendingPathComponent(fileName)
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                    let relativePath = "RecordFiles/\(recordID.uuidString)/\(fileName)"
                    savedFiles.append(RecordFile(filePath: relativePath, fileType: .image))
                    continue
                }

                let image = attachment.image ?? attachment.thumbnail
                let fileExtension: String
                let imageData: Data
                if let jpegData = image.jpegData(compressionQuality: 0.9) {
                    fileExtension = "jpg"
                    imageData = jpegData
                } else if let pngData = image.pngData() {
                    fileExtension = "png"
                    imageData = pngData
                } else {
                    throw NSError(domain: "HealthRecordStore", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to encode image"])
                }

                let fileName = "page-\(index + 1).\(fileExtension)"
                let fileURL = recordFolder.appendingPathComponent(fileName)

                try imageData.write(to: fileURL, options: .atomic)
                let relativePath = "RecordFiles/\(recordID.uuidString)/\(fileName)"
                savedFiles.append(RecordFile(filePath: relativePath, fileType: .image))
            case .pdf:
                guard let sourceURL = attachment.fileURL else {
                    throw NSError(domain: "HealthRecordStore", code: 4, userInfo: [NSLocalizedDescriptionKey: "Missing PDF file URL"])
                }

                let fileName = "page-\(index + 1).pdf"
                let destinationURL = recordFolder.appendingPathComponent(fileName)
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                let relativePath = "RecordFiles/\(recordID.uuidString)/\(fileName)"
                savedFiles.append(RecordFile(filePath: relativePath, fileType: .pdf))
            }
        }

        return savedFiles
    }

    private func previewImage(forPDFAt url: URL) -> UIImage? {
        guard let document = PDFDocument(url: url),
              let firstPage = document.page(at: 0) else {
            return nil
        }
        return firstPage.thumbnail(of: CGSize(width: 900, height: 1200), for: .mediaBox)
    }

    private func recordsFileURL() -> URL {
        ((try? documentDirectory()) ?? fileManager.temporaryDirectory).appendingPathComponent("records.json")
    }

    private func recordFilesDirectory() -> URL {
        ((try? documentDirectory()) ?? fileManager.temporaryDirectory).appendingPathComponent("RecordFiles", isDirectory: true)
    }

    private func documentDirectory() throws -> URL {
        try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }

    private func absoluteURL(forRelativePath path: String) throws -> URL {
        let baseURL = try documentDirectory()
        return baseURL.appendingPathComponent(path)
    }
}
