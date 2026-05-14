import Foundation
import PDFKit
import UIKit

final class HealthRecordStore {
    static let shared = HealthRecordStore()

    private let fileManager = FileManager.default
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

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
            let records = try decoder.decode([HealthRecord].self, from: data)
            let cleanedRecords = records.filter { !isLegacySeedRecord($0) }
            if cleanedRecords.count != records.count {
                try persist(cleanedRecords)
            }
            return cleanedRecords
        } catch {
            try persist([])
            return []
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
            userID: UserProfileStore.shared.current.id,
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

    func previewImage(for record: HealthRecord) -> UIImage? {
        if let imageFile = record.files.first(where: { $0.fileType == .image }) {
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
                if let url = try? absoluteURL(forRelativePath: file.filePath),
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
        return try? absoluteURL(forRelativePath: file.filePath)
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

        try persist([])
    }

    private func isLegacySeedRecord(_ record: HealthRecord) -> Bool {
        record.files.contains { $0.filePath.hasPrefix("asset:") }
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
