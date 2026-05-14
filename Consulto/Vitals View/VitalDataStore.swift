import Foundation
import UIKit
import SwiftUI

class VitalDataStore {

    static let shared = VitalDataStore()
    private init() {}

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var storeURL: URL {
        documentsURL.appendingPathComponent("vitalsData_v15.json")
    }

    func loadDTOs() -> [VitalReadingDTO] {
        if !FileManager.default.fileExists(atPath: storeURL.path) {
            let defaultDTOs = Self.emptyDefaultDTOs()
            persist(defaultDTOs)
            return processDTOs(defaultDTOs)
        }

        return processPersistedDTOs()
    }

    private func processDTOs(_ dtos: [VitalReadingDTO]) -> [VitalReadingDTO] {
        let cal = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "dd-MM-yyyy"

        return dtos.map { dto in
            Self.normalizedDTO(dto, cal: cal, df: df)
        }
    }

    private func processPersistedDTOs() -> [VitalReadingDTO] {
        if let data = try? Data(contentsOf: storeURL),
           let dtos = try? VitalData.decodeDTOs(from: data) {
            return processDTOs(dtos)
        }

        print("VitalDataStore: Documents store failed, recreating empty vitals")
        let defaultDTOs = Self.emptyDefaultDTOs()
        persist(defaultDTOs)
        return processDTOs(defaultDTOs)
    }

    func loadReadings() -> [VitalReading] {
        return Self.orderedReadings(loadDTOs().map { Self.convert($0) })
    }

    func saveNewPoint(forTitle title: String, value: String, day: String,
                      minValue: Double? = nil, maxValue: Double? = nil,
                      recordedAt date: Date = Date(),
                      subtitleOverride: String? = nil,
                      glucoseType: String? = nil,
                      heartRateSource: String? = nil) {
        var dtos = loadDTOs()

        guard let idx = dtos.firstIndex(where: { $0.title == title }) else {
            print("VitalDataStore: title '\(title)' not found"); return
        }

        let dto = dtos[idx]
        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        let hourFractional = Double(h) + Double(m) / 60.0

        let df = DateFormatter(); df.dateFormat = "dd-MM-yyyy"
        let dateStr = df.string(from: date)

        let hourlyPoint: HourlyDataPointDTO
        if let minV = minValue, let maxV = maxValue {
            hourlyPoint = HourlyDataPointDTO(hour: hourFractional, value: nil,
                                             minValue: minV, maxValue: maxV, dateString: dateStr,
                                             glucoseType: nil, baselineValue: nil)
        } else {
            let numVal = Double(value.replacingOccurrences(of: ",", with: "."))
            hourlyPoint = HourlyDataPointDTO(hour: hourFractional, value: numVal,
                                             minValue: nil, maxValue: nil, dateString: dateStr,
                                             glucoseType: glucoseType, baselineValue: nil,
                                             heartRateSource: heartRateSource)
        }

        var allHourlyPoints = dto.hourlyChartData ?? []
        allHourlyPoints.append(hourlyPoint)

        var userPersistedPoints = dto.persistedHourlyChartData ?? []
        userPersistedPoints.append(hourlyPoint)

        let updatedDTO = VitalReadingDTO(
            title: dto.title,
            value: dto.value,
            unit: dto.unit,
            subtitle: subtitleOverride ?? dto.subtitle,
            iconImageName: dto.iconImageName,
            detailIconImageName: dto.detailIconImageName,
            iconTintHex: dto.iconTintHex,
            chartType: dto.chartType,
            chartColor: dto.chartColor,
            chartData: dto.chartData,
            weeklyChartData: dto.weeklyChartData,
            monthlyChartData: dto.monthlyChartData,
            hourlyChartData: allHourlyPoints,
            persistedHourlyChartData: userPersistedPoints,
            baselineValue: dto.baselineValue
        )

        dtos[idx] = Self.normalizedDTO(updatedDTO, cal: cal, df: df)
        persist(dtos)
    }

    func updatePoint(title: String,
                     oldDateStr: String,
                     oldHour: Double,
                     newValue: String,
                     newDateStr: String,
                     newHour: Double,
                     newMinValue: Double? = nil,
                     newMaxValue: Double? = nil) {
        var dtos = loadDTOs()
        
        guard let idx = dtos.firstIndex(where: { $0.title == title }) else { return }
        
        let dto = dtos[idx]
        
        let updateArray = { (arr: [HourlyDataPointDTO]?) -> [HourlyDataPointDTO] in
            guard var points = arr else { return [] }
            if let pIdx = points.firstIndex(where: { $0.dateString == oldDateStr && abs($0.hour - oldHour) < 0.001 }) {
                let p = points[pIdx]
                let isRange = newMinValue != nil && newMaxValue != nil
                points[pIdx] = HourlyDataPointDTO(
                    hour: newHour,
                    value: isRange ? nil : Double(newValue.replacingOccurrences(of: ",", with: ".")),
                    minValue: newMinValue,
                    maxValue: newMaxValue,
                    dateString: newDateStr,
                    glucoseType: p.glucoseType,
                    baselineValue: p.baselineValue,
                    heartRateSource: p.heartRateSource
                )
            }
            return points
        }
        
        let updatedHourly = updateArray(dto.hourlyChartData)
        let updatedPersisted = updateArray(dto.persistedHourlyChartData)
        
        let updatedDTO = VitalReadingDTO(
            title: dto.title,
            value: dto.value,
            unit: dto.unit,
            subtitle: dto.subtitle,
            iconImageName: dto.iconImageName,
            detailIconImageName: dto.detailIconImageName,
            iconTintHex: dto.iconTintHex,
            chartType: dto.chartType,
            chartColor: dto.chartColor,
            chartData: dto.chartData,
            weeklyChartData: dto.weeklyChartData,
            monthlyChartData: dto.monthlyChartData,
            hourlyChartData: updatedHourly,
            persistedHourlyChartData: updatedPersisted,
            baselineValue: dto.baselineValue
        )
        
        let cal = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "dd-MM-yyyy"
        
        dtos[idx] = Self.normalizedDTO(updatedDTO, cal: cal, df: df)
        persist(dtos)
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .vitalDataDidUpdate, object: nil, userInfo: ["title": title])
        }
    }

    func deletePoint(title: String, dateStr: String, hour: Double) {
        var dtos = loadDTOs()

        guard let idx = dtos.firstIndex(where: { $0.title == title }) else { return }

        let dto = dtos[idx]

        let removeFromArray = { (arr: [HourlyDataPointDTO]?) -> [HourlyDataPointDTO] in
            guard let points = arr else { return [] }
            return points.filter { !($0.dateString == dateStr && abs($0.hour - hour) < 0.001) }
        }

        let updatedHourly    = removeFromArray(dto.hourlyChartData)
        let updatedPersisted = removeFromArray(dto.persistedHourlyChartData)

        let updatedDTO = VitalReadingDTO(
            title: dto.title,
            value: dto.value,
            unit: dto.unit,
            subtitle: dto.subtitle,
            iconImageName: dto.iconImageName,
            detailIconImageName: dto.detailIconImageName,
            iconTintHex: dto.iconTintHex,
            chartType: dto.chartType,
            chartColor: dto.chartColor,
            chartData: dto.chartData,
            weeklyChartData: dto.weeklyChartData,
            monthlyChartData: dto.monthlyChartData,
            hourlyChartData: updatedHourly,
            persistedHourlyChartData: updatedPersisted,
            baselineValue: dto.baselineValue
        )

        let cal = Calendar.current
        let df  = DateFormatter()
        df.dateFormat = "dd-MM-yyyy"

        dtos[idx] = Self.normalizedDTO(updatedDTO, cal: cal, df: df)
        persist(dtos)

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .vitalDataDidUpdate, object: nil, userInfo: ["title": title])
        }
    }

    private static func normalizedDTO(_ dto: VitalReadingDTO, cal: Calendar, df: DateFormatter) -> VitalReadingDTO {
        switch dto.title {
        case "Heart Rate":     return normalizedHeartRateDTO(dto, cal: cal, df: df)
        case "Blood Pressure": return normalizedBloodPressureDTO(dto, cal: cal, df: df)
        case "Blood Glucose":  return normalizedBloodGlucoseDTO(dto, cal: cal, df: df)
        case "Body Weight":    return normalizedBodyWeightDTO(dto, cal: cal, df: df)
        default:               return dto
        }
    }

    private static func sortedHourly(_ existing: [HourlyDataPointDTO], df: DateFormatter) -> [HourlyDataPointDTO] {
        existing.sorted { lhs, rhs in
            let lhsDate = df.date(from: lhs.dateString) ?? .distantPast
            let rhsDate = df.date(from: rhs.dateString) ?? .distantPast
            if lhsDate == rhsDate { return lhs.hour < rhs.hour }
            return lhsDate < rhsDate
        }
    }

    private static func normalizedHeartRateDTO(_ dto: VitalReadingDTO, cal: Calendar, df: DateFormatter) -> VitalReadingDTO {
        let preferredSource  = HeartRateSourceType.from(subtitle: dto.subtitle)
        let hourly           = sortedHourly(dto.hourlyChartData ?? [], df: df)
        let filteredHourly   = hourly.filter { heartRateSourceString(for: $0) == preferredSource.rawValue }
        let sourceHourly     = filteredHourly.isEmpty ? hourly : filteredHourly

        let daily   = buildDailyPoints(from: sourceHourly, hasRange: false, title: dto.title, cal: cal, df: df)
        let weekly  = buildWeeklyPoints(from: sourceHourly, hasRange: false, title: dto.title, cal: cal, df: df)
        let monthly = buildMonthlyPoints(from: sourceHourly, hasRange: false, title: dto.title, cal: cal, df: df)
        let latestValue = sourceHourly.last?.value

        return VitalReadingDTO(
            title: dto.title, value: latestValue.map(formatValue) ?? dto.value,
            unit: dto.unit, subtitle: preferredSource.subtitleText,
            iconImageName: dto.iconImageName, detailIconImageName: dto.detailIconImageName,
            iconTintHex: dto.iconTintHex, chartType: dto.chartType, chartColor: dto.chartColor,
            chartData: daily, weeklyChartData: weekly, monthlyChartData: monthly,
            hourlyChartData: hourly,
            persistedHourlyChartData: dto.persistedHourlyChartData ?? dto.hourlyChartData ?? [],
            baselineValue: dto.baselineValue
        )
    }

    private static func heartRateSourceString(for point: HourlyDataPointDTO) -> String {
        point.heartRateSource ?? HeartRateSourceType.manual.rawValue
    }

    private static func normalizedBloodPressureDTO(_ dto: VitalReadingDTO, cal: Calendar, df: DateFormatter) -> VitalReadingDTO {
        let hourly  = sortedHourly(dto.hourlyChartData ?? [], df: df)
        let daily   = buildDailyPoints(from: hourly, hasRange: true, title: dto.title, cal: cal, df: df)
        let weekly  = buildWeeklyPoints(from: hourly, hasRange: true, title: dto.title, cal: cal, df: df)
        let monthly = buildMonthlyPoints(from: hourly, hasRange: true, title: dto.title, cal: cal, df: df)
        let latestMax = hourly.last?.maxValue
        let latestMin = hourly.last?.minValue

        return VitalReadingDTO(
            title: dto.title,
            value: {
                guard let latestMax, let latestMin else { return dto.value }
                return "\(Int(floor(latestMax)))/\(Int(floor(latestMin)))"
            }(),
            unit: dto.unit,
            subtitle: computeVariabilitySubtitle(for: dto.title, hourly: hourly, cal: cal, df: df) ?? dto.subtitle,
            iconImageName: dto.iconImageName, detailIconImageName: dto.detailIconImageName,
            iconTintHex: dto.iconTintHex, chartType: dto.chartType, chartColor: dto.chartColor,
            chartData: daily, weeklyChartData: weekly, monthlyChartData: monthly,
            hourlyChartData: hourly,
            persistedHourlyChartData: dto.persistedHourlyChartData ?? dto.hourlyChartData ?? [],
            baselineValue: dto.baselineValue
        )
    }

    private static func normalizedBloodGlucoseDTO(_ dto: VitalReadingDTO, cal: Calendar, df: DateFormatter) -> VitalReadingDTO {
        let preferredType  = BloodGlucoseType.from(subtitle: dto.subtitle)
        let hourly         = sortedHourly(dto.hourlyChartData ?? [], df: df)
        let filteredHourly = hourly.filter { glucoseTypeString(for: $0) == preferredType.rawValue }
        let daily          = buildDailyPoints(from: filteredHourly, hasRange: false, title: dto.title, cal: cal, df: df)
        let weekly         = buildWeeklyPoints(from: filteredHourly, hasRange: false, title: dto.title, cal: cal, df: df)
        let monthly        = buildMonthlyPoints(from: filteredHourly, hasRange: false, title: dto.title, cal: cal, df: df)
        let latestValue    = filteredHourly.last?.value ?? hourly.last?.value

        return VitalReadingDTO(
            title: dto.title, value: latestValue.map(formatValue) ?? dto.value,
            unit: dto.unit, subtitle: preferredType.subtitleText,
            iconImageName: dto.iconImageName, detailIconImageName: dto.detailIconImageName,
            iconTintHex: dto.iconTintHex, chartType: dto.chartType, chartColor: dto.chartColor,
            chartData: daily, weeklyChartData: weekly, monthlyChartData: monthly,
            hourlyChartData: hourly,
            persistedHourlyChartData: dto.persistedHourlyChartData ?? dto.hourlyChartData ?? [],
            baselineValue: dto.baselineValue
        )
    }

    private static func normalizedBodyWeightDTO(_ dto: VitalReadingDTO, cal: Calendar, df: DateFormatter) -> VitalReadingDTO {
        let hourly           = sortedHourly(dto.hourlyChartData ?? [], df: df)
        let normalizedHourly = bodyWeightHourlyWithBaseline(from: hourly, cal: cal, df: df)
        let daily            = buildBodyWeightDailyPoints(from: normalizedHourly, cal: cal, df: df)
        let weekly           = buildBodyWeightWeeklyPoints(from: normalizedHourly, cal: cal, df: df)
        let monthly          = buildBodyWeightMonthlyPoints(from: normalizedHourly, cal: cal, df: df)
        let baseline = monthly.last?.baselineValue
            ?? weekly.last?.baselineValue
            ?? normalizedHourly.last?.baselineValue
            ?? dto.baselineValue
        let latestValue = normalizedHourly.last?.value

        return VitalReadingDTO(
            title: dto.title, value: latestValue.map(formatValue) ?? dto.value,
            unit: dto.unit,
            subtitle: computeVariabilitySubtitle(for: dto.title, hourly: normalizedHourly, cal: cal, df: df) ?? dto.subtitle,
            iconImageName: dto.iconImageName, detailIconImageName: dto.detailIconImageName,
            iconTintHex: dto.iconTintHex, chartType: dto.chartType, chartColor: dto.chartColor,
            chartData: daily, weeklyChartData: weekly, monthlyChartData: monthly,
            hourlyChartData: normalizedHourly,
            persistedHourlyChartData: dto.persistedHourlyChartData ?? dto.hourlyChartData ?? [],
            baselineValue: baseline
        )
    }

    private static func computeVariabilitySubtitle(for title: String, hourly: [HourlyDataPointDTO], cal: Calendar, df: DateFormatter) -> String? {
        guard !hourly.isEmpty else { return nil }

        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let currentWeekStart = cal.date(byAdding: .day, value: -daysFromMonday, to: today)!
        let currentWeekEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: cal.date(byAdding: .day, value: 6, to: currentWeekStart)!)!
        let prevWeekStart = cal.date(byAdding: .day, value: -7, to: currentWeekStart)!
        let prevWeekEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: cal.date(byAdding: .day, value: -1, to: currentWeekStart)!)!

        var currentPoints: [HourlyDataPointDTO] = []
        var prevPoints: [HourlyDataPointDTO] = []

        for p in hourly {
            guard let date = df.date(from: p.dateString) else { continue }
            if date >= currentWeekStart && date <= currentWeekEnd {
                currentPoints.append(p)
            } else if date >= prevWeekStart && date <= prevWeekEnd {
                prevPoints.append(p)
            }
        }

        let currentSpread: Double
        let prevSpread: Double

        if title == "Blood Pressure" {
            let csys = currentPoints.compactMap(\.maxValue); let cdia = currentPoints.compactMap(\.minValue)
            let psys = prevPoints.compactMap(\.maxValue);   let pdia = prevPoints.compactMap(\.minValue)
            let csysMin = csys.min() ?? 0; let csysMax = csys.max() ?? 0
            let cdiaMin = cdia.min() ?? 0; let cdiaMax = cdia.max() ?? 0
            currentSpread = csys.isEmpty || cdia.isEmpty ? 0 : (csysMax - csysMin) + (cdiaMax - cdiaMin)
            let psysMin = psys.min() ?? 0; let psysMax = psys.max() ?? 0
            let pdiaMin = pdia.min() ?? 0; let pdiaMax = pdia.max() ?? 0
            prevSpread = psys.isEmpty || pdia.isEmpty ? 0 : (psysMax - psysMin) + (pdiaMax - pdiaMin)
        } else {
            let cvals = currentPoints.compactMap(\.value); let pvals = prevPoints.compactMap(\.value)
            let cmin = cvals.min() ?? 0; let cmax = cvals.max() ?? 0
            currentSpread = cvals.isEmpty ? 0 : cmax - cmin
            let pmin = pvals.min() ?? 0; let pmax = pvals.max() ?? 0
            prevSpread = pvals.isEmpty ? 0 : pmax - pmin
        }

        let delta = currentSpread - prevSpread
        let labelAttr = title == "Blood Pressure" ? "Pressure" : (title == "Body Weight" ? "Weight" : title)

        if prevPoints.isEmpty || abs(delta) < 0.01 { return "Stable \(labelAttr)" }
        return delta > 0 ? "Higher \(labelAttr)" : "Lower \(labelAttr)"
    }

    private static func bodyWeightHourlyWithBaseline(from hourly: [HourlyDataPointDTO], cal: Calendar, df: DateFormatter) -> [HourlyDataPointDTO] {
        let sundayBaselines = weeklySundayBaselineMap(from: hourly, cal: cal, df: df)
        return hourly.map { point in
            guard let date = df.date(from: point.dateString) else { return point }
            let wKey = weekKey(for: date, cal: cal)
            return HourlyDataPointDTO(
                hour: point.hour, value: point.value, minValue: point.minValue,
                maxValue: point.maxValue, dateString: point.dateString,
                glucoseType: point.glucoseType, baselineValue: sundayBaselines[wKey]
            )
        }
    }

    private static func buildBodyWeightDailyPoints(from hourly: [HourlyDataPointDTO], cal: Calendar, df: DateFormatter) -> [ChartDataPointDTO] {
        var groups: [String: [HourlyDataPointDTO]] = [:]
        for point in hourly { groups[point.dateString, default: []].append(point) }

        return groups.keys.sorted { (df.date(from: $0) ?? .distantPast) < (df.date(from: $1) ?? .distantPast) }
            .compactMap { dateString in
                guard let points = groups[dateString] else { return nil }
                let values = points.compactMap(\.value)
                guard !values.isEmpty else { return nil }
                return ChartDataPointDTO(
                    day: dateString,
                    value: values.reduce(0, +) / Double(values.count),
                    minValue: nil, maxValue: nil,
                    baselineValue: points.compactMap(\.baselineValue).last
                )
            }
    }

    private static func buildBodyWeightWeeklyPoints(from hourly: [HourlyDataPointDTO], cal: Calendar, df: DateFormatter) -> [ChartDataPointDTO] {
        var groups: [String: [HourlyDataPointDTO]] = [:]
        for point in hourly {
            guard let date = df.date(from: point.dateString) else { continue }
            groups[weekKey(for: date, cal: cal), default: []].append(point)
        }

        var result: [ChartDataPointDTO] = []
        for points in groups.values {
            guard let sample = points.first, let sampleDate = df.date(from: sample.dateString) else { continue }
            let weekday = cal.component(.weekday, from: sampleDate)
            let sunday = cal.date(byAdding: .day, value: -(weekday - 1), to: sampleDate) ?? sampleDate
            let values = points.compactMap(\.value)
            guard !values.isEmpty else { continue }
            result.append(ChartDataPointDTO(
                day: df.string(from: sunday),
                value: values.reduce(0, +) / Double(values.count),
                minValue: nil, maxValue: nil,
                baselineValue: points.compactMap(\.baselineValue).last
            ))
        }
        return result.sorted { (df.date(from: $0.day) ?? .distantPast) < (df.date(from: $1.day) ?? .distantPast) }
    }

    private static func buildBodyWeightMonthlyPoints(from hourly: [HourlyDataPointDTO], cal: Calendar, df: DateFormatter) -> [ChartDataPointDTO] {
        var groups: [String: [HourlyDataPointDTO]] = [:]
        for point in hourly {
            guard let date = df.date(from: point.dateString) else { continue }
            groups[monthKey(for: date, cal: cal), default: []].append(point)
        }

        let monthSundayBaselineMap = groups.reduce(into: [String: Double]()) { partial, entry in
            if let baseline = monthlySundayAverage(in: entry.value, cal: cal, df: df) {
                partial[entry.key] = baseline
            }
        }

        var result: [ChartDataPointDTO] = []
        for points in groups.values {
            guard let sample = points.first, let sampleDate = df.date(from: sample.dateString) else { continue }
            var comps = cal.dateComponents([.year, .month], from: sampleDate); comps.day = 1
            let monthStart = cal.date(from: comps) ?? sampleDate
            let values = points.compactMap(\.value)
            guard !values.isEmpty else { continue }
            let previousMonthStart = cal.date(byAdding: .month, value: -1, to: monthStart) ?? monthStart
            let baseline = monthSundayBaselineMap[monthKey(for: previousMonthStart, cal: cal)]
                ?? monthSundayBaselineMap[monthKey(for: monthStart, cal: cal)]
            result.append(ChartDataPointDTO(
                day: df.string(from: monthStart),
                value: values.reduce(0, +) / Double(values.count),
                minValue: nil, maxValue: nil, baselineValue: baseline
            ))
        }
        return result.sorted { (df.date(from: $0.day) ?? .distantPast) < (df.date(from: $1.day) ?? .distantPast) }
    }

    private static func weeklySundayBaselineMap(from hourly: [HourlyDataPointDTO], cal: Calendar, df: DateFormatter) -> [String: Double] {
        var sundayBuckets: [String: [Double]] = [:]
        for point in hourly {
            guard let value = point.value, let date = df.date(from: point.dateString) else { continue }
            guard cal.component(.weekday, from: date) == 1 else { continue }
            sundayBuckets[weekKey(for: date, cal: cal), default: []].append(value)
        }
        return sundayBuckets.reduce(into: [String: Double]()) { partial, entry in
            guard !entry.value.isEmpty else { return }
            partial[entry.key] = entry.value.reduce(0, +) / Double(entry.value.count)
        }
    }

    private static func monthlySundayAverage(in points: [HourlyDataPointDTO], cal: Calendar, df: DateFormatter) -> Double? {
        let sundayValues = points.compactMap { point -> Double? in
            guard let value = point.value, let date = df.date(from: point.dateString) else { return nil }
            return cal.component(.weekday, from: date) == 1 ? value : nil
        }
        guard !sundayValues.isEmpty else { return nil }
        return sundayValues.reduce(0, +) / Double(sundayValues.count)
    }

    private static func weekKey(for date: Date, cal: Calendar) -> String {
        "\(cal.component(.yearForWeekOfYear, from: date))-\(cal.component(.weekOfYear, from: date))"
    }

    private static func monthKey(for date: Date, cal: Calendar) -> String {
        let c = cal.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    private static func buildDailyPoints(
        from hourly: [HourlyDataPointDTO],
        hasRange: Bool,
        title: String,
        cal: Calendar,
        df: DateFormatter
    ) -> [ChartDataPointDTO] {
        var groups: [String: [HourlyDataPointDTO]] = [:]
        for hp in hourly { groups[hp.dateString, default: []].append(hp) }

        return groups.keys.sorted { (df.date(from: $0) ?? .distantPast) < (df.date(from: $1) ?? .distantPast) }
            .compactMap { dateString in
                guard let pts = groups[dateString] else { return nil }
                if hasRange {
                    let maxVals = pts.compactMap { $0.maxValue }
                    let minVals = pts.compactMap { $0.minValue }
                    guard !maxVals.isEmpty, !minVals.isEmpty else { return nil }
                    let rawMax = maxVals.reduce(0, +) / Double(maxVals.count)
                    let rawMin = minVals.reduce(0, +) / Double(minVals.count)
                    return ChartDataPointDTO(day: dateString, value: nil,
                        minValue: title == "Body Weight" ? rawMin : floor(rawMin),
                        maxValue: title == "Body Weight" ? rawMax : floor(rawMax),
                        baselineValue: nil)
                } else {
                    let vals = pts.compactMap { $0.value }
                    guard !vals.isEmpty else { return nil }
                    let rawAvg = vals.reduce(0, +) / Double(vals.count)
                    return ChartDataPointDTO(day: dateString,
                        value: title == "Body Weight" ? rawAvg : floor(rawAvg),
                        minValue: nil, maxValue: nil, baselineValue: nil)
                }
            }
    }

    private static func buildWeeklyPoints(
        from hourly: [HourlyDataPointDTO],
        hasRange: Bool,
        title: String,
        cal: Calendar,
        df: DateFormatter
    ) -> [ChartDataPointDTO] {
        var groups: [String: [HourlyDataPointDTO]] = [:]
        for hp in hourly {
            guard let date = df.date(from: hp.dateString) else { continue }
            let key = "\(cal.component(.yearForWeekOfYear, from: date))-\(cal.component(.weekOfYear, from: date))"
            groups[key, default: []].append(hp)
        }

        var result: [ChartDataPointDTO] = []
        for (_, pts) in groups {
            guard let anyDate = df.date(from: pts[0].dateString) else { continue }
            let weekday   = cal.component(.weekday, from: anyDate)
            let sunday    = cal.date(byAdding: .day, value: -(weekday - 1), to: anyDate)!
            let sundayStr = df.string(from: sunday)

            if hasRange {
                let maxVals = pts.compactMap { $0.maxValue }
                let minVals = pts.compactMap { $0.minValue }
                guard !maxVals.isEmpty, !minVals.isEmpty else { continue }
                let rawMax = maxVals.reduce(0, +) / Double(maxVals.count)
                let rawMin = minVals.reduce(0, +) / Double(minVals.count)
                result.append(ChartDataPointDTO(day: sundayStr, value: nil,
                    minValue: title == "Body Weight" ? rawMin : floor(rawMin),
                    maxValue: title == "Body Weight" ? rawMax : floor(rawMax),
                    baselineValue: nil))
            } else {
                let vals = pts.compactMap { $0.value }
                guard !vals.isEmpty else { continue }
                let rawAvg = vals.reduce(0, +) / Double(vals.count)
                result.append(ChartDataPointDTO(day: sundayStr,
                    value: title == "Body Weight" ? rawAvg : floor(rawAvg),
                    minValue: nil, maxValue: nil, baselineValue: nil))
            }
        }
        return result.sorted { (df.date(from: $0.day) ?? .distantPast) < (df.date(from: $1.day) ?? .distantPast) }
    }

    private static func buildMonthlyPoints(
        from hourly: [HourlyDataPointDTO],
        hasRange: Bool,
        title: String,
        cal: Calendar,
        df: DateFormatter
    ) -> [ChartDataPointDTO] {
        var groups: [String: [HourlyDataPointDTO]] = [:]
        for hp in hourly {
            guard let date = df.date(from: hp.dateString) else { continue }
            let key = String(format: "%04d-%02d", cal.component(.year, from: date), cal.component(.month, from: date))
            groups[key, default: []].append(hp)
        }

        var result: [ChartDataPointDTO] = []
        for (_, pts) in groups {
            guard let anyDate = df.date(from: pts[0].dateString) else { continue }
            var comps = cal.dateComponents([.year, .month], from: anyDate); comps.day = 1
            let firstDay = cal.date(from: comps)!
            let dayStr   = df.string(from: firstDay)

            if hasRange {
                let maxVals = pts.compactMap { $0.maxValue }
                let minVals = pts.compactMap { $0.minValue }
                guard !maxVals.isEmpty, !minVals.isEmpty else { continue }
                let rawMax = maxVals.reduce(0, +) / Double(maxVals.count)
                let rawMin = minVals.reduce(0, +) / Double(minVals.count)
                result.append(ChartDataPointDTO(day: dayStr, value: nil,
                    minValue: title == "Body Weight" ? rawMin : floor(rawMin),
                    maxValue: title == "Body Weight" ? rawMax : floor(rawMax),
                    baselineValue: nil))
            } else {
                let vals = pts.compactMap { $0.value }
                guard !vals.isEmpty else { continue }
                let rawAvg = vals.reduce(0, +) / Double(vals.count)
                result.append(ChartDataPointDTO(day: dayStr,
                    value: title == "Body Weight" ? rawAvg : floor(rawAvg),
                    minValue: nil, maxValue: nil, baselineValue: nil))
            }
        }
        return result.sorted { (df.date(from: $0.day) ?? .distantPast) < (df.date(from: $1.day) ?? .distantPast) }
    }

    private static func glucoseTypeString(for point: HourlyDataPointDTO) -> String {
        point.glucoseType ?? BloodGlucoseType.fasting.rawValue
    }

    nonisolated private static func formatValue(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }

    private static func orderedReadings(_ readings: [VitalReading]) -> [VitalReading] {
        let preferredOrder = ["Heart Rate", "Blood Pressure", "Blood Glucose", "Body Weight"]
        let ranks = Dictionary(uniqueKeysWithValues: preferredOrder.enumerated().map { ($1, $0) })
        return readings.sorted { lhs, rhs in
            let l = ranks[lhs.title] ?? Int.max
            let r = ranks[rhs.title] ?? Int.max
            return l == r ? lhs.title < rhs.title : l < r
        }
    }

    private static func emptyDefaultDTOs() -> [VitalReadingDTO] {
        [
            VitalReadingDTO(
                title: "Heart Rate",
                value: "--",
                unit: "BPM",
                subtitle: HeartRateSourceType.manual.subtitleText,
                iconImageName: "HeartSymbol",
                detailIconImageName: "HeartFill",
                iconTintHex: "#CC1111",
                chartType: "line",
                chartColor: "red",
                chartData: [],
                weeklyChartData: [],
                monthlyChartData: [],
                hourlyChartData: [],
                persistedHourlyChartData: [],
                baselineValue: nil
            ),
            VitalReadingDTO(
                title: "Blood Pressure",
                value: "--",
                unit: "mmHg",
                subtitle: "No logged readings",
                iconImageName: "Blood Symbol",
                detailIconImageName: "DropFill",
                iconTintHex: "#D43C2F",
                chartType: "rangeBar",
                chartColor: "red",
                chartData: [],
                weeklyChartData: [],
                monthlyChartData: [],
                hourlyChartData: [],
                persistedHourlyChartData: [],
                baselineValue: nil
            ),
            VitalReadingDTO(
                title: "Blood Glucose",
                value: "--",
                unit: "mg/dL",
                subtitle: BloodGlucoseType.fasting.subtitleText,
                iconImageName: "Glucometer",
                detailIconImageName: "GlucometerFill",
                iconTintHex: "#1163C7",
                chartType: "line",
                chartColor: "blue",
                chartData: [],
                weeklyChartData: [],
                monthlyChartData: [],
                hourlyChartData: [],
                persistedHourlyChartData: [],
                baselineValue: nil
            ),
            VitalReadingDTO(
                title: "Body Weight",
                value: "--",
                unit: "kg",
                subtitle: "No logged readings",
                iconImageName: "Body Symbol",
                detailIconImageName: "BodyFill",
                iconTintHex: "#5A8E38",
                chartType: "baselineBar",
                chartColor: "green",
                chartData: [],
                weeklyChartData: [],
                monthlyChartData: [],
                hourlyChartData: [],
                persistedHourlyChartData: [],
                baselineValue: nil
            )
        ]
    }

    private func persist(_ dtos: [VitalReadingDTO]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(VitalReadingsPayload(readings: dtos))
            try data.write(to: storeURL, options: .atomic)
        } catch {
            print("VitalDataStore: save error — \(error)")
        }
    }

    func saveHealthKitPoints(samples: [(bpm: Double, date: Date)],
                             source: HeartRateSourceType) {
        var dtos = loadDTOs()
        guard let idx = dtos.firstIndex(where: { $0.title == "Heart Rate" }) else { return }

        let dto = dtos[idx]
        let cal = Calendar.current
        let df  = DateFormatter(); df.dateFormat = "dd-MM-yyyy"

        var existingPoints = dto.hourlyChartData ?? []

        let existingKeys: Set<String> = Set(existingPoints.map {
            "\($0.dateString)_\(Int($0.hour))_\($0.heartRateSource ?? HeartRateSourceType.manual.rawValue)"
        })

        var added = false
        for sample in samples {
            let h        = cal.component(.hour, from: sample.date)
            let m        = cal.component(.minute, from: sample.date)
            let hourFrac = Double(h) + Double(m) / 60.0
            let dateStr  = df.string(from: sample.date)
            let key      = "\(dateStr)_\(h)_\(source.rawValue)"

            guard !existingKeys.contains(key) else { continue }

            let newPoint = HourlyDataPointDTO(
                hour: hourFrac,
                value: sample.bpm,
                minValue: nil,
                maxValue: nil,
                dateString: dateStr,
                glucoseType: nil,
                baselineValue: nil,
                heartRateSource: source.rawValue
            )
            existingPoints.append(newPoint)
            added = true
        }

        guard added else { return }

        let updatedDTO = VitalReadingDTO(
            title: dto.title, value: dto.value, unit: dto.unit,
            subtitle: source.subtitleText,
            iconImageName: dto.iconImageName, detailIconImageName: dto.detailIconImageName,
            iconTintHex: dto.iconTintHex, chartType: dto.chartType, chartColor: dto.chartColor,
            chartData: dto.chartData,
            weeklyChartData: dto.weeklyChartData,
            monthlyChartData: dto.monthlyChartData,
            hourlyChartData: existingPoints,
            persistedHourlyChartData: existingPoints,
            baselineValue: dto.baselineValue
        )

        dtos[idx] = Self.normalizedDTO(updatedDTO, cal: cal, df: df)
        persist(dtos)

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .vitalDataDidUpdate, object: nil,
                                            userInfo: ["title": "Heart Rate"])
        }
    }

    static func convert(_ dto: VitalReadingDTO) -> VitalReading {
        let cType: ChartType
        switch dto.chartType {
        case "line":        cType = .line
        case "rangeBar":    cType = .rangeBar
        case "baselineBar": cType = .baselineBar
        default:            cType = .line
        }

        let cColor: Color
        switch dto.chartColor.lowercased() {
        case "red":   cColor = .red
        case "blue":  cColor = .blue
        case "green": cColor = .green
        default:      cColor = .primary
        }

        func mapPoints(_ arr: [ChartDataPointDTO]) -> [ChartDataPoint] {
            arr.map { pdto in
                cType == .rangeBar
                    ? ChartDataPoint(day: pdto.day, min: pdto.minValue ?? 0, max: pdto.maxValue ?? 0, baselineValue: pdto.baselineValue)
                    : ChartDataPoint(day: pdto.day, value: pdto.value ?? 0, baselineValue: pdto.baselineValue)
            }
        }

        func mapTimedPoints(_ arr: [ChartDataPointDTO]) -> [ChartDataPoint] {
            arr.map { pdto in
                cType == .rangeBar
                    ? ChartDataPoint(day: pdto.day, min: pdto.minValue ?? 0, max: pdto.maxValue ?? 0, fullDate: pdto.day, baselineValue: pdto.baselineValue)
                    : ChartDataPoint(day: pdto.day, value: pdto.value ?? 0, fullDate: pdto.day, baselineValue: pdto.baselineValue)
            }
        }

        let isHeartRate = dto.title == "Heart Rate"
        let hourlyPoints = (dto.hourlyChartData ?? []).map { hp -> ChartDataPoint in
            cType == .rangeBar
                ? ChartDataPoint(hour: hp.hour, min: hp.minValue ?? 0, max: hp.maxValue ?? 0, fullDate: hp.dateString, baselineValue: hp.baselineValue)
                : ChartDataPoint(hour: hp.hour, value: hp.value ?? 0, fullDate: hp.dateString,
                                 glucoseType: isHeartRate ? (hp.heartRateSource ?? HeartRateSourceType.manual.rawValue) : hp.glucoseType,
                                 baselineValue: hp.baselineValue)
        }
        let persistedHourlyPoints = (dto.persistedHourlyChartData ?? dto.hourlyChartData ?? []).map { hp -> ChartDataPoint in
            cType == .rangeBar
                ? ChartDataPoint(hour: hp.hour, min: hp.minValue ?? 0, max: hp.maxValue ?? 0, fullDate: hp.dateString, baselineValue: hp.baselineValue)
                : ChartDataPoint(hour: hp.hour, value: hp.value ?? 0, fullDate: hp.dateString,
                                 glucoseType: isHeartRate ? (hp.heartRateSource ?? HeartRateSourceType.manual.rawValue) : hp.glucoseType,
                                 baselineValue: hp.baselineValue)
        }

        return VitalReading(
            title:            dto.title,
            value:            dto.value,
            unit:             dto.unit == "bpm" ? "BPM" : dto.unit,
            subtitle:         dto.subtitle,
            iconImage:        UIImage(named: dto.iconImageName == "glucometer-flat" ? "Glucometer" : dto.iconImageName),
            detailIconImage:  UIImage(named: dto.detailIconImageName),
            iconTint:         UIColor(hex: dto.iconTintHex),
            chartType:        cType,
            chartColor:       cColor,
            chartData:        mapPoints(dto.chartData),
            weeklyChartData:  mapTimedPoints(dto.weeklyChartData ?? []),
            monthlyChartData: mapTimedPoints(dto.monthlyChartData ?? []),
            hourlyChartData:  hourlyPoints,
            persistedHourlyChartData: persistedHourlyPoints,
            baselineValue:    dto.baselineValue
        )
    }
}

extension Notification.Name {
    static let vitalDataDidUpdate          = Notification.Name("vitalDataDidUpdate")
    static let glucoseFilterTypeDidChange  = Notification.Name("glucoseFilterTypeDidChange")
    static let heartRateSourceDidChange    = Notification.Name("heartRateSourceDidChange")
}
