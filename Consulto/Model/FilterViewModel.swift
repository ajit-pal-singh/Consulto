import Foundation
import Combine

class FilterViewModel: ObservableObject {
    @Published var selectedFilter: String = "All"
}
