import UIKit

protocol VitalChartScrollDelegate: AnyObject {
    func vitalChartDidScroll(visibleStartDate: Date?, visibleEndDate: Date?)
    func vitalChartDidHighlightPoint(_ point: ChartDataPoint?)
}

final class VitalChartView: UIView {

    struct Config {
        var title: String               = ""
        var baselineValue: Double       = 0
        var glucoseTargetRange: (min: Double, max: Double)? = nil
        var viewportAnchorDate: Date?   = nil
        var chartType: ChartType        = .line
        var tintColor: UIColor          = .systemBlue
        var unit: String                = ""
        var yAxisWidth: CGFloat         = 44
        var xAxisHeight: CGFloat        = 28
        var columnWidth: CGFloat        = 46
        var plotInset: CGFloat          = 12
        var yGridLines: Int             = 4
        var isContinuousDaily: Bool     = false
        var isContinuousWeekly: Bool    = false
        var isContinuousMonthly: Bool   = false
    }

    private let scrollView  = UIScrollView()
    private let plotCanvas  = UIView()
    private let yAxisView   = UIView()

    weak var scrollDelegate: VitalChartScrollDelegate?

    private(set) var config     = Config()
    private var dataPoints      : [ChartDataPoint] = []
    private var yMin            : Double = 0
    private var yMax            : Double = 100
    private var bodyWeightStep  : Double = 0.5
    private var didScrollToEnd  = false
    
    private var minDate: Date = Date()
    private var maxDate: Date = Date()
    private var timelineDays: Int = 1
    
    private var visibleXLabels: [Int: UILabel] = [:]
    private var gridPathLayer: CAShapeLayer?        
    private var horizontalGridLayer: CAShapeLayer?  
    private var lastDrawnSize: CGSize = .zero       
    private var lastRenderedPeriodKey: String?
    
    private var timelineWeeks: Int = 1
    private var minWeekStart: Date = Date()
    
    private var totalMonthDays: Int = 0
    private var minMonthStart: Date = Date()
    private var monthSeparatorLayer: CAShapeLayer?

    private var highlightLineLayer: CAShapeLayer?
    private var highlightTooltip: UIView?
    private var highlightedPointIndex: Int?
    private var pointIndexByID: [UUID: Int] = [:]

    private static let sharedDF: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "dd-MM-yyyy"
        return df
    }()
    
    private var dateCache: [String: Date] = [:]

    override init(frame: CGRect) { super.init(frame: frame); build() }
    required init?(coder: NSCoder) { super.init(coder: coder); build() }

    private func build() {
        backgroundColor = .clear
        clipsToBounds   = false

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator   = false
        scrollView.clipsToBounds = true
        scrollView.backgroundColor = .clear
        scrollView.delegate = self

        plotCanvas.backgroundColor = .clear

        addSubview(scrollView)
        scrollView.addSubview(plotCanvas)
        addSubview(yAxisView)
        yAxisView.backgroundColor = .clear

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleChartTap(_:)))
        scrollView.addGestureRecognizer(tap)
    }

    private func startOfWeek(for date: Date) -> Date {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let weekday = cal.component(.weekday, from: startOfDay) 
        let daysFromMonday = (weekday + 5) % 7
        return cal.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
    }

    private func chartDate(from fullDate: String?) -> Date? {
        guard let fullDate else { return nil }
        if let d = dateCache[fullDate] { return d }
        let d = Self.sharedDF.date(from: fullDate)
        if let d = d { dateCache[fullDate] = d }
        return d
    }


    func configure(with points: [ChartDataPoint], config: Config) {
        self.config     = config
        
        for p in points {
            if let fd = p.fullDate, dateCache[fd] == nil {
                dateCache[fd] = Self.sharedDF.date(from: fd)
            }
        }
        
        if config.isContinuousDaily {
            self.dataPoints = points.sorted { p1, p2 in
                let d1 = chartDate(from: p1.fullDate) ?? Date.distantPast
                let d2 = chartDate(from: p2.fullDate) ?? Date.distantPast
                
                if d1 == d2 {
                    return (p1.hourOfDay ?? 0) < (p2.hourOfDay ?? 0)
                }
                return d1 < d2
            }
        } else if config.isContinuousWeekly {
            self.dataPoints = points.sorted { p1, p2 in
                let d1 = chartDate(from: p1.fullDate) ?? Date.distantPast
                let d2 = chartDate(from: p2.fullDate) ?? Date.distantPast
                return d1 < d2
            }
        } else {
            self.dataPoints = points
        }

        pointIndexByID = Dictionary(
            uniqueKeysWithValues: dataPoints.enumerated().map { ($0.element.id, $0.offset) }
        )
        
        didScrollToEnd  = false
        lastDrawnSize   = .zero   
        computeRange()
        setNeedsLayout()
    }


    override func layoutSubviews() {
        super.layoutSubviews()

        let w   = bounds.width
        let h   = bounds.height
        let yW  = config.yAxisWidth
        let xH  = config.xAxisHeight

        yAxisView.frame = CGRect(x: w - yW, y: 0, width: yW, height: h - xH)

        scrollView.frame = CGRect(x: 0, y: 0, width: w - yW, height: h)

        let minW    = scrollView.bounds.width
        let natural: CGFloat
        if config.isContinuousDaily {
            natural = config.plotInset * 2 + CGFloat(timelineDays * 4) * continuousColumnWidth
        } else if config.isContinuousWeekly {
            natural = config.plotInset * 2 + CGFloat(timelineWeeks * 7) * weeklyColumnWidth
        } else if config.isContinuousMonthly {
            natural = config.plotInset * 2 + CGFloat(totalMonthDays) * monthlyDayWidth
        } else {
            natural = config.plotInset * 2 + CGFloat(dataPoints.count) * config.columnWidth
        }
        let contentW = max(minW, natural)
        plotCanvas.frame       = CGRect(x: 0, y: 0, width: contentW, height: h)
        scrollView.contentSize = CGSize(width: contentW, height: h)

        let currentSize = CGSize(width: w, height: h)
        if currentSize != lastDrawnSize {
            lastDrawnSize = currentSize
            redraw()
        }

        if !didScrollToEnd {
            didScrollToEnd = true
            
            let cal = Calendar.current
            var lastDataDate = cal.startOfDay(for: config.viewportAnchorDate ?? Date())
            if let lastPt = dataPoints.last, let fd = lastPt.fullDate {
                if let d = chartDate(from: fd) {
                    lastDataDate = max(lastDataDate, cal.startOfDay(for: d))
                }
            }

            if config.isContinuousDaily {
                let dayOffset = cal.dateComponents([.day], from: minDate, to: lastDataDate).day ?? 1000
                let ox = config.plotInset + CGFloat(dayOffset * 4) * continuousColumnWidth
                let targetX = max(0, ox - config.plotInset)
                let maxScroll = max(0, scrollView.contentSize.width - scrollView.bounds.width)
                scrollView.setContentOffset(CGPoint(x: min(maxScroll, targetX), y: 0), animated: false)
            } else if config.isContinuousWeekly {
                let lastDataWeekStart = startOfWeek(for: lastDataDate)
                let today = cal.startOfDay(for: Date())
                let currentWeekStart = startOfWeek(for: today)
                let anchorWeekStart = max(lastDataWeekStart, currentWeekStart)
                let weekOffset = cal.dateComponents([.day], from: minWeekStart, to: anchorWeekStart).day ?? (1000 * 7)
                let ox = config.plotInset + CGFloat(weekOffset) * weeklyColumnWidth
                let targetX = max(0, ox - config.plotInset)
                let maxScroll = max(0, scrollView.contentSize.width - scrollView.bounds.width)
                scrollView.setContentOffset(CGPoint(x: min(maxScroll, targetX), y: 0), animated: false)
            } else if config.isContinuousMonthly {
                var comps = cal.dateComponents([.year, .month], from: lastDataDate)
                comps.day = 1
                let lastDataMonthStart = cal.date(from: comps) ?? lastDataDate
                var currentComps = cal.dateComponents([.year, .month], from: cal.startOfDay(for: Date()))
                currentComps.day = 1
                let currentMonthStart = cal.date(from: currentComps) ?? lastDataMonthStart
                let anchorMonthStart = max(lastDataMonthStart, currentMonthStart)
                let dayOffset = cal.dateComponents([.day], from: minMonthStart, to: anchorMonthStart).day ?? 0
                let ox = config.plotInset + CGFloat(dayOffset) * monthlyDayWidth
                let targetX = max(0, ox - config.plotInset)
                let maxScroll = max(0, scrollView.contentSize.width - scrollView.bounds.width)
                scrollView.setContentOffset(CGPoint(x: min(maxScroll, targetX), y: 0), animated: false)
            } else if scrollView.contentSize.width > scrollView.bounds.width {
                let ox = scrollView.contentSize.width - scrollView.bounds.width
                scrollView.setContentOffset(CGPoint(x: ox, y: 0), animated: false)
            }
            fireScrollDelegate()
        }
    }


    private func computeRange() {
        if config.isContinuousDaily {
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            let bounds = dateBounds()
            let rangeStart = cal.date(byAdding: .day, value: -7, to: bounds?.start ?? today) ?? today
            let rangeEnd = cal.date(byAdding: .day, value: 7, to: bounds?.end ?? today) ?? today
            minDate = cal.startOfDay(for: rangeStart)
            maxDate = cal.startOfDay(for: rangeEnd)
            let daySpan = cal.dateComponents([.day], from: minDate, to: maxDate).day ?? 0
            timelineDays = max(14, daySpan + 1)
        }
        
        if config.isContinuousWeekly {
            let cal = Calendar.current
            let thisWeekStart = startOfWeek(for: Date())
            let bounds = dateBounds()
            let startAnchor = startOfWeek(for: bounds?.start ?? thisWeekStart)
            let endAnchor = startOfWeek(for: bounds?.end ?? thisWeekStart)
            minWeekStart = cal.date(byAdding: .weekOfYear, value: -4, to: startAnchor) ?? thisWeekStart
            let maxWeekStart = cal.date(byAdding: .weekOfYear, value: 4, to: endAnchor) ?? thisWeekStart
            let weekSpan = cal.dateComponents([.weekOfYear], from: minWeekStart, to: maxWeekStart).weekOfYear ?? 0
            timelineWeeks = max(12, weekSpan + 1)
        }
        
        if config.isContinuousMonthly {
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            let bounds = dateBounds()
            let startBase = startOfMonth(for: bounds?.start ?? today, calendar: cal)
            let endBase = startOfMonth(for: bounds?.end ?? today, calendar: cal)
            minMonthStart = cal.date(byAdding: .month, value: -2, to: startBase) ?? startBase
            let maxMonthStart = cal.date(byAdding: .month, value: 2, to: endBase) ?? endBase
            let endOfMaxMonth = cal.date(byAdding: DateComponents(month: 1, day: -1), to: maxMonthStart) ?? maxMonthStart
            let total = cal.dateComponents([.day], from: minMonthStart, to: endOfMaxMonth).day ?? 0
            totalMonthDays = max(90, total + 1)
        }

        var vals: [Double] = []
        for pt in dataPoints {
            if let v = pt.value    { vals.append(v) }
            if let v = pt.minValue { vals.append(v) }
            if let v = pt.maxValue { vals.append(v) }
        }
        
        if config.title == "Heart Rate" {
            var targetMin = 70.0
            var targetMax = 90.0
            if !vals.isEmpty {
                let actualMin = vals.min()!
                let actualMax = vals.max()!
                while actualMin <= targetMin { targetMin -= 10.0 }
                while actualMax >= targetMax { targetMax += 10.0 }
            }
            yMin = targetMin - 4
            yMax = targetMax + 2
            
        } else if config.title == "Blood Pressure" {
            var targetMin = 60.0
            var targetMax = 140.0
            if !vals.isEmpty {
                let actualMin = vals.min()!
                let actualMax = vals.max()!
                while actualMin <= targetMin { targetMin -= 20.0 }
                while actualMax >= targetMax { targetMax += 20.0 }
            }
            yMin = targetMin - 5
            yMax = targetMax + 5
            
        } else if config.title == "Blood Glucose", let glucoseRange = config.glucoseTargetRange {
            var targetMin = glucoseRange.min
            var targetMax = glucoseRange.max
            if !vals.isEmpty {
                let actualMin = vals.min()!
                let actualMax = vals.max()!
                while actualMin <= targetMin { targetMin -= 10.0 }
                while actualMax >= targetMax { targetMax += 10.0 }
            }
            yMin = targetMin
            yMax = targetMax + 2

        } else if config.title == "Body Weight" {
            let base = config.baselineValue > 0 ? config.baselineValue : (vals.first ?? 80.0)
            if !vals.isEmpty {
                let actualMin = vals.min()!
                let actualMax = vals.max()!
                
                let maxDiff = max(abs(actualMax - base), abs(base - actualMin))
                if maxDiff > 10 {
                    bodyWeightStep = 5.0
                } else if maxDiff > 5 {
                    bodyWeightStep = 2.0
                } else if maxDiff > 2 {
                    bodyWeightStep = 1.0
                } else {
                    bodyWeightStep = 0.5
                }
                
                var bMin = base - bodyWeightStep
                var bMax = base + bodyWeightStep
                while actualMin <= bMin { bMin -= bodyWeightStep }
                while actualMax >= bMax { bMax += bodyWeightStep }
                
                yMin = bMin - (bodyWeightStep * 0.4)
                yMax = bMax + (bodyWeightStep * 0.4)
            } else {
                bodyWeightStep = 0.5
                yMin = base - 0.7
                yMax = base + 0.7
            }
            
        } else {
            guard !vals.isEmpty else { yMin = 0; yMax = 100; return }
            let lo  = vals.min()!
            let hi  = vals.max()!
            let pad = max((hi - lo) * 0.20, 5)
            yMin    = (lo - pad).rounded(.down)
            yMax    = (hi + pad).rounded(.up)
        }
    }

    private func dateBounds() -> (start: Date, end: Date)? {
        let dates = dataPoints.compactMap { chartDate(from: $0.fullDate) }.map {
            Calendar.current.startOfDay(for: $0)
        }
        guard let start = dates.min(), let end = dates.max() else { return nil }
        return (start, end)
    }

    private func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month], from: date)
        comps.day = 1
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }


    private func redraw() {
        lastRenderedPeriodKey = currentVisiblePeriodKey()
        visibleXLabels.removeAll()
        gridPathLayer = nil
        horizontalGridLayer = nil
        monthSeparatorLayer = nil
        yAxisView.subviews.forEach              { $0.removeFromSuperview() }
        yAxisView.layer.sublayers?.forEach      { $0.removeFromSuperlayer() }
        plotCanvas.subviews.forEach             { $0.removeFromSuperview() }
        plotCanvas.layer.sublayers?.forEach     { $0.removeFromSuperlayer() }

        drawHorizontalGrid()
        if config.isContinuousDaily || config.isContinuousWeekly || config.isContinuousMonthly {
            updateDynamicViewport()
        } else {
            drawVerticalGrid()
            drawXAxisLabels()
        }
        drawYAxisLabels()

        let visiblePoints = plottedPointsForCurrentViewport()
        if visiblePoints.isEmpty {
            drawEmptyLabel()
        } else {
            drawData(using: visiblePoints)
        }
    }


    private var continuousColumnWidth: CGFloat {
        let visible = scrollView.bounds.width
        let available = visible - (config.plotInset * 2)
        return max(30, available / 4.0)
    }
    
    private var weeklyColumnWidth: CGFloat {
        let visible = scrollView.bounds.width
        let available = visible - (config.plotInset * 2)
        return max(30, available / 7.0)
    }
    
    private var monthlyDayWidth: CGFloat {
        let visible = scrollView.bounds.width
        let available = visible - (config.plotInset * 2)
        let daysInCurrentMonth = Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30
        return max(8, available / CGFloat(daysInCurrentMonth))
    }
    
    private func monthlyDate(forColumn col: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: col, to: minMonthStart) ?? minMonthStart
    }

    private func chartH() -> CGFloat { plotCanvas.bounds.height - config.xAxisHeight }

    private func yPos(_ value: Double) -> CGFloat {
        let topPad: CGFloat = 3
        guard yMax > yMin else { return topPad }
        let availableH = chartH() - topPad
        return topPad + availableH * CGFloat((yMax - value) / (yMax - yMin))
    }

    private func xCenter(_ i: Int) -> CGFloat {
        if config.isContinuousDaily {
            let pt = dataPoints[i]
            guard let fd = pt.fullDate, let d = chartDate(from: fd), let h = pt.hourOfDay else {
                return config.plotInset + (CGFloat(i) + 0.5) * config.columnWidth 
            }
            let dayOffset = Calendar.current.dateComponents([.day], from: minDate, to: d).day ?? 0
            let cWidth = continuousColumnWidth
            let xOffset = CGFloat(dayOffset * 4) * cWidth + CGFloat(h / 6.0) * cWidth
            return config.plotInset + xOffset
        } else if config.isContinuousWeekly {
            let pt = dataPoints[i]
            guard let fd = pt.fullDate, let d = chartDate(from: fd) else {
                return config.plotInset + (CGFloat(i) + 0.5) * weeklyColumnWidth
            }
            let dayOffset = Calendar.current.dateComponents([.day], from: minWeekStart, to: d).day ?? 0
            return config.plotInset + (CGFloat(dayOffset) + 0.5) * weeklyColumnWidth
        } else if config.isContinuousMonthly {
            let pt = dataPoints[i]
            guard let fd = pt.fullDate, let d = chartDate(from: fd) else {
                return config.plotInset + (CGFloat(i) + 0.5) * monthlyDayWidth
            }
            let dayOffset = Calendar.current.dateComponents([.day], from: minMonthStart, to: d).day ?? 0
            return config.plotInset + (CGFloat(dayOffset) + 0.5) * monthlyDayWidth
        } else {
            return config.plotInset + (CGFloat(i) + 0.5) * config.columnWidth
        }
    }

    private func niceFloat(_ v: Double) -> String {
        if config.title == "Body Weight" {
            return String(format: "%.1f", v)
        }
        return v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
    }

    private func currentVisiblePeriodKey() -> String? {
        let cal = Calendar.current
        let df = Self.sharedDF
        let offsetX = scrollView.contentOffset.x
        let visibleW = scrollView.bounds.width

        if config.isContinuousDaily {
            let dayW = continuousColumnWidth * 4
            let centerCol = max(0, Int(((offsetX + visibleW / 2) - config.plotInset) / dayW))
            guard let centerDate = cal.date(byAdding: .day, value: centerCol, to: minDate) else { return nil }
            return df.string(from: centerDate)
        }

        if config.isContinuousWeekly {
            let cWidth = weeklyColumnWidth
            let centerCol = max(0, Int(((offsetX + visibleW / 2) - config.plotInset) / cWidth))
            let startCol = max(0, centerCol - (centerCol % 7))
            guard let weekStart = cal.date(byAdding: .day, value: startCol, to: minWeekStart) else { return nil }
            return "week:\(df.string(from: weekStart))"
        }

        if config.isContinuousMonthly {
            let dayW = monthlyDayWidth
            let centerCol = max(0, Int(((offsetX + visibleW / 2) - config.plotInset) / dayW))
            guard let centerDate = cal.date(byAdding: .day, value: centerCol, to: minMonthStart) else { return nil }
            let comps = cal.dateComponents([.year, .month], from: centerDate)
            return String(format: "month:%04d-%02d", comps.year ?? 0, comps.month ?? 0)
        }

        return nil
    }

    private func plottedPointsForCurrentViewport() -> [ChartDataPoint] {
        let cal = Calendar.current

        if config.isContinuousDaily {
            let offsetX = scrollView.contentOffset.x
            let visibleW = scrollView.bounds.width
            let dayW = continuousColumnWidth * 4
            let centerCol = max(0, Int(((offsetX + visibleW / 2) - config.plotInset) / dayW))
            guard let centerDate = cal.date(byAdding: .day, value: centerCol, to: minDate),
                  let bufferedStart = cal.date(byAdding: .day, value: -3, to: centerDate),
                  let bufferedEnd = cal.date(byAdding: .day, value: 3, to: centerDate) else { return [] }
            
            return dataPoints.filter { point in
                guard let date = chartDate(from: point.fullDate) else { return false }
                return date >= bufferedStart && date <= bufferedEnd
            }
        }

        if config.isContinuousWeekly {
            let offsetX = scrollView.contentOffset.x
            let visibleW = scrollView.bounds.width
            let cWidth = weeklyColumnWidth
            let centerCol = max(0, Int(((offsetX + visibleW / 2) - config.plotInset) / cWidth))
            let startCol = max(0, centerCol - (centerCol % 7))
            guard let weekStart = cal.date(byAdding: .day, value: startCol - 7, to: minWeekStart),
                  let weekEnd = cal.date(byAdding: .day, value: 20, to: weekStart) else { return [] }
            return dataPoints.filter { point in
                guard let date = chartDate(from: point.fullDate) else { return false }
                return date >= weekStart && date <= weekEnd
            }
        }

        if config.isContinuousMonthly {
            let offsetX = scrollView.contentOffset.x
            let visibleW = scrollView.bounds.width
            let dayW = monthlyDayWidth
            let centerCol = max(0, Int(((offsetX + visibleW / 2) - config.plotInset) / dayW))
            guard let centerDate = cal.date(byAdding: .day, value: centerCol, to: minMonthStart) else { return [] }
            var comps = cal.dateComponents([.year, .month], from: centerDate)
            comps.day = 1
            guard let monthStart = cal.date(from: comps),
                  let bufferedStart = cal.date(byAdding: .month, value: -1, to: monthStart),
                  let bufferedEnd = cal.date(byAdding: DateComponents(month: 2, day: -1), to: monthStart) else { return [] }
            return dataPoints.filter { point in
                guard let date = chartDate(from: point.fullDate) else { return false }
                return date >= bufferedStart && date <= bufferedEnd
            }
        }

        return dataPoints
    }

    private func generateYLabels() -> [Double] {
        if config.title == "Heart Rate" || config.title == "Blood Pressure" || config.title == "Blood Glucose" {
            let step = config.title == "Blood Pressure" ? 20.0 : 10.0
            let start = ceil(yMin / step) * step
            var labels: [Double] = []
            var curr = start
            while curr <= yMax {
                labels.append(curr)
                curr += step
            }
            return labels
        } else if config.title == "Body Weight" {
            let base = config.baselineValue > 0 ? config.baselineValue : ((yMin + yMax) / 2)
            let step = bodyWeightStep
            var labels: [Double] = []
            var curr = base
            while curr >= yMin {
                labels.append(curr)
                curr -= step
            }
            curr = base + step
            while curr <= yMax {
                labels.append(curr)
                curr += step
            }
            return Array(Set(labels)).sorted()
        } else {
            let steps = config.yGridLines
            var labels: [Double] = []
            for i in 0...steps {
                let ratio = Double(i) / Double(steps)
                labels.append(yMin + ratio * (yMax - yMin))
            }
            return labels
        }
    }


    private func drawYAxisLabels() {
        let font  = UIFont.systemFont(ofSize: 11, weight: .regular)
        let labels = generateYLabels()

        for yValue in labels {
            let yPos = self.yPos(yValue)
            
            let lbl = UILabel()
            lbl.text          = niceFloat(yValue)
            lbl.font          = font
            lbl.textColor     = .secondaryLabel
            lbl.textAlignment = .right
            let rightInset: CGFloat = config.title == "Body Weight" ? 2 : 8
            lbl.frame         = CGRect(x: 0, y: yPos - 8, width: config.yAxisWidth - rightInset, height: 16)
            yAxisView.addSubview(lbl)
        }
    }


    private func drawHorizontalGrid() {
        let plotW  = plotCanvas.bounds.width
        let labels = generateYLabels()

        let path = UIBezierPath()
        for yValue in labels {
            let y = self.yPos(yValue)
            path.move(to: CGPoint(x: 0,     y: y))
            path.addLine(to: CGPoint(x: plotW, y: y))
        }

        if horizontalGridLayer == nil {
            let layer = CAShapeLayer()
            layer.fillColor  = UIColor.clear.cgColor
            layer.strokeColor = UIColor.separator.withAlphaComponent(0.45).cgColor
            layer.lineWidth  = 1
            layer.lineDashPattern = [4, 4]
            plotCanvas.layer.addSublayer(layer)
            horizontalGridLayer = layer
        }
        horizontalGridLayer?.path        = path.cgPath
        horizontalGridLayer?.strokeColor = UIColor.separator.withAlphaComponent(0.45).cgColor
        horizontalGridLayer?.frame       = plotCanvas.bounds
    }


    private func drawVerticalGrid() {
        if config.isContinuousDaily { return }
        
        let h     = chartH()
        let topPad = verticalGridTopY()
        
        guard !dataPoints.isEmpty else { return }
        let step  = verticalGridStep()

        for i in stride(from: 0, to: dataPoints.count, by: step) {
            let x = xCenter(i)
            addDashedLine(to: plotCanvas.layer,
                          from: CGPoint(x: x, y: topPad),
                          to:   CGPoint(x: x, y: h),
                          color: UIColor.separator.withAlphaComponent(0.35))
        }
        let last = dataPoints.count - 1
        if last % step != 0 {
            let x = xCenter(last)
            addDashedLine(to: plotCanvas.layer,
                          from: CGPoint(x: x, y: topPad),
                          to:   CGPoint(x: x, y: h),
                          color: UIColor.separator.withAlphaComponent(0.35))
        }
    }



    private func verticalGridStep() -> Int {
        let visible  = scrollView.bounds.width
        let maxLines = max(1, Int(visible / 70))        
        return max(1, Int(ceil(Double(dataPoints.count) / Double(maxLines))))
    }


    private func drawXAxisLabels() {
        if config.isContinuousDaily { return }
        
        let bottomY = plotCanvas.bounds.height - config.xAxisHeight + 5
        let font    = UIFont.systemFont(ofSize: 11, weight: .regular)
        
        guard !dataPoints.isEmpty else { return }
        let step    = verticalGridStep()

        for i in stride(from: 0, to: dataPoints.count, by: step) {
            addXLabel(text: dataPoints[i].day, cx: xCenter(i), y: bottomY, font: font)
        }
        let last = dataPoints.count - 1
        if last % step != 0 {
            addXLabel(text: dataPoints[last].day, cx: xCenter(last), y: bottomY, font: font)
        }
    }

    private func addXLabel(text: String, cx: CGFloat, y: CGFloat, font: UIFont) {
        let lblW: CGFloat = 54
        let lbl  = UILabel()
        lbl.text                      = text
        lbl.font                      = font
        lbl.textColor                 = .secondaryLabel
        lbl.textAlignment             = .center
        lbl.adjustsFontSizeToFitWidth = true
        lbl.minimumScaleFactor        = 0.7
        lbl.frame = CGRect(x: cx - lblW/2, y: y, width: lblW, height: config.xAxisHeight - 5)
        plotCanvas.addSubview(lbl)
    }

    
    private func updateDynamicViewport() {
        let offsetX = scrollView.contentOffset.x
        let visibleWidth = scrollView.bounds.width
        
        if config.isContinuousMonthly {
            let cal = Calendar.current
            let dayW = monthlyDayWidth
            let minX = max(0, offsetX - dayW * 2)
            let maxX = min(scrollView.contentSize.width, offsetX + visibleWidth + dayW * 2)
            let startCol = Int(minX / dayW)
            let endCol   = min(Int(maxX / dayW), totalMonthDays - 1)
            
            guard startCol <= endCol else { return }
            
            let font    = UIFont.systemFont(ofSize: 10, weight: .regular)
            let bottomY = plotCanvas.bounds.height - config.xAxisHeight + 5
            var currentVisibleKeys = Set<Int>()
            let topPad = verticalGridTopY()
            let h = chartH()
            
            let gridPath = UIBezierPath()
            let sepPath  = UIBezierPath()
            
            for col in startCol...endCol {
                let date    = monthlyDate(forColumn: col)
                let weekday = cal.component(.weekday, from: date) 
                let day     = cal.component(.day,     from: date)
                let x = config.plotInset + (CGFloat(col) + 0.5) * dayW
                let monthRange = cal.range(of: .day, in: .month, for: date)
                let lastDayOfMonth = monthRange?.count ?? day
                
                if day == 1 || day == lastDayOfMonth {
                    let sepX = day == 1
                        ? config.plotInset + CGFloat(col) * dayW
                        : config.plotInset + CGFloat(col + 1) * dayW
                    let fullH = plotCanvas.bounds.height - 20   
                    sepPath.move(to: CGPoint(x: sepX, y: 8))
                    sepPath.addLine(to: CGPoint(x: sepX, y: fullH))
                }
                
                if weekday == 1 {
                    gridPath.move(to: CGPoint(x: x, y: topPad))
                    gridPath.addLine(to: CGPoint(x: x, y: h))
                    
                    currentVisibleKeys.insert(col)
                    if visibleXLabels[col] == nil {
                        let lbl = UILabel()
                        lbl.text = "\(day)"
                        lbl.font = font
                        lbl.textColor = .secondaryLabel
                        lbl.textAlignment = .center
                        let lblW: CGFloat = 28
                        lbl.frame = CGRect(x: x - lblW/2, y: bottomY, width: lblW, height: config.xAxisHeight - 5)
                        plotCanvas.addSubview(lbl)
                        visibleXLabels[col] = lbl
                    }
                }
            }
            
            for key in visibleXLabels.keys where !currentVisibleKeys.contains(key) {
                visibleXLabels[key]?.removeFromSuperview()
                visibleXLabels.removeValue(forKey: key)
            }
            
            if gridPathLayer == nil {
                let layer = CAShapeLayer()
                layer.strokeColor = UIColor.separator.withAlphaComponent(0.35).cgColor
                layer.lineWidth = 1
                layer.lineDashPattern = [4, 4]
                plotCanvas.layer.insertSublayer(layer, at: 0)
                gridPathLayer = layer
            }
            gridPathLayer?.path = gridPath.cgPath
            
            if monthSeparatorLayer == nil {
                let layer = CAShapeLayer()
                layer.strokeColor = UIColor.systemGray2.withAlphaComponent(0.7).cgColor
                layer.lineWidth = 1.5
                layer.lineDashPattern = nil
                plotCanvas.layer.insertSublayer(layer, at: 1)
                monthSeparatorLayer = layer
            }
            monthSeparatorLayer?.path = sepPath.cgPath
            return
        }
        
        if config.isContinuousWeekly {
            let cWidth = weeklyColumnWidth
            let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            let minX = max(0, offsetX - cWidth * 2)
            let maxX = min(scrollView.contentSize.width, offsetX + visibleWidth + cWidth * 2)
            let startCol = Int(minX / cWidth)
            let endCol = Int(maxX / cWidth)
            
            var currentVisibleKeys = Set<Int>()
            let font    = UIFont.systemFont(ofSize: 11, weight: .regular)
            let bottomY = plotCanvas.bounds.height - config.xAxisHeight + 5
            let h = chartH()
            let topPad = verticalGridTopY()
            let dashedPath = UIBezierPath()
            
            for col in startCol...endCol {
                currentVisibleKeys.insert(col)
                let xCenter = config.plotInset + (CGFloat(col) + 0.5) * cWidth
                let xBoundary = config.plotInset + CGFloat(col) * cWidth
                
                if visibleXLabels[col] == nil {
                    let lbl = UILabel()
                    lbl.text = dayNames[col % 7]
                    lbl.font = font
                    lbl.textColor = .secondaryLabel
                    lbl.textAlignment = .center
                    lbl.adjustsFontSizeToFitWidth = true
                    lbl.minimumScaleFactor = 0.7
                    let lblW: CGFloat = 42
                    lbl.frame = CGRect(x: xCenter - lblW/2, y: bottomY, width: lblW, height: config.xAxisHeight - 5)
                    plotCanvas.addSubview(lbl)
                    visibleXLabels[col] = lbl
                }
                
                dashedPath.move(to: CGPoint(x: xBoundary, y: topPad))
                dashedPath.addLine(to: CGPoint(x: xBoundary, y: h))
                
                if col == endCol {
                    let xEnd = config.plotInset + CGFloat(col + 1) * cWidth
                    dashedPath.move(to: CGPoint(x: xEnd, y: topPad))
                    dashedPath.addLine(to: CGPoint(x: xEnd, y: h))
                }
            }

            for key in visibleXLabels.keys where !currentVisibleKeys.contains(key) {
                visibleXLabels[key]?.removeFromSuperview()
                visibleXLabels.removeValue(forKey: key)
            }
            if gridPathLayer == nil {
                let layer = CAShapeLayer()
                layer.strokeColor = UIColor.separator.withAlphaComponent(0.35).cgColor
                layer.lineWidth = 1
                layer.lineDashPattern = [4, 4]
                plotCanvas.layer.insertSublayer(layer, at: 0)
                gridPathLayer = layer
            }
            gridPathLayer?.path = dashedPath.cgPath
            monthSeparatorLayer?.path = nil
            return
        }
        
        let cWidth = continuousColumnWidth
        let minX = max(0, offsetX - cWidth)
        let maxX = min(scrollView.contentSize.width, offsetX + visibleWidth + cWidth)
        
        let startChunk = Int(minX / cWidth)
        let endChunk = Int(maxX / cWidth)
        
        var currentVisibleKeys = Set<Int>()
        let font = UIFont.systemFont(ofSize: 11, weight: .regular)
        let bottomY = plotCanvas.bounds.height - config.xAxisHeight + 5
        let labelsStr = ["12 AM", "6", "12 PM", "6"]
        
        for chunkIndex in startChunk...endChunk {
            currentVisibleKeys.insert(chunkIndex)
            if visibleXLabels[chunkIndex] == nil {
                let lbl = UILabel()
                lbl.text = labelsStr[chunkIndex % 4]
                lbl.font = font
                lbl.textColor = .secondaryLabel
                lbl.textAlignment = .center
                lbl.adjustsFontSizeToFitWidth = true
                lbl.minimumScaleFactor = 0.7
                let x = config.plotInset + CGFloat(chunkIndex) * cWidth
                let lblW: CGFloat = 54
                lbl.frame = CGRect(x: x - lblW/2, y: bottomY, width: lblW, height: config.xAxisHeight - 5)
                plotCanvas.addSubview(lbl)
                visibleXLabels[chunkIndex] = lbl
            }
        }
        
        for key in visibleXLabels.keys {
            if !currentVisibleKeys.contains(key) {
                visibleXLabels[key]?.removeFromSuperview()
                visibleXLabels.removeValue(forKey: key)
            }
        }
        
        let h = chartH()
        let topPad = verticalGridTopY()
        let path = UIBezierPath()
        for chunkIndex in startChunk...endChunk {
            let x = config.plotInset + CGFloat(chunkIndex) * cWidth
            path.move(to: CGPoint(x: x, y: topPad))
            path.addLine(to: CGPoint(x: x, y: h))
        }
        
        if gridPathLayer == nil {
            let layer = CAShapeLayer()
            layer.strokeColor = UIColor.separator.withAlphaComponent(0.35).cgColor
            layer.lineWidth = 1
            layer.lineDashPattern = [4, 4]
            plotCanvas.layer.insertSublayer(layer, at: 0) 
            gridPathLayer = layer
        }
        gridPathLayer?.path = path.cgPath
    }


    private func drawEmptyLabel() {
        let lbl    = UILabel()
        lbl.text          = "No data available"
        lbl.textColor     = .tertiaryLabel
        lbl.font          = UIFont.systemFont(ofSize: 13)
        lbl.textAlignment = .center
        lbl.frame         = CGRect(x: 0, y: 0,
                                   width: plotCanvas.bounds.width,
                                   height: chartH())
        plotCanvas.addSubview(lbl)
    }


    private func drawData(using points: [ChartDataPoint]) {
        switch config.chartType {
        case .line:        drawLine(using: points)
        case .rangeBar:    drawRangeBar(using: points)
        case .baselineBar: drawBaselineBar(using: points)
        }
    }


    private func drawLine(using points: [ChartDataPoint]) {
        let color  = config.tintColor
        let h      = chartH()

        var pts: [CGPoint] = []
        for dp in points {
            guard let value = dp.value,
                  let sourceIndex = pointIndexByID[dp.id] else { continue }
            pts.append(CGPoint(x: xCenter(sourceIndex), y: yPos(value)))
        }
        guard !pts.isEmpty else { return }

        let fillPath = UIBezierPath()
        fillPath.move(to: pts[0])
        pts.dropFirst().forEach { fillPath.addLine(to: $0) }
        fillPath.addLine(to: CGPoint(x: pts.last!.x, y: h))
        fillPath.addLine(to: CGPoint(x: pts[0].x,    y: h))
        fillPath.close()

        let grad        = CAGradientLayer()
        grad.frame      = CGRect(x: 0, y: 0, width: plotCanvas.bounds.width, height: h)
        grad.colors     = [color.withAlphaComponent(0.20).cgColor, UIColor.clear.cgColor]
        grad.startPoint = CGPoint(x: 0.5, y: 0)
        grad.endPoint   = CGPoint(x: 0.5, y: 1)
        let msk = CAShapeLayer(); msk.path = fillPath.cgPath
        grad.mask = msk
        plotCanvas.layer.addSublayer(grad)

        let linePath = UIBezierPath()
        linePath.move(to: pts[0])
        pts.dropFirst().forEach { linePath.addLine(to: $0) }
        let sl         = CAShapeLayer()
        sl.path        = linePath.cgPath
        sl.strokeColor = color.cgColor
        sl.fillColor   = UIColor.clear.cgColor
        sl.lineWidth   = 2.5
        sl.lineJoin    = .round
        sl.lineCap     = .round
        plotCanvas.layer.addSublayer(sl)

        for p in pts {
            let r: CGFloat = 4.5
            let dot         = CAShapeLayer()
            dot.path        = UIBezierPath(ovalIn: CGRect(x: p.x-r, y: p.y-r,
                                                          width: r*2, height: r*2)).cgPath
            dot.fillColor   = color.cgColor
            dot.strokeColor = UIColor.white.cgColor
            dot.lineWidth   = 1.5
            plotCanvas.layer.addSublayer(dot)
        }
    }

    private var activeBarWidth: CGFloat {
        if config.isContinuousMonthly {
            return max(4, monthlyDayWidth * 0.68)
        }
        if config.isContinuousWeekly {
            if config.title == "Blood Pressure" || config.title == "Body Weight" {
                return max(6, continuousColumnWidth * 0.15)
            }
            return max(6, weeklyColumnWidth * 0.40)
        }
        if config.isContinuousDaily {
            return max(6, continuousColumnWidth * 0.15)
        }
        return config.columnWidth * 0.25
    }


    private func drawRangeBar(using points: [ChartDataPoint]) {
        let color = config.tintColor
        let barW  = activeBarWidth
        let h     = chartH()
        let bgCol = color.withAlphaComponent(0.12)

        for dp in points {
            guard let sourceIndex = pointIndexByID[dp.id] else { continue }
            let cx = xCenter(sourceIndex)

            guard let lo = dp.minValue, let hi = dp.maxValue else { continue }
            let top  = yPos(hi)
            let barH = max(yPos(lo) - top, 4)
            let bgR  = expandedPillRect(forDarkPill: CGRect(x: cx - barW/2, y: top, width: barW, height: barH), withinHeight: h)
            let bg   = CAShapeLayer()
            bg.path      = UIBezierPath(roundedRect: bgR, cornerRadius: barW/2).cgPath
            bg.fillColor = bgCol.cgColor
            plotCanvas.layer.addSublayer(bg)

            let fgR  = CGRect(x: cx - barW/2, y: top, width: barW, height: barH)
            let fg   = CAShapeLayer()
            fg.path      = UIBezierPath(roundedRect: fgR, cornerRadius: barW/2).cgPath
            fg.fillColor = color.cgColor
            plotCanvas.layer.addSublayer(fg)
        }
    }


    private func drawBaselineBar(using points: [ChartDataPoint]) {
        let posCol = config.tintColor
        let negCol = UIColor(red: 0.80, green: 0.50, blue: 0.50, alpha: 1)
        let bgCol  = UIColor.systemGray5
        let barW   = activeBarWidth
        let h      = chartH()

        for dp in points {
            guard let sourceIndex = pointIndexByID[dp.id] else { continue }
            let cx  = xCenter(sourceIndex)
            guard let val = dp.value else { continue }
            let base = dp.baselineValue ?? (config.baselineValue > 0 ? config.baselineValue : (yMax + yMin) / 2)
            let baseY  = yPos(base)
            let valY = yPos(val)
            let top  = min(valY, baseY)
            let barH = max(abs(baseY - valY), 4)
            let fgR  = CGRect(x: cx - barW/2, y: top, width: barW, height: barH)

            let bgR = bodyWeightBackgroundRect(centerX: cx, barWidth: barW, height: h)
            let bg  = CAShapeLayer()
            bg.path      = UIBezierPath(roundedRect: bgR, cornerRadius: barW/2).cgPath
            bg.fillColor = bgCol.cgColor
            plotCanvas.layer.addSublayer(bg)

            let fg   = CAShapeLayer()
            fg.path      = baselineBarPath(rect: fgR, baselineY: baseY).cgPath
            fg.fillColor = (val >= base ? posCol : negCol).cgColor
            plotCanvas.layer.addSublayer(fg)

            addDashedLine(to: plotCanvas.layer,
                          from: CGPoint(x: cx - barW * 1.1, y: baseY),
                          to:   CGPoint(x: cx + barW * 1.1, y: baseY),
                          color: posCol.withAlphaComponent(0.55),
                          dash: [4, 3],
                          width: 1.2)
        }
    }


    private func addDashedLine(to layer: CALayer,
                                from start: CGPoint,
                                to end: CGPoint,
                                color: UIColor,
                                dash: [NSNumber] = [5, 5],
                                width: CGFloat = 1) {
        let sl            = CAShapeLayer()
        let p             = UIBezierPath()
        p.move(to: start)
        p.addLine(to: end)
        sl.path           = p.cgPath
        sl.strokeColor    = color.cgColor
        sl.fillColor      = UIColor.clear.cgColor
        sl.lineWidth      = width
        sl.lineDashPattern = dash
        layer.addSublayer(sl)
    }

    private func expandedPillRect(forDarkPill rect: CGRect, withinHeight height: CGFloat) -> CGRect {
        let expansion: CGFloat
        switch config.title {
        case "Blood Pressure":
            expansion = rect.height * 0.4
        case "Body Weight":
            expansion = 3
        default:
            let targetHeight = max(rect.height * 1.5, rect.height + 8)
            expansion = (targetHeight - rect.height) / 2
        }

        let topLimit: CGFloat
        let bottomLimit: CGFloat
        if config.title == "Body Weight" {
            let yLabelPositions = generateYLabels().map { yPos($0) }
            topLimit = (yLabelPositions.min() ?? 0) + 3
            bottomLimit = (yLabelPositions.max() ?? height) - 3
        } else {
            topLimit = 0
            bottomLimit = height
        }

        let y = max(topLimit, rect.minY - expansion)
        let maxY = min(bottomLimit, rect.maxY + expansion)
        return CGRect(x: rect.minX, y: y, width: rect.width, height: max(4, maxY - y))
    }

    private func bodyWeightBackgroundRect(centerX: CGFloat, barWidth: CGFloat, height: CGFloat) -> CGRect {
        guard config.title == "Body Weight" else {
            return CGRect(x: centerX - barWidth / 2, y: 0, width: barWidth, height: height)
        }

        let yLabelPositions = generateYLabels().map { yPos($0) }
        let topLimit = (yLabelPositions.min() ?? 0) + 3
        let bottomLimit = (yLabelPositions.max() ?? height) - 3

        return CGRect(
            x: centerX - barWidth / 2,
            y: topLimit,
            width: barWidth,
            height: max(4, bottomLimit - topLimit)
        )
    }

    private func verticalGridTopY() -> CGFloat {
        return generateYLabels()
            .map { yPos($0) }
            .min() ?? 3
    }

    private func baselineBarPath(rect: CGRect, baselineY: CGFloat) -> UIBezierPath {
        let radius = rect.width / 2
        let path = UIBezierPath()

        if rect.minY < baselineY {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addArc(withCenter: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                        radius: radius,
                        startAngle: .pi,
                        endAngle: -.pi / 2,
                        clockwise: true)
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addArc(withCenter: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                        radius: radius,
                        startAngle: -.pi / 2,
                        endAngle: 0,
                        clockwise: true)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
            path.addArc(withCenter: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                        radius: radius,
                        startAngle: .pi,
                        endAngle: .pi / 2,
                        clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
            path.addArc(withCenter: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                        radius: radius,
                        startAngle: .pi / 2,
                        endAngle: 0,
                        clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }

        path.close()
        return path
    }
    @objc private func handleChartTap(_ gesture: UITapGestureRecognizer) {
        let tapLocation = gesture.location(in: plotCanvas)

        if highlightedPointIndex != nil {
            clearHighlight()
            return
        }

        let visiblePoints = plottedPointsForCurrentViewport()
        guard !visiblePoints.isEmpty else { return }

        var bestIndex: Int?
        var bestDist: CGFloat = .greatestFiniteMagnitude

        for dp in visiblePoints {
            guard let sourceIndex = pointIndexByID[dp.id] else { continue }
            let cx = xCenter(sourceIndex)

            var pointY: CGFloat
            if let val = dp.value {
                pointY = yPos(val)
            } else if let hi = dp.maxValue, let lo = dp.minValue {
                pointY = (yPos(hi) + yPos(lo)) / 2
            } else {
                continue
            }

            let dist = hypot(tapLocation.x - cx, tapLocation.y - pointY)
            if dist < bestDist {
                bestDist = dist
                bestIndex = sourceIndex
            }
        }

        guard let idx = bestIndex, bestDist < 40 else { return }

        highlightedPointIndex = idx
        drawHighlight(for: idx)
        scrollDelegate?.vitalChartDidHighlightPoint(dataPoints[idx])
    }

    private func drawHighlight(for index: Int) {
        let dp = dataPoints[index]
        let cx = xCenter(index)
        let h = chartH()

        let lineLayer = CAShapeLayer()
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: cx, y: 0))
        linePath.addLine(to: CGPoint(x: cx, y: h))
        lineLayer.path = linePath.cgPath
        lineLayer.strokeColor = UIColor.systemGray3.cgColor
        lineLayer.lineWidth = 1.5
        lineLayer.zPosition = 999
        plotCanvas.layer.addSublayer(lineLayer)
        highlightLineLayer = lineLayer

        let valueText: String
        if let hi = dp.maxValue, let lo = dp.minValue {
            valueText = "\(niceFloat(hi))/\(niceFloat(lo))"
        } else if let val = dp.value {
            valueText = niceFloat(val)
        } else {
            valueText = "--"
        }

        let dateText = tooltipDateString(for: dp)

        let tooltip = UIView()
        tooltip.backgroundColor = UIColor.systemGray6
        tooltip.layer.cornerRadius = 10
        tooltip.layer.shadowColor = UIColor.black.cgColor
        tooltip.layer.shadowOpacity = 0.1
        tooltip.layer.shadowOffset = CGSize(width: 0, height: 2)
        tooltip.layer.shadowRadius = 6

        let valueLbl = UILabel()
        let valAttr = NSMutableAttributedString(
            string: valueText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold).rounded,
                .foregroundColor: UIColor.label
            ]
        )
        valAttr.append(NSAttributedString(
            string: " \(config.unit)",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium).rounded,
                .foregroundColor: UIColor.secondaryLabel
            ]
        ))
        valueLbl.attributedText = valAttr
        valueLbl.textAlignment = .center

        let dateLbl = UILabel()
        dateLbl.text = dateText
        dateLbl.font = UIFont.systemFont(ofSize: 13, weight: .medium).rounded
        dateLbl.textColor = .secondaryLabel
        dateLbl.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [valueLbl, dateLbl])
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        tooltip.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: tooltip.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: tooltip.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: tooltip.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: tooltip.trailingAnchor, constant: -14)
        ])

        let tooltipSize = tooltip.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let translatedX = cx - scrollView.contentOffset.x
        let tooltipY: CGFloat = -tooltipSize.height - 4
        var tooltipX = translatedX - tooltipSize.width / 2

        let visibleMinX: CGFloat = 4
        let visibleMaxX: CGFloat = self.bounds.width - config.yAxisWidth - 4
        tooltipX = max(visibleMinX, min(tooltipX, visibleMaxX - tooltipSize.width))

        tooltip.frame = CGRect(x: tooltipX, y: tooltipY, width: tooltipSize.width, height: tooltipSize.height)

        tooltip.alpha = 0
        tooltip.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        self.addSubview(tooltip)
        highlightTooltip = tooltip

        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            tooltip.alpha = 1
            tooltip.transform = .identity
        }
    }

    func clearHighlight() {
        guard highlightedPointIndex != nil else { return }
        highlightLineLayer?.removeFromSuperlayer()
        highlightLineLayer = nil

        if let tooltip = highlightTooltip {
            UIView.animate(withDuration: 0.15, animations: {
                tooltip.alpha = 0
                tooltip.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }) { _ in
                tooltip.removeFromSuperview()
            }
        }
        highlightTooltip = nil
        highlightedPointIndex = nil
        scrollDelegate?.vitalChartDidHighlightPoint(nil)
    }

    private func tooltipDateString(for point: ChartDataPoint) -> String {
        let df = DateFormatter()
        df.dateFormat = "dd-MM-yyyy"
        let displayDf = DateFormatter()
        displayDf.dateFormat = "d MMM"

        guard let fdStr = point.fullDate, let date = df.date(from: fdStr) else {
            return point.day
        }

        let dateStr = displayDf.string(from: date)

        if let hour = point.hourOfDay {
            let startHour = Int(hour)
            let isPM = startHour >= 12
            let displayHour = startHour == 0 ? 12 : (startHour > 12 ? startHour - 12 : startHour)
            let suffix = isPM ? "PM" : "AM"

            let endHourRaw = startHour + 1
            let endIsPM = endHourRaw >= 12
            let endDisplay = endHourRaw == 0 ? 12 : (endHourRaw > 12 ? endHourRaw - 12 : endHourRaw)
            let endSuffix = endIsPM ? "PM" : "AM"

            if suffix == endSuffix {
                return "\(dateStr), \(displayHour)–\(endDisplay) \(suffix)"
            }
            return "\(dateStr), \(displayHour) \(suffix)–\(endDisplay) \(endSuffix)"
        }

        return dateStr
    }
}

extension VitalChartView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        clearHighlight()
        if config.isContinuousDaily || config.isContinuousWeekly || config.isContinuousMonthly {
            updateDynamicViewport()
            let periodKey = currentVisiblePeriodKey()
            if periodKey != lastRenderedPeriodKey {
                redraw()
            }
            fireScrollDelegate()
        }
    }

    private func fireScrollDelegate() {
        let cal = Calendar.current
        let offsetX = scrollView.contentOffset.x
        let visibleW = scrollView.bounds.width

        if config.isContinuousDaily {
            let dayW = continuousColumnWidth * 4   

            let startPx = offsetX
            let endPx = offsetX + visibleW
            
            let startDays = Double(startPx - config.plotInset) / Double(dayW)
            let endDays = Double(endPx - config.plotInset) / Double(dayW)
            
            let startDate = minDate.addingTimeInterval(startDays * 24 * 3600)
            let endDate = minDate.addingTimeInterval(endDays * 24 * 3600)

            scrollDelegate?.vitalChartDidScroll(visibleStartDate: startDate, visibleEndDate: endDate)

        } else if config.isContinuousWeekly {
            let cWidth = weeklyColumnWidth
            let startCol = max(0, Int((offsetX - config.plotInset) / cWidth))
            let visibleCols = Int(visibleW / cWidth)
            let endCol = startCol + visibleCols - 1
            let startDate = cal.date(byAdding: .day, value: startCol, to: minWeekStart)
            let endDate   = cal.date(byAdding: .day, value: endCol, to: minWeekStart)
            scrollDelegate?.vitalChartDidScroll(visibleStartDate: startDate, visibleEndDate: endDate)

        } else if config.isContinuousMonthly {
            let dayW = monthlyDayWidth
            let startCol = max(0, Int((offsetX - config.plotInset) / dayW))
            let endCol   = min(Int((offsetX + visibleW - config.plotInset) / dayW), totalMonthDays - 1)
            let startDate = cal.date(byAdding: .day, value: startCol, to: minMonthStart)
            let endDate   = cal.date(byAdding: .day, value: endCol, to: minMonthStart)
            scrollDelegate?.vitalChartDidScroll(visibleStartDate: startDate, visibleEndDate: endDate)
        }
    }
}
