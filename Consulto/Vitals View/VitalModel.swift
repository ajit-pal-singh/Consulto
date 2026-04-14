import Foundation
import UIKit
import SwiftUI

enum ChartType {
    case line
    case rangeBar
    case baselineBar
}

enum BloodGlucoseType: String, CaseIterable {
    case fasting  = "Fasting"
    case random   = "Random"
    case afterMeal = "After meal"

    var subtitleText: String {
        "\(rawValue) Glucose"
    }

    var targetRange: (min: Double, max: Double) {
        switch self {
        case .fasting:   return (70, 100)
        case .random:    return (70, 140)
        case .afterMeal: return (90, 140)
        }
    }

    static func from(subtitle: String?) -> BloodGlucoseType {
        guard let subtitle = subtitle?.lowercased() else { return .fasting }
        if subtitle.contains("after meal") { return .afterMeal }
        if subtitle.contains("random") { return .random }
        return .fasting
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let day: String
    let value: Double?
    let minValue: Double?
    let maxValue: Double?
    let baselineValue: Double?
    let hourOfDay: Double?
    let fullDate: String?
    let glucoseType: String?

    init(day: String, value: Double, fullDate: String? = nil, glucoseType: String? = nil, baselineValue: Double? = nil) {
        self.day = day; self.value = value; self.minValue = nil; self.maxValue = nil; self.baselineValue = baselineValue; self.hourOfDay = nil; self.fullDate = fullDate; self.glucoseType = glucoseType
    }
    init(day: String, value: Double?, fullDate: String? = nil, glucoseType: String? = nil, baselineValue: Double? = nil) {
        self.day = day; self.value = value; self.minValue = nil; self.maxValue = nil; self.baselineValue = baselineValue; self.hourOfDay = nil; self.fullDate = fullDate; self.glucoseType = glucoseType
    }
    init(day: String, min: Double, max: Double, fullDate: String? = nil, glucoseType: String? = nil, baselineValue: Double? = nil) {
        self.day = day; self.value = nil; self.minValue = min; self.maxValue = max; self.baselineValue = baselineValue; self.hourOfDay = nil; self.fullDate = fullDate; self.glucoseType = glucoseType
    }
    init(day: String, min: Double?, max: Double?, fullDate: String? = nil, glucoseType: String? = nil, baselineValue: Double? = nil) {
        self.day = day; self.value = nil; self.minValue = min; self.maxValue = max; self.baselineValue = baselineValue; self.hourOfDay = nil; self.fullDate = fullDate; self.glucoseType = glucoseType
    }
    init(hour: Double, value: Double, fullDate: String? = nil, glucoseType: String? = nil, baselineValue: Double? = nil) {
        var h = Int(hour)
        var mins = Int(round((hour - Double(h)) * 60))
        if mins == 60 { mins = 0; h += 1 }
        if h == 24 { h = 0 }
        let ampm = h < 12 ? "AM" : "PM"
        let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        self.day = mins > 0 ? String(format: "%d:%02d%@", h12, mins, ampm) : "\(h12)\(ampm)"
        self.value = value; self.minValue = nil; self.maxValue = nil; self.baselineValue = baselineValue; self.hourOfDay = hour; self.fullDate = fullDate; self.glucoseType = glucoseType
    }
    init(hour: Double, min: Double, max: Double, fullDate: String? = nil, glucoseType: String? = nil, baselineValue: Double? = nil) {
        var h = Int(hour)
        var mins = Int(round((hour - Double(h)) * 60))
        if mins == 60 { mins = 0; h += 1 }
        if h == 24 { h = 0 }
        let ampm = h < 12 ? "AM" : "PM"
        let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        self.day = mins > 0 ? String(format: "%d:%02d%@", h12, mins, ampm) : "\(h12)\(ampm)"
        self.value = nil; self.minValue = min; self.maxValue = max; self.baselineValue = baselineValue; self.hourOfDay = hour; self.fullDate = fullDate; self.glucoseType = glucoseType
    }
}

struct VitalReading {
    let title: String
    let value: String
    let unit: String
    let subtitle: String
    let iconImage: UIImage?
    let detailIconImage: UIImage?
    let iconTint: UIColor
    let chartType: ChartType
    let chartColor: Color
    let chartData: [ChartDataPoint]
    let weeklyChartData: [ChartDataPoint]
    let monthlyChartData: [ChartDataPoint]
    let hourlyChartData: [ChartDataPoint]
    let persistedHourlyChartData: [ChartDataPoint]
    var baselineValue: Double? = nil
}

struct VitalReadingDTO: Codable {
    let title: String
    let value: String
    let unit: String
    let subtitle: String
    let iconImageName: String
    let detailIconImageName: String
    let iconTintHex: String
    let chartType: String
    let chartColor: String
    let chartData: [ChartDataPointDTO]
    let weeklyChartData: [ChartDataPointDTO]?
    let monthlyChartData: [ChartDataPointDTO]?
    let hourlyChartData: [HourlyDataPointDTO]?
    let persistedHourlyChartData: [HourlyDataPointDTO]?
    let baselineValue: Double?
}

struct VitalReadingsPayload: Codable {
    let readings: [VitalReadingDTO]
}

struct ChartDataPointDTO: Codable {
    let day: String
    let value: Double?
    let minValue: Double?
    let maxValue: Double?
    let baselineValue: Double?
}

struct HourlyDataPointDTO: Codable {
    let hour: Double
    let value: Double?
    let minValue: Double?
    let maxValue: Double?
    let dateString: String
    let glucoseType: String?
    let baselineValue: Double?
}

class VitalData {
    static func decodeDTOs(from data: Data) throws -> [VitalReadingDTO] {
        let decoder = JSONDecoder()
        if let payload = try? decoder.decode(VitalReadingsPayload.self, from: data) {
            return payload.readings
        }
        return try decoder.decode([VitalReadingDTO].self, from: data)
    }
}

extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        self.init(
            red:   CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8)  / 255.0,
            blue:  CGFloat(rgb & 0x0000FF)          / 255.0,
            alpha: 1.0
        )
    }
}
