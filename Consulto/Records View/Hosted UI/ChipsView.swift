import SwiftUI

struct ChipsView: View {
    // Observable Object for State
    @ObservedObject var viewModel: FilterViewModel
    
    // Data (matches Model RecordTypes + "All")
    let filters = ["All", "Prescription", "Lab Report", "Discharge", "Scan", "Other"]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(filters, id: \.self) { filter in
                    ChipButton(title: filter, isSelected: viewModel.selectedFilter == filter) {
                        // Action: Update selection
                        withAnimation {
                            viewModel.selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
        }
        .scrollClipDisabled()
    }
}

struct ChipButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .tint(isSelected ? .white : .black)
                .animation(nil, value: isSelected)
        }
        .glassEffect(
            isSelected 
            ? .clear.tint(Color(getColor(for: title)).opacity(0.85))
            : .regular
        )
    }
    
    func getColor(for filter: String) -> UIColor {
        switch filter {
        case "All": return .black
        case "Prescription": return UIColor(named: "PrescriptionColor") ?? .systemBlue
        case "Lab Report": return UIColor(named: "ReportColor") ?? .systemRed
        case "Discharge": return UIColor(named: "DischargeSummaryColor") ?? .systemYellow
        case "Scan": return UIColor(named: "ScanColor") ?? .systemPurple
        case "Other": return .systemGray
        default: return .systemGray
        }
    }
}
