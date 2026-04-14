
import UIKit
import SwiftUI
import DGCharts

class VitalCardCell: UICollectionViewCell {
    private let cardWeekdayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    private let cardXAxisHeight: CGFloat = 22
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var dataLabel: UILabel!
    @IBOutlet weak var unitLabel: UILabel!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var graphContainerView: UIView!
    @IBOutlet weak var cardBackgroundView: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        
        nameLabel.font = roundedFont(ofSize: 16, weight: .medium)
        dataLabel.font = roundedFont(ofSize: 28, weight: .bold)
        unitLabel.font = roundedFont(ofSize: 16, weight: .semibold)
        typeLabel.font = roundedFont(ofSize: 15, weight: .medium)
        if dateLabel != nil {
            dateLabel.font = roundedFont(ofSize: 14, weight: .medium)
        }
        
        self.clipsToBounds = false
        self.layer.masksToBounds = false
        self.contentView.clipsToBounds = false
        self.contentView.layer.masksToBounds = false
        
        if let cardView = cardBackgroundView {
            cardView.layer.cornerRadius = 24
            cardView.backgroundColor = .white
            
            cardView.clipsToBounds = false
            cardView.layer.masksToBounds = false
            
            cardView.layer.shadowColor = UIColor.black.cgColor
            cardView.layer.shadowOpacity = 0.05
            cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
            cardView.layer.shadowRadius = 12
        }
    }
    
    private func roundedFont(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let systemFont = UIFont.systemFont(ofSize: size, weight: weight)
        if let descriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return systemFont
    }
    
    func configure(with reading: VitalReading, glucoseFilterType: String? = nil) {
        var latestValueStr = reading.value

        let isGlucose = reading.title == "Blood Glucose"
        let activeGlucoseFilter = glucoseFilterType ?? "Fasting"
        let sourcePoints = reading.persistedHourlyChartData.isEmpty ? reading.hourlyChartData : reading.persistedHourlyChartData
        let filteredHourly: [ChartDataPoint] = isGlucose
            ? sourcePoints.filter { ($0.glucoseType ?? "Fasting") == activeGlucoseFilter }
            : sourcePoints

        let lastPoint = filteredHourly.last ?? reading.chartData.last
        if let point = lastPoint {
            if let min = point.minValue, let max = point.maxValue {
                latestValueStr = "\(Int(max.rounded()))/\(Int(min.rounded()))"
            } else if let val = point.value {
                latestValueStr = val.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(val)) : String(format: "%.1f", val)
            }
        }
        
        nameLabel.text = reading.title
        dataLabel.text = latestValueStr
        unitLabel.text = reading.unit
        typeLabel.text = isGlucose ? "\(activeGlucoseFilter) Glucose" : reading.subtitle
        iconImageView.image = reading.iconImage
        iconImageView.tintColor = reading.iconTint
        
        if let label = dateLabel {
            if let lastHourly = filteredHourly.last, let hour = lastHourly.hourOfDay {
                var hourInt = Int(hour)
                var minuteInt = Int(round((hour - Double(hourInt)) * 60))
                
                if minuteInt == 60 {
                    minuteInt = 0
                    hourInt += 1
                }
                
                if hourInt == 24 {
                    hourInt = 0
                }
                
                let isPM = hourInt >= 12
                let displayHour = hourInt == 0 ? 12 : (hourInt > 12 ? hourInt - 12 : hourInt)
                let timeStr = String(format: "%d:%02d %@", displayHour, minuteInt, isPM ? "PM" : "AM")
                
                let df = DateFormatter()
                df.dateFormat = "dd-MM-yyyy"
                let todayStr = df.string(from: Date())
                
                let isToday = (lastHourly.fullDate == todayStr) || (lastHourly.fullDate == "__TODAY__") || (lastHourly.fullDate == nil)
                
                if isToday {
                    label.text = timeStr
                } else {
                    if let full = lastHourly.fullDate, let parsed = df.date(from: full) {
                        df.dateFormat = "dd MMM"
                        label.text = df.string(from: parsed)
                    } else {
                        label.text = lastHourly.fullDate ?? ""
                    }
                }
            } else if let lastDaily = reading.chartData.last {
                label.text = lastDaily.day.replacingOccurrences(of: "-", with: " ")
            } else {
                label.text = ""
            }
        }
        
        graphContainerView.subviews.forEach { $0.removeFromSuperview() }
        
        let recentDataPoints = currentWeekCardPoints(from: filteredHourly, chartType: reading.chartType, baseline: reading.baselineValue, title: reading.title)
        
        switch reading.chartType {
        case .line:
            setupLineChart(in: graphContainerView, color: reading.iconTint, dataPoints: recentDataPoints)
        case .rangeBar:
            setupBarChart(in: graphContainerView, color: reading.iconTint, dataPoints: recentDataPoints)
        case .baselineBar:
            setupBaselineBarChart(in: graphContainerView, color: reading.iconTint, dataPoints: recentDataPoints, baseline: reading.baselineValue ?? 0)
        }
    }

    private func currentWeekCardPoints(from points: [ChartDataPoint], chartType: ChartType, baseline: Double?, title: String) -> [ChartDataPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today) 
        let mondayOffset = weekday == 1 ? -6 : (2 - weekday)
        let monday = cal.date(byAdding: .day, value: mondayOffset, to: today) ?? today
        let df = DateFormatter()
        df.dateFormat = "dd-MM-yyyy"

        return (0..<7).map { offset -> ChartDataPoint in
            let date = cal.date(byAdding: .day, value: offset, to: monday) ?? monday
            let dateString = df.string(from: date)
            let dayPoints = points.filter { $0.fullDate == dateString }

            switch chartType {
            case .rangeBar:
                let mins = dayPoints.compactMap(\.minValue)
                let maxs = dayPoints.compactMap(\.maxValue)
                if !mins.isEmpty && !maxs.isEmpty {
                    let avgMin = mins.reduce(0, +) / Double(mins.count)
                    let avgMax = maxs.reduce(0, +) / Double(maxs.count)
                    return ChartDataPoint(day: dateString, min: title == "Body Weight" ? avgMin : floor(avgMin), max: title == "Body Weight" ? avgMax : floor(avgMax), fullDate: dateString)
                }
                return ChartDataPoint(day: dateString, min: nil, max: nil, fullDate: dateString)
            case .baselineBar:
                let values = dayPoints.compactMap(\.value)
                if !values.isEmpty {
                    let avg = values.reduce(0, +) / Double(values.count)
                    return ChartDataPoint(day: dateString, value: title == "Body Weight" ? avg : floor(avg), fullDate: dateString, baselineValue: dayPoints.compactMap(\.baselineValue).last ?? baseline)
                }
                return ChartDataPoint(day: dateString, value: nil, fullDate: dateString, baselineValue: baseline)
            case .line:
                let values = dayPoints.compactMap(\.value)
                if !values.isEmpty {
                    let avg = values.reduce(0, +) / Double(values.count)
                    return ChartDataPoint(day: dateString, value: title == "Body Weight" ? avg : floor(avg), fullDate: dateString)
                }
                return ChartDataPoint(day: dateString, value: nil, fullDate: dateString)
            }
        }
    }
    
    private func setupLineChart(in container: UIView, color: UIColor, dataPoints: [ChartDataPoint]) {
        let lineChartView = LineChartView(frame: chartFrame(in: container))
        lineChartView.noDataText = "No data recorded this week."
        lineChartView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        var lineDataSets: [LineChartDataSet] = []
        var currentEntries: [ChartDataEntry] = []
        var globalMin: Double = .greatestFiniteMagnitude
        var globalMax: Double = 0
        
        for (i, point) in dataPoints.enumerated() {
            if let val = point.value {
                currentEntries.append(ChartDataEntry(x: Double(i), y: val))
                globalMin = min(globalMin, val)
                globalMax = max(globalMax, val)
            } else if !currentEntries.isEmpty {
                lineDataSets.append(makeLineDataSet(entries: currentEntries, color: color))
                currentEntries.removeAll()
            }
        }
        if !currentEntries.isEmpty {
            lineDataSets.append(makeLineDataSet(entries: currentEntries, color: color))
        }
        guard !lineDataSets.isEmpty else {
            applyCardXAxis(to: lineChartView.xAxis)
            applyCardChartLayout(to: lineChartView)
            lineChartView.leftAxis.enabled = false
            lineChartView.rightAxis.enabled = false
            lineChartView.legend.enabled = false
            lineChartView.isUserInteractionEnabled = false
            container.addSubview(lineChartView)
            addCardXAxisLabels(in: container)
            return
        }

        let data = LineChartData(dataSets: lineDataSets)
        lineChartView.data = data
        
        applyCardXAxis(to: lineChartView.xAxis)
        applyCardChartLayout(to: lineChartView)
        
        if globalMin != .greatestFiniteMagnitude {
            let totalRange = max(globalMax - globalMin, 10.0)
            
            let padding = totalRange * 0.333 
            
            lineChartView.leftAxis.axisMinimum = globalMin - padding
            lineChartView.leftAxis.axisMaximum = globalMax + padding
        }
        
        lineChartView.leftAxis.enabled = false
        lineChartView.rightAxis.enabled = false
        lineChartView.legend.enabled = false
        lineChartView.isUserInteractionEnabled = false
        
        container.addSubview(lineChartView)
        addCardXAxisLabels(in: container)
    }

    private func makeLineDataSet(entries: [ChartDataEntry], color: UIColor) -> LineChartDataSet {
        let dataSet = LineChartDataSet(entries: entries, label: "")
        dataSet.colors = [color]
        
        if entries.count == 1 {
            dataSet.drawCirclesEnabled = true
            dataSet.circleColors = [color]
            dataSet.circleRadius = 3.0
            dataSet.drawCircleHoleEnabled = false
        } else {
            dataSet.drawCirclesEnabled = false
        }
        
        dataSet.lineWidth = 2.0
        dataSet.mode = .cubicBezier
        dataSet.drawValuesEnabled = false

        let gradientColors = [color.withAlphaComponent(0.3).cgColor, UIColor.clear.cgColor] as CFArray
        let colorLocations: [CGFloat] = [1.0, 0.0]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors, locations: colorLocations) {
            dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90.0)
            dataSet.drawFilledEnabled = true
        }
        return dataSet
    }

    private func applyCardXAxis(to axis: XAxis) {
        axis.valueFormatter = IndexAxisValueFormatter(values: cardWeekdayLabels)
        axis.axisMinimum = -0.5
        axis.axisMaximum = 6.5
        axis.granularity = 1
        axis.labelCount = 7
        axis.forceLabelsEnabled = true
        axis.labelPosition = .bottom
        axis.labelFont = roundedFont(ofSize: 12, weight: .medium)
        axis.labelTextColor = .gray
        axis.drawGridLinesEnabled = false
        axis.drawAxisLineEnabled = false
        axis.drawLabelsEnabled = false
        axis.centerAxisLabelsEnabled = false
        axis.avoidFirstLastClippingEnabled = false
        axis.yOffset = 4
    }

    private func applyCardChartLayout(to chartView: BarLineChartViewBase) {
        chartView.minOffset = 8
        chartView.extraLeftOffset = 4
        chartView.extraRightOffset = 4
        chartView.extraBottomOffset = 0
        chartView.drawBordersEnabled = false
        chartView.clipDataToContentEnabled = false
        chartView.dragEnabled = false
        chartView.scaleXEnabled = false
        chartView.scaleYEnabled = false
        chartView.pinchZoomEnabled = false
        chartView.doubleTapToZoomEnabled = false
        chartView.highlightPerTapEnabled = false
        chartView.highlightPerDragEnabled = false
        chartView.fitScreen()
        chartView.setVisibleXRangeMinimum(7)
        chartView.setVisibleXRangeMaximum(7)
        chartView.moveViewToX(0)
    }

    private func chartFrame(in container: UIView) -> CGRect {
        container.bounds.inset(by: UIEdgeInsets(top: 0, left: 0, bottom: cardXAxisHeight, right: 0))
    }

    private func addCardXAxisLabels(in container: UIView) {
        container.subviews
            .filter { $0.tag == 7001 }
            .forEach { $0.removeFromSuperview() }

        let labelsView = UIStackView(frame: CGRect(
            x: 0,
            y: container.bounds.height - cardXAxisHeight,
            width: container.bounds.width,
            height: cardXAxisHeight
        ))
        labelsView.tag = 7001
        labelsView.axis = .horizontal
        labelsView.alignment = .fill
        labelsView.distribution = .fillEqually
        labelsView.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]

        for labelText in cardWeekdayLabels {
            let label = UILabel()
            label.text = labelText
            label.font = roundedFont(ofSize: 12, weight: .medium)
            label.textColor = .gray
            label.textAlignment = .center
            labelsView.addArrangedSubview(label)
        }

        container.addSubview(labelsView)
    }
    
    private func setupBarChart(in container: UIView, color: UIColor, dataPoints: [ChartDataPoint]) {
        let barChartView = BarChartView(frame: chartFrame(in: container))
        barChartView.noDataText = "No data recorded this week."
        barChartView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        barChartView.renderer = RoundedBarChartRenderer(dataProvider: barChartView, animator: barChartView.chartAnimator, viewPortHandler: barChartView.viewPortHandler)
        
        var fgEntries: [BarChartDataEntry] = []
        var globalMin: Double = .greatestFiniteMagnitude
        var globalMax: Double = 0
        
        for (i, point) in dataPoints.enumerated() {
            if let min = point.minValue, let max = point.maxValue, !(min == 0 && max == 0 && point.fullDate != nil) {
                fgEntries.append(BarChartDataEntry(x: Double(i), yValues: [min, max]))
                
                if min < globalMin { globalMin = min }
                if max > globalMax { globalMax = max }
            }
        }
        guard !fgEntries.isEmpty else {
            applyCardXAxis(to: barChartView.xAxis)
            applyCardChartLayout(to: barChartView)
            barChartView.leftAxis.enabled = false
            barChartView.rightAxis.enabled = false
            barChartView.legend.enabled = false
            barChartView.isUserInteractionEnabled = false
            container.addSubview(barChartView)
            addCardXAxisLabels(in: container)
            return
        }
        
        let totalRange = globalMax - globalMin
        let bgMin = max(0, globalMin - (totalRange * 0.25))
        let bgMax = globalMax + (totalRange * 0.25)
        
        var bgEntries = [BarChartDataEntry]()
        for (i, point) in dataPoints.enumerated() where !(point.minValue == nil && point.maxValue == nil) && !(point.minValue == 0 && point.maxValue == 0 && point.fullDate != nil) {
            bgEntries.append(BarChartDataEntry(x: Double(i), yValues: [bgMin, bgMax]))
        }
        let bgDataSet = BarChartDataSet(entries: bgEntries, label: "")
        bgDataSet.colors = [UIColor(hex: "#F8DDDD")]
        bgDataSet.drawValuesEnabled = false
        
        let fgDataSet = BarChartDataSet(entries: fgEntries, label: "")
        fgDataSet.colors = [color]
        fgDataSet.drawValuesEnabled = false
        
        let data = BarChartData(dataSets: [bgDataSet, fgDataSet])
        data.barWidth = 0.25 
        barChartView.data = data
        
        applyCardXAxis(to: barChartView.xAxis)
        applyCardChartLayout(to: barChartView)
        
        barChartView.leftAxis.axisMinimum = bgMin - (totalRange * 0.1) 
        barChartView.leftAxis.axisMaximum = bgMax + (totalRange * 0.1)
        barChartView.leftAxis.enabled = false
        barChartView.rightAxis.enabled = false
        barChartView.legend.enabled = false
        barChartView.isUserInteractionEnabled = false
        
        container.addSubview(barChartView)
        addCardXAxisLabels(in: container)
    }
    
    private func setupBaselineBarChart(in container: UIView, color: UIColor, dataPoints: [ChartDataPoint], baseline: Double) {
        let barChartView = BarChartView(frame: chartFrame(in: container))
        barChartView.noDataText = "No data recorded this week."
        barChartView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        barChartView.renderer = RoundedBarChartRenderer(dataProvider: barChartView, animator: barChartView.chartAnimator, viewPortHandler: barChartView.viewPortHandler)
        
        let hasValidData = dataPoints.contains { point in
            if let val = point.value, !(val == 0 && point.fullDate != nil) { return true }
            return false
        }
        
        guard hasValidData else {
            applyCardXAxis(to: barChartView.xAxis)
            applyCardChartLayout(to: barChartView)
            barChartView.leftAxis.enabled = false
            barChartView.rightAxis.enabled = false
            barChartView.legend.enabled = false
            barChartView.isUserInteractionEnabled = false
            container.addSubview(barChartView)
            addCardXAxisLabels(in: container)
            return
        }
        
        let maxAbsDiff = dataPoints.compactMap { point -> Double? in
            guard let v = point.value else { return nil }
            guard !(v == 0 && point.fullDate != nil) else { return nil }
            return abs(v - baseline)
        }.max() ?? 1.0
        
        let bgPadding = maxAbsDiff * 0.2 
        let bgY = maxAbsDiff + bgPadding
        
        var bgEntries = [BarChartDataEntry]()
        for (i, point) in dataPoints.enumerated() where !(point.value == nil) && !(point.value == 0 && point.fullDate != nil) {
            bgEntries.append(BarChartDataEntry(x: Double(i), yValues: [-bgY, bgY]))
        }
        let bgDataSet = BarChartDataSet(entries: bgEntries, label: "")
        bgDataSet.colors = [UIColor(hex: "#E2E2E2")] 
        bgDataSet.drawValuesEnabled = false
        
        var fgEntries = [BarChartDataEntry]()
        var fgColors = [UIColor]()
        
        for i in 0..<dataPoints.count {
            if let val = dataPoints[i].value, !(val == 0 && dataPoints[i].fullDate != nil) {
                let diff = val - baseline
                fgEntries.append(BarChartDataEntry(x: Double(i), y: diff))
                
                fgColors.append(diff >= 0 ? color : UIColor(hex: "#CD8282"))
            } else {
                fgEntries.append(BarChartDataEntry(x: Double(i), y: 0))
                fgColors.append(.clear)
            }
        }
        let fgDataSet = BarChartDataSet(entries: fgEntries, label: "")
        fgDataSet.colors = fgColors
        fgDataSet.drawValuesEnabled = false
        
        let data = BarChartData(dataSets: [bgDataSet, fgDataSet])
        data.barWidth = 0.25 
        barChartView.data = data
        
        applyCardXAxis(to: barChartView.xAxis)
        applyCardChartLayout(to: barChartView)
        
        barChartView.leftAxis.axisMinimum = -bgY
        barChartView.leftAxis.axisMaximum = bgY
        barChartView.leftAxis.enabled = false
        barChartView.rightAxis.enabled = false
        barChartView.legend.enabled = false
        barChartView.isUserInteractionEnabled = false
        
        container.addSubview(barChartView)
        addCardXAxisLabels(in: container)
    }
}

class RoundedBarChartRenderer: BarChartRenderer {
    
    nonisolated override init(dataProvider: BarChartDataProvider?, animator: Animator, viewPortHandler: ViewPortHandler) {
        super.init(dataProvider: dataProvider!, animator: animator, viewPortHandler: viewPortHandler)
    }
    
    nonisolated override func drawDataSet(context: CGContext, dataSet: BarChartDataSetProtocol, index: Int) {
        guard let dataProvider = dataProvider, let barData = dataProvider.barData else { return }
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        
        context.saveGState()
        defer { context.restoreGState() }
        
        let phaseY = animator.phaseY
        let barWidth = barData.barWidth
        let barWidthHalf = barWidth / 2.0
        
        for j in 0..<dataSet.entryCount {
            guard let e = dataSet.entryForIndex(j) as? BarChartDataEntry else { continue }
            let x = e.x
            let y = e.y
            
            var bottomVal: Double = 0
            var topVal: Double = 0
            
            if let yVals = e.yValues, yVals.count == 2 {
                bottomVal = yVals[0] * phaseY
                topVal = yVals[1] * phaseY
            } else {
                bottomVal = min(0.0, y) * phaseY
                topVal = max(0.0, y) * phaseY
            }
            
            var rect = CGRect(x: x - barWidthHalf, y: bottomVal, width: barWidth, height: topVal - bottomVal)
            trans.rectValueToPixel(&rect)
            rect = rect.standardized 
            
            var path: UIBezierPath
            
            if e.yValues == nil {
                var corners: UIRectCorner = []
                if y > 0 {
                    corners = [.topLeft, .topRight]
                } else if y < 0 {
                    corners = [.bottomLeft, .bottomRight]
                } else {
                    continue
                }
                path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: rect.width / 2.0, height: rect.width / 2.0))
            } else {
                path = UIBezierPath(roundedRect: rect, cornerRadius: rect.width / 2.0)
            }
            
            context.setFillColor(dataSet.color(atIndex: j).cgColor)
            path.fill()
        }
    }
}
