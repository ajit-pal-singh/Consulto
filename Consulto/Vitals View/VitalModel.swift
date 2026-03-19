import Foundation
import UIKit
import SwiftUI

enum ChartType {
    case line
    case rangeBar
    case baselineBar
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let day: String
    let value: Double?
    let minValue: Double?
    let maxValue: Double?
    
    // For Line Chart
    init(day: String, value: Double) {
        self.day = day; self.value = value; self.minValue = nil; self.maxValue = nil
    }
    // For Range Chart
    init(day: String, min: Double, max: Double) {
        self.day = day; self.value = nil; self.minValue = min; self.maxValue = max
    }
}

struct VitalReading {
    let title: String
    let value: String
    let unit: String
    let subtitle: String
    let iconImage: UIImage?
    let iconTint: UIColor
    let chartType: ChartType
    let chartColor: Color
    let chartData: [ChartDataPoint]
    var baselineValue: Double? = nil
}

class VitalData {
    static func generateMockData() -> [VitalReading] {
        return [
            VitalReading(
                title: "Heart Rate", value: "72", unit: "bpm", subtitle: "Resting Rate",
                iconImage: UIImage(named: "heart Symbol"), iconTint: UIColor(hex: "#CC1111"), chartType: .line, chartColor: .red,
                chartData: [
                    ChartDataPoint(day: "M", value: 71), ChartDataPoint(day: "T", value: 72),
                    ChartDataPoint(day: "W", value: 70), ChartDataPoint(day: "T", value: 72),
                    ChartDataPoint(day: "F", value: 71), ChartDataPoint(day: "S", value: 73),
                    ChartDataPoint(day: "S", value: 71)
                ]
            ),
            VitalReading(
                title: "Blood Pressure", value: "112/96", unit: "mmHg", subtitle: "Stable Range",
                iconImage: UIImage(named: "Blood Symbol"), iconTint: UIColor(hex: "#D94647"), chartType: .rangeBar, chartColor: .red,
                chartData: [
                    ChartDataPoint(day: "M", min: 80, max: 120), ChartDataPoint(day: "T", min: 85, max: 115),
                    ChartDataPoint(day: "W", min: 82, max: 118), ChartDataPoint(day: "T", min: 80, max: 115),
                    ChartDataPoint(day: "F", min: 85, max: 118), ChartDataPoint(day: "S", min: 82, max: 116),
                    ChartDataPoint(day: "S", min: 80, max: 115)
                ]
            ),
            VitalReading(
                title: "Blood Glucose", value: "98", unit: "mg/dL", subtitle: "Fasting Glucose",
                iconImage: UIImage(named: "Glucometer"), iconTint: UIColor(hex: "#1163C7"), chartType: .line, chartColor: .blue,
                chartData: [
                    ChartDataPoint(day: "M", value: 93), ChartDataPoint(day: "T", value: 95),
                    ChartDataPoint(day: "W", value: 94), ChartDataPoint(day: "T", value: 96),
                    ChartDataPoint(day: "F", value: 93), ChartDataPoint(day: "S", value: 95),
                    ChartDataPoint(day: "S", value: 94)
                ]
            ),
            VitalReading(
                title: "Body Weight", value: "80.6", unit: "kg", subtitle: "Stable Weight",
                iconImage: UIImage(named: "Body Symbol"), iconTint: UIColor(hex: "#719F50"), chartType: .baselineBar, chartColor: .green,
                chartData: [
                    ChartDataPoint(day: "M", value: 80.6),
                    ChartDataPoint(day: "T", value: 81.2),
                    ChartDataPoint(day: "W", value: 80.8),
                    ChartDataPoint(day: "T", value: 80.2),
                    ChartDataPoint(day: "F", value: 79.7), // below 80
                    ChartDataPoint(day: "S", value: 79.5), // below 80
                    ChartDataPoint(day: "S", value: 80.6)
                ],
                baselineValue: 80.0 // Last Sunday's Data
            )
        ]
    }
}

// MARK: - UIColor Hex Extension
extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}
