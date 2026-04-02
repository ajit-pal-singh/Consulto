import UIKit
import SwiftUI
import DGCharts

class VitalCardCell: UICollectionViewCell {
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var dataLabel: UILabel!
    @IBOutlet weak var unitLabel: UILabel!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var graphContainerView: UIView!
    @IBOutlet weak var cardBackgroundView: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        
        nameLabel.font = roundedFont(ofSize: 16, weight: .medium)
        dataLabel.font = roundedFont(ofSize: 28, weight: .bold)
        unitLabel.font = roundedFont(ofSize: 16, weight: .semibold)
        typeLabel.font = roundedFont(ofSize: 14, weight: .regular)
        
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
    
    func configure(with reading: VitalReading) {
        nameLabel.text = reading.title
        dataLabel.text = reading.value
        unitLabel.text = reading.unit
        typeLabel.text = reading.subtitle
        iconImageView.image = reading.iconImage
        iconImageView.tintColor = reading.iconTint
        
        // Remove any old DGCharts graph if we are reusing this cell
        graphContainerView.subviews.forEach { $0.removeFromSuperview() }
        
        switch reading.chartType {
        case .line:
            setupLineChart(in: graphContainerView, color: reading.iconTint, dataPoints: reading.chartData)
        case .rangeBar:
            setupBarChart(in: graphContainerView, color: reading.iconTint, dataPoints: reading.chartData)
        case .baselineBar:
            setupBaselineBarChart(in: graphContainerView, color: reading.iconTint, dataPoints: reading.chartData, baseline: reading.baselineValue ?? 0)
        }
    }
    
    // MARK: - DGCharts Implementation
    private func setupLineChart(in container: UIView, color: UIColor, dataPoints: [ChartDataPoint]) {
        let lineChartView = LineChartView(frame: container.bounds)
        lineChartView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        var entries: [ChartDataEntry] = []
        var globalMin: Double = .greatestFiniteMagnitude
        var globalMax: Double = 0
        
        for (i, point) in dataPoints.enumerated() {
            if let val = point.value {
                entries.append(ChartDataEntry(x: Double(i), y: val))
                if val < globalMin { globalMin = val }
                if val > globalMax { globalMax = val }
            }
        }
        
        let dataSet = LineChartDataSet(entries: entries, label: "")
        dataSet.colors = [color]
        dataSet.drawCirclesEnabled = false
        dataSet.lineWidth = 2.0
        dataSet.mode = .cubicBezier
        dataSet.drawValuesEnabled = false
        
        let gradientColors = [color.withAlphaComponent(0.3).cgColor, UIColor.clear.cgColor] as CFArray
        let colorLocations:[CGFloat] = [1.0, 0.0]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors, locations: colorLocations) {
            dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90.0)
            dataSet.drawFilledEnabled = true
        }
        
        let data = LineChartData(dataSet: dataSet)
        lineChartView.data = data
        
        let days = dataPoints.map { $0.day }
        lineChartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: days)
        lineChartView.xAxis.labelPosition = .bottom
        lineChartView.xAxis.labelFont = roundedFont(ofSize: 12, weight: .medium)
        lineChartView.xAxis.labelTextColor = .gray
        lineChartView.xAxis.drawGridLinesEnabled = false
        lineChartView.xAxis.drawAxisLineEnabled = false
        lineChartView.xAxis.drawLabelsEnabled = true
        
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
    }
    
    private func setupBarChart(in container: UIView, color: UIColor, dataPoints: [ChartDataPoint]) {
        let barChartView = BarChartView(frame: container.bounds)
        barChartView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        barChartView.renderer = RoundedBarChartRenderer(dataProvider: barChartView, animator: barChartView.chartAnimator, viewPortHandler: barChartView.viewPortHandler)
        
        var fgEntries: [BarChartDataEntry] = []
        var globalMin: Double = .greatestFiniteMagnitude
        var globalMax: Double = 0
        
        for (i, point) in dataPoints.enumerated() {
            if let min = point.minValue, let max = point.maxValue {
                fgEntries.append(BarChartDataEntry(x: Double(i), yValues: [min, max]))
                
                if min < globalMin { globalMin = min }
                if max > globalMax { globalMax = max }
            } else {
                fgEntries.append(BarChartDataEntry(x: Double(i), y: 0))
            }
        }
        
        let totalRange = globalMax - globalMin
        let bgMin = max(0, globalMin - (totalRange * 0.25))
        let bgMax = globalMax + (totalRange * 0.25)
        
        var bgEntries = [BarChartDataEntry]()
        for i in 0..<dataPoints.count {
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
        
        let days = dataPoints.map { $0.day }
        barChartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: days)
        barChartView.xAxis.labelPosition = .bottom
        barChartView.xAxis.labelFont = roundedFont(ofSize: 12, weight: .medium)
        barChartView.xAxis.labelTextColor = .gray
        barChartView.xAxis.drawGridLinesEnabled = false
        barChartView.xAxis.drawAxisLineEnabled = false
        barChartView.xAxis.drawLabelsEnabled = true
        
        barChartView.leftAxis.axisMinimum = bgMin - (totalRange * 0.1)
        barChartView.leftAxis.axisMaximum = bgMax + (totalRange * 0.1)
        barChartView.leftAxis.enabled = false
        barChartView.rightAxis.enabled = false
        barChartView.legend.enabled = false
        barChartView.isUserInteractionEnabled = false
        
        container.addSubview(barChartView)
    }
    
    private func setupBaselineBarChart(in container: UIView, color: UIColor, dataPoints: [ChartDataPoint], baseline: Double) {
        let barChartView = BarChartView(frame: container.bounds)
        barChartView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    
        barChartView.renderer = RoundedBarChartRenderer(dataProvider: barChartView, animator: barChartView.chartAnimator, viewPortHandler: barChartView.viewPortHandler)
        
        // Find the highest difference from the baseline so the grey background bars stretch uniformly
        let maxAbsDiff = dataPoints.compactMap { point -> Double? in
            guard let v = point.value else { return nil }
            return abs(v - baseline)
        }.max() ?? 1.0
        
        let bgPadding = maxAbsDiff * 0.2
        let bgY = maxAbsDiff + bgPadding
        
        // DataSet 1: Background Light Grey Bars (Stretch from -max to +max)
        var bgEntries = [BarChartDataEntry]()
        for i in 0..<dataPoints.count {
            bgEntries.append(BarChartDataEntry(x: Double(i), yValues: [-bgY, bgY]))
        }
        let bgDataSet = BarChartDataSet(entries: bgEntries, label: "")
        bgDataSet.colors = [UIColor(hex: "#E2E2E2")] // Light grey
        bgDataSet.drawValuesEnabled = false
        
        // DataSet 2: Foreground Colored Bars
        var fgEntries = [BarChartDataEntry]()
        var fgColors = [UIColor]()
        
        for i in 0..<dataPoints.count {
            if let val = dataPoints[i].value {
                let diff = val - baseline
                fgEntries.append(BarChartDataEntry(x: Double(i), y: diff))
                
                // Green if we gained/stayed the same, Red if we lost weight
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
        
        let days = dataPoints.map { $0.day }
        barChartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: days)
        barChartView.xAxis.labelPosition = .bottom
        barChartView.xAxis.labelFont = roundedFont(ofSize: 12, weight: .medium)
        barChartView.xAxis.labelTextColor = .gray
        barChartView.xAxis.drawGridLinesEnabled = false
        barChartView.xAxis.drawAxisLineEnabled = false
        barChartView.xAxis.drawLabelsEnabled = true
        
        // Lock the Y axis directly to the top/bottom bounds of the background bars so they fill the space perfectly
        barChartView.leftAxis.axisMinimum = -bgY
        barChartView.leftAxis.axisMaximum = bgY
        barChartView.leftAxis.enabled = false
        barChartView.rightAxis.enabled = false
        barChartView.legend.enabled = false
        barChartView.isUserInteractionEnabled = false
        
        container.addSubview(barChartView)
    }
}

// MARK: - Custom Renderer for Rounded Caps in DGCharts
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
