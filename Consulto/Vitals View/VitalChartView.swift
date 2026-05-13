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
    /// Stores the actual tap x (in plotCanvas coords) for step-line charts so the
    /// highlight line and tooltip appear exactly where the user tapped.
    private var lastStepLineTapX: CGFloat?

    // Watch HR daily "latest reading" intro animation
    private var latestHighlightWorkItem: DispatchWorkItem?
    private var watchHRLatestDotLayer: CAShapeLayer?
    private var watchHRLatestLabel: UILabel?
    private var watchHRGreyLayers: [CAShapeLayer] = []

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
                let weekOffset = cal.dateComponents([.day], from: minWeekStart, to: lastDataWeekStart).day ?? (1000 * 7)
                let ox = config.plotInset + CGFloat(weekOffset) * weeklyColumnWidth
                let targetX = max(0, ox - config.plotInset)
                let maxScroll = max(0, scrollView.contentSize.width - scrollView.bounds.width)
                scrollView.setContentOffset(CGPoint(x: min(maxScroll, targetX), y: 0), animated: false)
            } else if config.isContinuousMonthly {
                var comps = cal.dateComponents([.year, .month], from: lastDataDate)
                comps.day = 1
                let lastDataMonthStart = cal.date(from: comps) ?? lastDataDate
                let dayOffset = cal.dateComponents([.day], from: minMonthStart, to: lastDataMonthStart).day ?? 0
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
                var step: Double = 0.5
                if maxDiff > 10 {
                    step = 5.0
                } else if maxDiff > 5 {
                    step = 2.0
                } else if maxDiff > 2 {
                    step = 1.0
                }
                
                // Ensure step is large enough to keep labels count <= 6 (5 intervals max)
                while (actualMax - actualMin) / step > 5.0 {
                    if step == 0.5 { step = 1.0 }
                    else if step == 1.0 { step = 2.0 }
                    else if step == 2.0 { step = 5.0 }
                    else if step == 5.0 { step = 10.0 }
                    else { step *= 2 }
                }
                
                bodyWeightStep = step
                
                var bMin = base - step
                var bMax = base + step
                while actualMin <= bMin { bMin -= step }
                while actualMax >= bMax { bMax += step }
                
                yMin = bMin - (step * 0.4)
                yMax = bMax + (step * 0.4)
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
        latestHighlightWorkItem?.cancel()
        latestHighlightWorkItem = nil
        watchHRLatestDotLayer?.removeFromSuperlayer()
        watchHRLatestDotLayer = nil
        watchHRLatestLabel?.removeFromSuperview()
        watchHRLatestLabel = nil
        watchHRGreyLayers.removeAll()
        yAxisView.subviews.forEach              { $0.removeFromSuperview() }
        yAxisView.layer.sublayers?.forEach      { $0.removeFromSuperlayer() }
        plotCanvas.subviews.forEach             { $0.removeFromSuperview() }
        plotCanvas.layer.sublayers?.forEach     { $0.removeFromSuperlayer() }

        // For continuous charts, scope the Y-axis to the currently-visible
        // data so each viewport gets its own correctly-scaled axis.
        if config.isContinuousDaily || config.isContinuousWeekly || config.isContinuousMonthly {
            let visiblePoints = plottedPointsForCurrentViewport()
            computeVisibleYRange(for: visiblePoints)
        }
        normalizeYPadding()

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
        let topPad: CGFloat = 8
        guard yMax > yMin else { return topPad }
        let availableH = chartH() - topPad
        return topPad + availableH * CGFloat((yMax - value) / (yMax - yMin))
    }

    private func xCenter(_ i: Int) -> CGFloat {
        if config.isContinuousDaily {
            let pt = dataPoints[i]
            guard let fd = pt.fullDate, let d = chartDate(from: fd) else {
                return config.plotInset + (CGFloat(i) + 0.5) * config.columnWidth
            }
            let dayOffset = Calendar.current.dateComponents([.day], from: minDate, to: d).day ?? 0
            let cWidth = continuousColumnWidth
            // Step line: position at center of the day (no hourOfDay needed)
            if config.chartType == .stepLine {
                return config.plotInset + CGFloat(dayOffset * 4 + 2) * cWidth
            }
            guard let h = pt.hourOfDay else {
                return config.plotInset + (CGFloat(i) + 0.5) * config.columnWidth
            }
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
            var step = config.title == "Blood Pressure" ? 20.0 : 10.0
            let maxLabels = 6

            // Build labels with the current step; if too many, double the step and retry.
            func buildLabels(step: Double) -> [Double] {
                let start = ceil(yMin / step) * step
                var result: [Double] = []
                var curr = start
                while curr <= yMax {
                    result.append(curr)
                    curr += step
                }
                return result
            }

            var labels = buildLabels(step: step)
            while labels.count > maxLabels {
                step *= 2
                labels = buildLabels(step: step)
            }
            return labels
        } else if config.title == "Body Weight" {
            let base = config.baselineValue > 0 ? config.baselineValue : ((yMin + yMax) / 2)
            var step = bodyWeightStep
            let maxLabels = 4

            func buildLabels(step: Double) -> [Double] {
                var result: [Double] = []
                var curr = base
                while curr >= yMin {
                    result.append(curr)
                    curr -= step
                }
                curr = base + step
                while curr <= yMax {
                    result.append(curr)
                    curr += step
                }
                return Array(Set(result)).sorted()
            }

            var labels = buildLabels(step: step)
            while labels.count > maxLabels {
                if step == 0.5 { step = 1.0 }
                else if step == 1.0 { step = 2.0 }
                else if step == 2.0 { step = 5.0 }
                else if step == 5.0 { step = 10.0 }
                else { step *= 2 }
                labels = buildLabels(step: step)
            }
            return labels
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

    /// Recomputes yMin / yMax from only the currently-visible data points.
    /// Uses the same ±step padding logic as computeRange() but scoped to
    /// what the user can actually see right now.  Falls back to global range
    /// when there are no visible values (e.g. empty viewport).
    private func computeVisibleYRange(for visiblePoints: [ChartDataPoint]) {
        var vals: [Double] = []
        for pt in visiblePoints {
            if let v = pt.value    { vals.append(v) }
            if let v = pt.minValue { vals.append(v) }
            if let v = pt.maxValue { vals.append(v) }
        }
        guard !vals.isEmpty else { return }   // keep current global range if no data

        let actualMin = vals.min()!
        let actualMax = vals.max()!

        if config.title == "Heart Rate" {
            let step = 10.0
            var lo = (floor(actualMin / step) - 1) * step   // one step below the floor
            var hi = (ceil(actualMax  / step) + 1) * step   // one step above the ceiling
            // guarantee at least two grid lines
            if hi - lo < step * 2 { lo -= step; hi += step }
            yMin = lo - 4
            yMax = hi + 2

        } else if config.title == "Blood Pressure" {
            let step = 20.0
            var lo = (floor(actualMin / step) - 1) * step
            var hi = (ceil(actualMax  / step) + 1) * step
            if hi - lo < step * 2 { lo -= step; hi += step }
            yMin = lo - 5
            yMax = hi + 5

        } else if config.title == "Blood Glucose", let glucoseRange = config.glucoseTargetRange {
            let step = 10.0
            var lo = (floor(actualMin / step) - 1) * step
            var hi = (ceil(actualMax  / step) + 1) * step
            // never hide the target-range band
            lo = min(lo, floor(glucoseRange.min / step) * step)
            hi = max(hi, ceil(glucoseRange.max  / step) * step + step)
            yMin = lo
            yMax = hi

        } else if config.title == "Body Weight" {
            let base = config.baselineValue > 0 ? config.baselineValue : ((actualMin + actualMax) / 2)
            let maxDiff = max(abs(actualMax - base), abs(base - actualMin))
            var step: Double
            if maxDiff > 10      { step = 5.0 }
            else if maxDiff > 5  { step = 2.0 }
            else if maxDiff > 2  { step = 1.0 }
            else                 { step = 0.5 }

            // Ensure step is large enough to keep labels count <= 6 (5 intervals max)
            while (actualMax - actualMin) / step > 5.0 {
                if step == 0.5 { step = 1.0 }
                else if step == 1.0 { step = 2.0 }
                else if step == 2.0 { step = 5.0 }
                else if step == 5.0 { step = 10.0 }
                else { step *= 2 }
            }

            bodyWeightStep = step
            var bMin = base - step
            var bMax = base + step
            while actualMin <= bMin { bMin -= step }
            while actualMax >= bMax { bMax += step }
            yMin = bMin - (step * 0.4)
            yMax = bMax + (step * 0.4)

        } else {
            let pad = max((actualMax - actualMin) * 0.20, 5)
            yMin = (actualMin - pad).rounded(.down)
            yMax = (actualMax + pad).rounded(.up)
        }
    }

    /// Adjusts yMin / yMax so that the visual gap above the top grid line
    /// and below the bottom grid line is the same across every vital type.
    /// Uses half the label step as padding on each side.
    private func normalizeYPadding() {
        let labels = generateYLabels()
        guard labels.count >= 2,
              let topLabel = labels.last,
              let bottomLabel = labels.first else { return }
        let step = labels[1] - labels[0]
        let padding = step * 0.3
        yMax = topLabel + padding
        yMin = bottomLabel - padding
    }

    /// Tears down and redraws only the Y-axis labels and the horizontal grid
    /// lines — much cheaper than a full redraw() when only the range changed.
    private func refreshYAxis() {
        // Clear old axis labels
        yAxisView.subviews.forEach { $0.removeFromSuperview() }
        yAxisView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        // Redraw labels
        drawYAxisLabels()

        // Redraw horizontal grid
        let plotW  = plotCanvas.bounds.width
        let labels = generateYLabels()
        let path = UIBezierPath()
        for yValue in labels {
            let y = self.yPos(yValue)
            path.move(to: CGPoint(x: 0,     y: y))
            path.addLine(to: CGPoint(x: plotW, y: y))
        }
        horizontalGridLayer?.path = path.cgPath
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
        case .stepLine:    drawStepLine(using: points)
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

    // MARK: - Step Line (Resting HR daily)
    /// Draws one flat horizontal segment per day, connected by vertical steps between days.
    /// Puts a filled circle at the centre of each day as a tap target.
    private func drawStepLine(using points: [ChartDataPoint]) {
        guard !points.isEmpty else { return }
        let color = config.tintColor
        let cal   = Calendar.current
        let cWidth = continuousColumnWidth
        let df = DateFormatter()
        df.dateFormat = "dd-MM-yyyy"

        struct DaySegment {
            let startX: CGFloat
            let endX:   CGFloat
            let centerX: CGFloat
            let y:      CGFloat
            let point:  ChartDataPoint
        }

        var segments: [DaySegment] = []
        for dp in points {
            guard let fd = dp.fullDate,
                  let d  = chartDate(from: fd),
                  let val = dp.value else { continue }
            let dayOffset = cal.dateComponents([.day], from: minDate, to: d).day ?? 0
            let startX  = config.plotInset + CGFloat(dayOffset * 4) * cWidth
            let endX    = config.plotInset + CGFloat((dayOffset + 1) * 4) * cWidth
            let centerX = (startX + endX) / 2
            segments.append(DaySegment(startX: startX, endX: endX, centerX: centerX,
                                       y: yPos(val), point: dp))
        }
        guard !segments.isEmpty else { return }
        segments.sort { $0.startX < $1.startX }

        // Build step path
        let path = UIBezierPath()
        for (i, seg) in segments.enumerated() {
            if i == 0 {
                path.move(to: CGPoint(x: seg.startX, y: seg.y))
            } else if seg.startX > segments[i - 1].endX {
                // Gap between days — lift pen and continue
                path.move(to: CGPoint(x: seg.startX, y: seg.y))
            }
            // Horizontal span across the day
            path.addLine(to: CGPoint(x: seg.endX, y: seg.y))
            // Vertical connector to next segment
            if i + 1 < segments.count {
                let next = segments[i + 1]
                if next.startX <= seg.endX + 1 {   // consecutive days
                    path.addLine(to: CGPoint(x: seg.endX, y: next.y))
                }
            }
        }

        let sl = CAShapeLayer()
        sl.path        = path.cgPath
        sl.strokeColor = color.cgColor
        sl.fillColor   = UIColor.clear.cgColor
        sl.lineWidth   = 2.5
        sl.lineJoin    = .miter
        sl.lineCap     = .square
        plotCanvas.layer.addSublayer(sl)
        // No dots — the whole line is tappable via x-range detection
    }

    private var activeBarWidth: CGFloat {
        if config.isContinuousMonthly {
            return max(4, monthlyDayWidth * 0.68)
        }
        if config.isContinuousWeekly {
            if config.title == "Blood Pressure" || config.title == "Body Weight" {
                return max(6, continuousColumnWidth * 0.15)
            }
            // Watch HR & Blood Glucose pills — slimmer
            if (config.title == "Heart Rate" || config.title == "Blood Glucose") && config.chartType == .rangeBar {
                return max(5, weeklyColumnWidth * 0.26)
            }
            return max(6, weeklyColumnWidth * 0.40)
        }
        if config.isContinuousDaily {
            if config.title == "Heart Rate" && config.chartType == .rangeBar {
                // Narrower Apple-Health-style hourly pill
                return max(5, continuousColumnWidth * 0.13)
            }
            return max(6, continuousColumnWidth * 0.15)
        }
        return config.columnWidth * 0.25
    }


    private func drawRangeBar(using points: [ChartDataPoint]) {
        let color    = config.tintColor
        let barW     = activeBarWidth
        let h        = chartH()
        let bgCol    = color.withAlphaComponent(0.12)
        let isHRPill = config.title == "Heart Rate"
        // Watch HR daily intro animation: show latest pill in colour, rest in grey
        let isWatchHRDaily = isHRPill && config.isContinuousDaily

        // Find the most-recent hourly bucket (latest date + highest hour)
        let latestPoint: ChartDataPoint? = isWatchHRDaily ? points.max(by: { a, b in
            let df = DateFormatter()
            df.dateFormat = "dd-MM-yyyy"
            let da = df.date(from: a.fullDate ?? "") ?? .distantPast
            let db = df.date(from: b.fullDate ?? "") ?? .distantPast
            if da == db { return (a.hourOfDay ?? 0) < (b.hourOfDay ?? 0) }
            return da < db
        }) : nil

        let greyFill = UIColor.systemGray2.withAlphaComponent(0.45).cgColor

        for dp in points {
            guard let sourceIndex = pointIndexByID[dp.id] else { continue }
            let cx = xCenter(sourceIndex)

            guard let lo = dp.minValue, let hi = dp.maxValue else { continue }
            let top  = yPos(hi)
            let barH = max(yPos(lo) - top, 4)

            // Skip translucent background pill for Heart Rate and Blood Glucose (cleaner look)
            let skipBackgroundPill = config.title == "Heart Rate" || config.title == "Blood Glucose"
            if !skipBackgroundPill {
                let bgR = expandedPillRect(forDarkPill: CGRect(x: cx - barW/2, y: top, width: barW, height: barH), withinHeight: h)
                let bg  = CAShapeLayer()
                bg.path      = UIBezierPath(roundedRect: bgR, cornerRadius: barW/2).cgPath
                bg.fillColor = bgCol.cgColor
                plotCanvas.layer.addSublayer(bg)
            }

            let isLatest   = isWatchHRDaily && dp.id == latestPoint?.id
            let pillColor  = isWatchHRDaily ? (isLatest ? color.cgColor : greyFill) : color.cgColor

            let fgR = CGRect(x: cx - barW/2, y: top, width: barW, height: barH)
            let fg  = CAShapeLayer()
            fg.path      = UIBezierPath(roundedRect: fgR, cornerRadius: barW/2).cgPath
            fg.fillColor = pillColor
            plotCanvas.layer.addSublayer(fg)

            if isWatchHRDaily && !isLatest { watchHRGreyLayers.append(fg) }

            // ── Latest pill: dot + value label ──
            if isLatest {
                let avgBPM = (hi + lo) / 2
                let dotY   = yPos(avgBPM)
                let dotR: CGFloat = 5

                let dot = CAShapeLayer()
                dot.path        = UIBezierPath(ovalIn: CGRect(x: cx - dotR, y: dotY - dotR,
                                                              width: dotR * 2, height: dotR * 2)).cgPath
                dot.fillColor   = color.cgColor
                dot.strokeColor = UIColor.white.cgColor
                dot.lineWidth   = 1
                plotCanvas.layer.addSublayer(dot)
                watchHRLatestDotLayer = dot

                // Convert plotCanvas point → VitalChartView coords for the floating label
                let ptInSelf = plotCanvas.convert(CGPoint(x: cx, y: dotY), to: self)

                let label = UILabel()
                label.text      = niceFloat(avgBPM)
                label.font      = UIFont.systemFont(ofSize: 21, weight: .bold)
                label.textColor = color
                label.sizeToFit()

                let labelW = label.frame.width
                let labelH = label.frame.height
                // Try placing to the right of the dot; fall back to left if clipped by y-axis
                var labelX = ptInSelf.x + dotR + 4
                if labelX + labelW > self.bounds.width - config.yAxisWidth - 4 {
                    labelX = ptInSelf.x - dotR - 4 - labelW
                }
                label.frame = CGRect(x: labelX,
                                     y: ptInSelf.y - labelH / 2,
                                     width: labelW, height: labelH)
                self.addSubview(label)
                watchHRLatestLabel = label
            }
        }

        // ── Schedule the "reveal all" animation after 1.5 s ──
        guard isWatchHRDaily, !watchHRGreyLayers.isEmpty else { return }
        let workItem = DispatchWorkItem { [weak self] in
            self?.revealWatchHRLatestIntro()
        }
        latestHighlightWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }

    private func revealWatchHRLatestIntro(animated: Bool = true) {
        guard !watchHRGreyLayers.isEmpty else { return }
        let tintCG = config.tintColor.cgColor
        
        if animated {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.5)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
            for layer in watchHRGreyLayers { layer.fillColor = tintCG }
            CATransaction.commit()
            
            UIView.animate(withDuration: 0.3) {
                self.watchHRLatestDotLayer?.opacity = 0
                self.watchHRLatestLabel?.alpha = 0
            } completion: { _ in
                self.watchHRLatestDotLayer?.removeFromSuperlayer()
                self.watchHRLatestDotLayer = nil
                self.watchHRLatestLabel?.removeFromSuperview()
                self.watchHRLatestLabel = nil
                self.watchHRGreyLayers.removeAll()
            }
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for layer in watchHRGreyLayers { layer.fillColor = tintCG }
            self.watchHRLatestDotLayer?.opacity = 0
            CATransaction.commit()
            
            self.watchHRLatestLabel?.alpha = 0
            self.watchHRLatestDotLayer?.removeFromSuperlayer()
            self.watchHRLatestDotLayer = nil
            self.watchHRLatestLabel?.removeFromSuperview()
            self.watchHRLatestLabel = nil
            self.watchHRGreyLayers.removeAll()
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
        case "Heart Rate" where config.chartType == .rangeBar:
            // Watch HR pills: same tight expansion as Blood Pressure
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

        // ── Step line (Resting HR daily): match by day x-range, highlight at actual tap x ──
        if config.chartType == .stepLine && config.isContinuousDaily {
            let cWidth = continuousColumnWidth
            let dayW   = cWidth * 4
            let df = DateFormatter()
            df.dateFormat = "dd-MM-yyyy"
            let dayIndex = max(0, Int((tapLocation.x - config.plotInset) / dayW))
            guard let tapDate = Calendar.current.date(byAdding: .day, value: dayIndex, to: minDate) else { return }
            let tapDateStr = df.string(from: tapDate)
            for dp in visiblePoints {
                guard dp.fullDate == tapDateStr,
                      let val = dp.value,
                      let sourceIdx = pointIndexByID[dp.id] else { continue }
                // Accept tap anywhere along the horizontal step line (whole day width, ±30 pt y)
                if abs(tapLocation.y - yPos(val)) < 30 {
                    lastStepLineTapX = tapLocation.x   // remember exact tap position
                    highlightedPointIndex = sourceIdx
                    drawHighlight(for: sourceIdx)
                    scrollDelegate?.vitalChartDidHighlightPoint(dataPoints[sourceIdx])
                }
                return
            }
            return
        }

        // ── Default nearest-point matching ──
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
        // For step-line taps use the stored tap x so the line appears under the finger;
        // for everything else use the computed centre of the data point.
        let cx: CGFloat
        if config.chartType == .stepLine, let tapX = lastStepLineTapX {
            cx = tapX
        } else {
            cx = xCenter(index)
        }
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
            if config.title == "Heart Rate" {
                if hi == lo {
                    valueText = niceFloat(hi)
                } else {
                    valueText = "\(niceFloat(lo))–\(niceFloat(hi))"
                }
            } else {
                valueText = "\(niceFloat(hi))/\(niceFloat(lo))"
            }
        } else if let val = dp.value {
            valueText = niceFloat(val)
        } else {
            valueText = "--"
        }

        // For step-line use the tapped x to derive the hour so the tooltip shows
        // "d MMM, H–H+1 AM/PM" instead of just the date.
        let dateText: String
        if config.chartType == .stepLine, let tapX = lastStepLineTapX {
            let cWidth = continuousColumnWidth
            let dayW   = cWidth * 4
            let posInDay = (tapX - config.plotInset).truncatingRemainder(dividingBy: dayW)
            let rawHour  = max(0, min(23, Int(posInDay / cWidth * 6)))

            let df = DateFormatter(); df.dateFormat = "dd-MM-yyyy"
            let displayDf = DateFormatter(); displayDf.dateFormat = "d MMM"
            let baseDate: String = {
                if let fdStr = dp.fullDate, let d = df.date(from: fdStr) {
                    return displayDf.string(from: d)
                }
                return tooltipDateString(for: dp)
            }()

            let startH   = rawHour
            let isPM     = startH >= 12
            let h12      = startH == 0 ? 12 : (startH > 12 ? startH - 12 : startH)
            let suffix   = isPM ? "PM" : "AM"
            let endRaw   = startH + 1
            let endIsPM  = endRaw >= 12
            let endH12   = endRaw == 0 ? 12 : (endRaw > 12 ? endRaw - 12 : endRaw)
            let endSuffix = endIsPM ? "PM" : "AM"

            if suffix == endSuffix {
                dateText = "\(baseDate), \(h12)–\(endH12) \(suffix)"
            } else {
                dateText = "\(baseDate), \(h12) \(suffix)–\(endH12) \(endSuffix)"
            }
        } else {
            dateText = tooltipDateString(for: dp)
        }

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
        valueLbl.textAlignment = .left

        let dateLbl = UILabel()
        dateLbl.text = dateText
        dateLbl.font = UIFont.systemFont(ofSize: 13, weight: .medium).rounded
        dateLbl.textColor = .secondaryLabel
        dateLbl.textAlignment = .left

        // For step-line (Resting HR) add a header label matching Apple Health style
        // For Watch HR range pills add a "RANGE" header
        var stackViews: [UIView] = []
        let isRestingHR = config.title == "Heart Rate" && (config.chartType == .stepLine || dp.glucoseType == "Resting")
        
        if isRestingHR {
            let headerLbl = UILabel()
            headerLbl.text      = "RESTING HEART RATE"
            headerLbl.font      = UIFont.systemFont(ofSize: 14, weight: .semibold).rounded
            headerLbl.textColor = .secondaryLabel
            headerLbl.textAlignment = .left
            stackViews.append(headerLbl)
        } else if config.chartType == .rangeBar && config.title == "Heart Rate" {
            let headerLbl = UILabel()
            if let lo = dp.minValue, let hi = dp.maxValue, abs(hi - lo) > 0.01 {
                headerLbl.text = "RANGE"
            } else {
                headerLbl.text = "AVERAGE"
            }
            headerLbl.font      = UIFont.systemFont(ofSize: 14, weight: .semibold).rounded
            headerLbl.textColor = .secondaryLabel
            headerLbl.textAlignment = .left
            stackViews.append(headerLbl)
        }
        stackViews.append(contentsOf: [valueLbl, dateLbl])

        let stack = UIStackView(arrangedSubviews: stackViews)
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .leading
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
        lastStepLineTapX = nil

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
        
        if scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating {
            if latestHighlightWorkItem != nil {
                latestHighlightWorkItem?.cancel()
                latestHighlightWorkItem = nil
                revealWatchHRLatestIntro(animated: true)
            }
        }
        
        if config.isContinuousDaily || config.isContinuousWeekly || config.isContinuousMonthly {
            updateDynamicViewport()

            // Recompute Y-axis from the data currently visible in the viewport
            let visiblePoints = plottedPointsForCurrentViewport()
            computeVisibleYRange(for: visiblePoints)
            normalizeYPadding()
            refreshYAxis()

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
