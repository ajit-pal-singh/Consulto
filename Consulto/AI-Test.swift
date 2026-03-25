import Foundation
import FoundationModels
import Playgrounds

@Generable
struct FormDataExtractionTest {
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

private func displayRecordType(_ type: RecordType?) -> String {
    guard let type else { return "" }
    switch type {
    case .prescription: return "Prescription"
    case .labReport: return "Lab Report"
    case .scan: return "Scan"
    case .dischargeSummary: return "Discharge Summary"
    case .other: return "Other"
    }
}

#Playground {
    
    
    // Simulate messy OCR output
    let rawOCRText = """
    3rd KM, JANSATH ROAD, MUZAFFARNAGAR 254D01
   * PIN: U831100L1996PTC079982
   ardhman
   TRAUMA & LAPAROSCOPY CENTRE PVT. LTD.
   UHID : VH-50366/2025
   Date : 08-Dec-2025
   Time: 10:33:46 AM
   Name : Mrs. SANGEETA MITTAL 55Y 4M 7D / Female
   Mobile: 9927818922 (Previous Visit: NA)
   Address : AGARWAL COLONY, LAKSAR, HARIDWAR UTTARAKHAND
   BP(mmHg): 133/74 SPO_(%): 79
   Pulse(bpm): 72
   CHIEF COMPLAINTS: TAILBONE PAIN X 10 DAYS
   B/L (R>L) HEEL PAIN X 3 MONTHS
   PAST HISTORY: 10 DAYS OLD INJURY
   MEDICAL ILLNESS • HTN 2
   INVESTIGATION FINDINGS : X-RAY SHOWS COCCYX ANGULATION, HEEL SPUR
   Frequency
   S.No.
   Medicine
   1.
   SACHET D3 BEST SACHET
   2.
   TAB RABEKIND 20
   3.
   TAB VETORI 90
   4.
   TAB MYOTOP SR 450
   5.
   TAB TROYCOBAL NT 1/2
   DRUG ALLERGY: NIL
   INSTRUCTIONS) : AVOID SITTING FOR ONE MONTH
   NO 2 WHEELER FOR 3 MONTHS
   WEEKLY
   1-0-0
   1-040
   0-0-1
   0-0-1
   SOFT FOOTWEAR (SHOES AND SLIPPER)
   SKECHERS (ADDA
   SILICON HEEL IN SHOES
   HOT FOMENTATION 30 - 30 MINUTES
   Dr. Mukesh Jain
   BONGULTANT ORTHOPAEDIC SURGEON
   Dr. Anubhav Jain
   CONBULTANT ORTHOPAEDIC &
   JOINT REFLACEMENT SURGEON
   Dr. Siddhant Jain
   TRALINA & ARTHROSCOPY SURGEON
   Welight: (kig): 66
   Duration
   4 WEEKS
   30 DAYS
   30 DAYS
   AFTER DINNER
   Please come afte
   30
   ... days.
   DE ANUBHAY JAIN
   C(M.S (ORTHO))
   Printed on: 08-Dec-2025 11:40:29 AM
   For Problems: @ dranubhav86@gmail.com
   For Appoiniment
   lopovardhmanhospitel@gmail.com
   3rd Km., Jansath Road, Muzaffamagar-251001 (UP)
   Reg Office: G208, Defence Colony, New Deihi-110024, India
   www.vardhmanhospital.com
   1830803084/
   7830803086/ 9219416543
   OPD Registration: 3PM. 106 PM. 8219456235
   Saturday & Sunday Closed 
"""
            
        do {
            let session = LanguageModelSession()
            
            // Keep the same safety margin as the app implementation
            let safeString = String(rawOCRText.prefix(12000))
            
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
            
            let response = try await session.respond(to: prompt, generating: FormDataExtractionTest.self)
            print(response)

            let extraction = response.content
            
        } catch {
            print("Error encountered: \(error)")
        }
    
    
}
