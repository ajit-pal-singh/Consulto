import Foundation
import UIKit
import Vision
import FoundationModels
import PDFKit

@Generable
struct FormDataExtraction {
    @Guide(description: "Determine if the text is a medical document (like a prescription, discharge summary, or lab report) or simply irrelevant text. Check the entire text for patient notes, diagnosis, or medicines. Return true if there is any clinical context.")
    var isMedicalRecord: Bool
    
    @Guide(description: "CRITICAL: Do NOT write generic terms like 'Prescription', 'Lab Report', 'Scan', or 'Discharge Summary'. You MUST extract the specific entity: For Prescriptions = Doctor's Name. For Lab Reports = Test Name. For Scans = Scan Type (e.g., MRI Brain). For Discharge Summaries = Main Medical Issue/Procedure.")
    var title: String?
    
    @Guide(description: "The name of the hospital, clinic, lab, or facility.")
    var facilityName: String?
    
    @Guide(description: "The date the record was issued in dd-MM-yyyy format, or nil if none found.")
    var dateString: String? 

    @Guide(description: "The record type. MUST be exactly one of these enum cases: prescription, labReport, scan, dischargeSummary, other.")
    var recordType: RecordType?
    
    @Guide(description: "A solid paragraph summarizing the clinical notes, diagnosis, chief complaints, and findings. Focus heavily on medical content. If none exist, describe the document.")
    var summary: String?
}

class MedicalIntelligenceService {
    static let shared = MedicalIntelligenceService()
    
    private init() {}
    
    /// Parses the priority queue of documents (PDF first, images last) ensuring it stays under 12,000 characters to fit flawlessly inside the Apple Foundation Model limits.
    func extractData(from imageUploads: [UIImage], pdfUploads: [URL] = []) async throws -> FormDataExtraction? {
        // 1. Let the system gracefully handle availability via try await session.respond catching.
        
        // 2. Safely extract raw text from up to 3 prioritized assets
        let rawTranscript = await Task.detached {
            return await self.extractSafeTranscript(images: imageUploads, pdfs: pdfUploads)
        }.value
        
        // Limit to roughly 12,000 chars for extreme safety margin to ensure no context window crashes
        let safeString = String(rawTranscript.prefix(12000))
        
        // 3. Prepare the Foundation Model
        let session = LanguageModelSession()
        
        let prompt = """
        You are an expert clinical coding and parsing assistant.
        You must carefully analyze the entire raw text extracted from a user's document to synthesize the clinical data.
        Crucially, look past headers and contact information to find the actual medical context. Even if the text starts with a business listing, scan to the bottom for complaints, medicines, or medical parameters (like BP and Weight) before determining if it's a medical record!
        
        CRITICAL RULES:
        1. If the text contains no valid clinical or medical information, return 'false' for the medical record check and make all remaining fields nil.
        2. For the 'title' field, NEVER output generic words like "Prescription", "Report", "Scan", or "Summary". Instead, extract exactly:
           - Prescription: The actual Doctor's Name.
           - Lab Report: The specific Test Name.
           - Scan: The exact Scan Type (e.g., MRI Brain, Chest X-Ray).
           - Discharge Summary: The primary Diagnosis or Procedure.
        
        Transcript Data:
        \"\"\"
        \(safeString)
        \"\"\"
        """
        
        // 4. Guided Generation Execution On-Device!
        let response = try await session.respond(to: prompt, generating: FormDataExtraction.self)
        
        let extraction = response.content
        
        if extraction.isMedicalRecord {
            return extraction
        } else {
            return nil // Model safely detected irrelevant content (e.g., dogs/screenshots)
        }
    }
    
    /// Strictly limits the total extractions to 3 files, prioritizing PDFs dynamically
    private func extractSafeTranscript(images: [UIImage], pdfs: [URL]) async -> String {
        var transcript = ""
        var itemsParsed = 0
        let parsingLimit = 3
        
        // --- 1. ALWAYS EXAMINE THE PDF FIRST ---
        for url in pdfs {
            if itemsParsed >= parsingLimit { break }
            guard let document = PDFDocument(url: url) else { continue }
            
            let totalPages = document.pageCount
            let pagesToScan = [0, 1, totalPages - 1].filter { $0 < totalPages && $0 >= 0 } // Safely grab page 1, 2, and the Last Page
            let uniquePages = Array(Set(pagesToScan)).sorted() // Remove duplicates if it's a 1-page PDF
            
            for pageIndex in uniquePages {
                if itemsParsed >= parsingLimit { break }
                guard let page = document.page(at: pageIndex) else { continue }
                
                // Attempt native text extraction
                if let text = page.string, text.trimmingCharacters(in: .whitespacesAndNewlines).count > 50 {
                    transcript += " [PDF Page \(pageIndex + 1)]: \(text) "
                } else {
                    // Fallback to Image Vision OCR if the PDF page is actually just a scanned photo
                    let thumbnail = page.thumbnail(of: CGSize(width: 1000, height: 1000), for: .mediaBox)
                    let text = extractText(from: thumbnail)
                    transcript += " [PDF Scanned Page \(pageIndex + 1)]: \(text) "
                }
                itemsParsed += 1
            }
        }
        
        // --- 2. EXAMINE IMAGES NEXT IF QUOTA NOT MET ---
        for image in images {
            if itemsParsed >= parsingLimit { break }
            
            let text = extractText(from: image)
            transcript += " [Attached Image]: \(text) "
            
            itemsParsed += 1
        }
        
        return transcript
    }
    
    /// Standard Vision processing pipeline
    private func extractText(from image: UIImage) -> String {
        guard let cgImage = image.cgImage else { return "" }
        var recognizedText = ""
        
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else { return }
            for observation in observations {
                if let candidate = observation.topCandidates(1).first {
                    recognizedText += candidate.string + "\n"
                }
            }
        }
        request.recognitionLevel = .accurate
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Vision OCR failed.")
        }
        
        return recognizedText
    }
}
