import UIKit

class VitalDetailViewController: UIViewController {
    private struct MetricCardModel {
        let title: String
        let value: String
        let unit: String
        let subtitle: String
        let icon: UIImage?
        let isTextValue: Bool
    }

    private struct VisibleWindow {
        let points: [ChartDataPoint]
        let startDate: Date
        let endDate: Date
        let label: String
        let isCurrentPeriod: Bool
    }

    @IBOutlet weak var heroIconImageView: UIImageView!
    @IBOutlet weak var heroValueLabel: UILabel!
    @IBOutlet weak var heroUnitLabel: UILabel!
    @IBOutlet weak var heroSubtitleLabel: UILabel!
    
    @IBOutlet weak var metricsCollectionView: UICollectionView!
    
    @IBOutlet weak var graphFilterButton: UIButton?
    @IBOutlet weak var graphSegmentedControl: UISegmentedControl?
    @IBOutlet weak var graphContainerView: UIView?
    @IBOutlet weak var customGraphView: UIView?

    @IBOutlet weak var chartInfoView: UIView?
    @IBOutlet weak var chartValueLabel: UILabel?
    @IBOutlet weak var chartDateLabel: UILabel?
    @IBOutlet weak var chartRangeTagLabel: UILabel?

    private var selectedPeriod: Int = 0  
    private var chartInstalled = false
    private weak var vitalChartView: VitalChartView?
    private var metricCards: [MetricCardModel] = []
    private var currentChartPoints: [ChartDataPoint] = []


    var reading: VitalReading? 
    var initialGlucoseFilterType: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.largeTitleDisplayMode = .never
        
        view.backgroundColor = UIColor(hex: "#F5F5F5")
        
        if let scrollView = view.subviews.first(where: { $0 is UIScrollView }) {
            scrollView.backgroundColor = .clear
            for sv in scrollView.subviews {
                sv.backgroundColor = .clear
                if let stackView = sv.subviews.first(where: { $0 is UIStackView }) as? UIStackView {
                    stackView.backgroundColor = .clear
                    for arrangedSub in stackView.arrangedSubviews {
                        arrangedSub.backgroundColor = .clear
                    }
                }
            }
        }
        
        setupHeroSection()
        setupCollectionView()
        setupGraphSection()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataUpdate),
            name: .vitalDataDidUpdate,
            object: nil
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !chartInstalled {
            chartInstalled = true
            installChart()
            UIView.animate(withDuration: 0.22) {
                self.customGraphView?.alpha = 1
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }


    @objc private func handleDataUpdate(_ notification: Notification) {
        guard let currentTitle = reading?.title else { return }
        if let updatedTitle = notification.userInfo?["title"] as? String, updatedTitle != currentTitle {
            return
        }
        let updated = VitalDataStore.shared.loadReadings()
        guard let freshReading = updated.first(where: { $0.title == currentTitle }) else { return }
        reading = freshReading

        setupHeroSection()

        metricsCollectionView.reloadData()

        reloadChart()
    }

    private func setupHeroSection() {
        title = reading?.title
        heroIconImageView.image = reading?.detailIconImage
        heroIconImageView.tintColor = nil 
        
        var latestValueStr = reading?.value ?? "--"
        var subtitleStr = "Today's Logged Reading"
        
        if let currentReading = reading {
            let filteredHourly: [ChartDataPoint]
            let filteredDaily: [ChartDataPoint]
            
            if currentReading.title == "Blood Glucose" {
                filteredHourly = currentReading.hourlyChartData.filter { ($0.glucoseType ?? BloodGlucoseType.fasting.rawValue) == currentFilterType }
                filteredDaily = currentReading.chartData.filter { ($0.glucoseType ?? BloodGlucoseType.fasting.rawValue) == currentFilterType }
            } else {
                filteredHourly = currentReading.hourlyChartData
                filteredDaily = currentReading.chartData
            }

            let lastPoint = filteredHourly.last ?? filteredDaily.last
            if let point = lastPoint {
                if let min = point.minValue, let max = point.maxValue {
                    latestValueStr = "\(Int(max.rounded()))/\(Int(min.rounded()))"
                } else if let val = point.value {
                    latestValueStr = val.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(val)) : String(format: "%.1f", val)
                }
            } else if currentReading.title == "Blood Glucose" {
                latestValueStr = "--"
            }
            
            let df = DateFormatter()
            let today = Date()
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            
            var targetStr: String? = nil
            var isDailyFormat = false
            
            if let lastHourly = filteredHourly.last {
                targetStr = lastHourly.fullDate
            } else if let lastDaily = filteredDaily.last {
                targetStr = lastDaily.day
                isDailyFormat = true
            }
            
            if let targetDateStr = targetStr {
                df.dateFormat = isDailyFormat ? "dd-MMM" : "dd-MM-yyyy"
                let todayStr = df.string(from: today)
                let yesterdayStr = df.string(from: yesterday)
                
                if targetDateStr == todayStr || targetDateStr == "__TODAY__" || targetDateStr == "" {
                    subtitleStr = "Today's Logged Reading"
                } else if targetDateStr == yesterdayStr {
                    subtitleStr = "Yesterday's Logged Reading"
                } else {
                    let parsedDate: Date?
                    let fmt = DateFormatter()
                    fmt.dateFormat = "dd-MM-yyyy"
                    if let d = fmt.date(from: targetDateStr) {
                        parsedDate = d
                    } else {
                        fmt.dateFormat = "dd-MMM"
                        parsedDate = fmt.date(from: targetDateStr)
                    }
                    
                    if let d = parsedDate {
                        fmt.dateFormat = "dd MMM"
                        subtitleStr = "Last logged on \(fmt.string(from: d))"
                    } else {
                        subtitleStr = "Last logged on \(targetDateStr.replacingOccurrences(of: "-", with: " "))"
                    }
                }
            } else {
                if currentReading.title == "Blood Glucose" {
                    subtitleStr = "No logged readings"
                }
            }
        }
        
        heroValueLabel.text = latestValueStr
        heroUnitLabel.text = reading?.unit ?? ""
        heroSubtitleLabel.text = subtitleStr
        
        if let valFont = heroValueLabel.font.fontDescriptor.withDesign(.rounded) {
            heroValueLabel.font = UIFont(descriptor: valFont, size: heroValueLabel.font.pointSize)
        }
        if let unitFont = heroUnitLabel.font.fontDescriptor.withDesign(.rounded) {
            heroUnitLabel.font = UIFont(descriptor: unitFont, size: heroUnitLabel.font.pointSize)
        }
        if let subFont = heroSubtitleLabel.font.fontDescriptor.withDesign(.rounded) {
            heroSubtitleLabel.font = UIFont(descriptor: subFont, size: heroSubtitleLabel.font.pointSize)
        }
    }

    private func setupCollectionView() {
        guard let cv = metricsCollectionView else { return }
        cv.delegate = self
        cv.dataSource = self
        
        if let layout = cv.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = .zero
        }
        
        let nib = UINib(nibName: "VitalMetricCollectionViewCell", bundle: nil)
        cv.register(nib, forCellWithReuseIdentifier: "VitalMetricCollectionViewCell")
        cv.backgroundColor = .clear
    }
    
    private func setupGraphSection() {
        if reading?.title == "Blood Glucose" {
            currentFilterType = initialGlucoseFilterType ?? BloodGlucoseType.from(subtitle: reading?.subtitle).rawValue
            graphFilterButton?.superview?.isHidden = false
            
            let fasting = UIAction(title: "Fasting") { _ in self.updateFilterTitle("Fasting") }
            let afterMeal = UIAction(title: "After meal") { _ in self.updateFilterTitle("After meal") }
            let random = UIAction(title: "Random") { _ in self.updateFilterTitle("Random") }
            
            graphFilterButton?.menu = UIMenu(title: "", children: [fasting, afterMeal, random])
            graphFilterButton?.showsMenuAsPrimaryAction = true
            graphFilterButton?.setTitle(currentFilterType, for: .normal)
            graphFilterButton?.semanticContentAttribute = .forceRightToLeft
            graphFilterButton?.contentHorizontalAlignment = .right
            graphFilterButton?.contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)
            graphFilterButton?.titleEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
        } else {
            graphFilterButton?.superview?.isHidden = true
        }
        
        let font = UIFont(name: "Montserrat-Medium", size: 13) ?? .systemFont(ofSize: 13)
        graphSegmentedControl?.setTitleTextAttributes([.font: font], for: .normal)
        graphSegmentedControl?.setTitleTextAttributes([.font: font], for: .selected)
        graphSegmentedControl?.selectedSegmentIndex = selectedPeriod

        graphSegmentedControl?.addTarget(self, action: #selector(periodChanged(_:)), for: .valueChanged)
        
    }

    @objc private func periodChanged(_ sender: UISegmentedControl) {
        selectedPeriod = sender.selectedSegmentIndex
        reloadChart()
    }


    private func installChart() {
        guard let container = customGraphView else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        container.backgroundColor = .white
        container.layer.cornerRadius = 12
        container.clipsToBounds = false

        let chart = VitalChartView(frame: container.bounds)
        chart.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(chart)
        vitalChartView = chart
        chart.scrollDelegate = self
        reloadChart()
    }

    private func reloadChart() {
        guard let chart = vitalChartView, let reading = reading else { return }
        graphSegmentedControl?.selectedSegmentIndex = selectedPeriod

        let points = chartPoints(for: reading)
        currentChartPoints = points
        let glucoseTargetRange = glucoseTargetRange(for: reading)
        let currentBaseline = currentBaseline(for: reading, points: points)
        let latestRecordedDate: Date? = {
            let df = DateFormatter()
            df.dateFormat = "dd-MM-yyyy"
            return reading.hourlyChartData
                .compactMap { $0.fullDate }
                .compactMap { df.date(from: $0) }
                .max()
        }()

        let config = VitalChartView.Config(
            title:       reading.title,
            baselineValue: currentBaseline,
            glucoseTargetRange: glucoseTargetRange,
            viewportAnchorDate: latestRecordedDate,
            chartType:   reading.chartType,
            tintColor:   reading.iconTint,
            unit:        reading.unit,
            yAxisWidth:  reading.title == "Body Weight" ? 46 : 30,
            xAxisHeight: 30,
            columnWidth: selectedPeriod == 0 ? 40 : 50,
            plotInset:   selectedPeriod == 0 ? 16 : 0,
            yGridLines:  4,
            isContinuousDaily:   selectedPeriod == 0,
            isContinuousWeekly:  selectedPeriod == 1,
            isContinuousMonthly: selectedPeriod == 2
        )
        chart.configure(with: points, config: config)
        updateChartInfo(points: points)
    }


    func updateChartInfo(points: [ChartDataPoint], visibleStartDate: Date? = nil, visibleEndDate: Date? = nil) {
        guard let reading = reading else { return }
        let unit = reading.unit
        let df = DateFormatter()
        df.dateFormat = "dd-MM-yyyy"
        let displayDf = DateFormatter()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        if let hc = chartInfoView?.constraints.first(where: { $0.firstAttribute == .height && $0.secondAttribute == .notAnAttribute }) {
            hc.constant = (selectedPeriod == 0) ? 68 : 70
        }

        if let valLabel = chartValueLabel {
            let base = UIFont.systemFont(ofSize: 25, weight: .bold)
            if let desc = base.fontDescriptor.withDesign(.rounded) {
                valLabel.font = UIFont(descriptor: desc, size: 25)
            }
        }
        if let dateLabel = chartDateLabel {
            let base = UIFont.systemFont(ofSize: 15, weight: .medium)
            if let desc = base.fontDescriptor.withDesign(.rounded) {
                dateLabel.font = UIFont(descriptor: desc, size: 15)
            }
        }
        if let tagLabel = chartRangeTagLabel {
            let base = UIFont.systemFont(ofSize: 11, weight: .semibold)
            if let desc = base.fontDescriptor.withDesign(.rounded) {
                tagLabel.font = UIFont(descriptor: desc, size: 11)
            }
        }
        let window = makeVisibleWindow(
            from: points,
            visibleStartDate: visibleStartDate,
            visibleEndDate: visibleEndDate,
            cal: cal,
            df: df,
            displayDf: displayDf,
            today: today
        )

        if selectedPeriod == 0 {
            chartRangeTagLabel?.text = window.label.contains("–") ? "RANGE" : ""
            chartDateLabel?.text = window.label
            setEdgeValueLabel(from: window.points, reading: reading, unit: unit)
        } else {
            chartRangeTagLabel?.text = extremaDateTag(from: window.points, reading: reading, df: df)
            chartDateLabel?.text = window.label
            setValueLabel(from: window.points, reading: reading, unit: unit)
        }
        metricCards = makeMetricCards(for: reading, window: window, cal: cal, df: df)
        metricsCollectionView.reloadData()
    }

    private func niceValue(_ v: Double, reading: VitalReading) -> String {
        if reading.title == "Body Weight" { return String(format: "%.1f", v) }
        return v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
    }

    private func applyAttributedValue(text: String, unit: String) {
        guard let label = chartValueLabel, let font = label.font else { return }
        let fullString = "\(text) \(unit)"
        let attrString = NSMutableAttributedString(string: fullString)
        let range = (fullString as NSString).range(of: " \(unit)")
        if range.location != NSNotFound {
            let smallFont = UIFont.systemFont(ofSize: font.pointSize * 0.65, weight: .bold)
            if let desc = smallFont.fontDescriptor.withDesign(.rounded) {
                attrString.addAttribute(.font, value: UIFont(descriptor: desc, size: font.pointSize * 0.65), range: range)
            } else {
                attrString.addAttribute(.font, value: smallFont, range: range)
            }
        }
        label.attributedText = attrString
    }

    private func setValueLabel(from pts: [ChartDataPoint], reading: VitalReading, unit: String) {
        if reading.title == "Blood Pressure" {
            let sysVals = pts.compactMap { $0.maxValue }
            let diaVals = pts.compactMap { $0.minValue }
            if sysVals.isEmpty && diaVals.isEmpty {
                applyAttributedValue(text: "--", unit: unit)
                return
            }
            var parts: [String] = []
            if let sLo = sysVals.min(), let sHi = sysVals.max() {
                parts.append(abs(sHi - sLo) < 0.01 ? niceValue(sLo, reading: reading) : "\(niceValue(sLo, reading: reading))–\(niceValue(sHi, reading: reading))")
            }
            if let dLo = diaVals.min(), let dHi = diaVals.max() {
                parts.append(abs(dHi - dLo) < 0.01 ? niceValue(dLo, reading: reading) : "\(niceValue(dLo, reading: reading))–\(niceValue(dHi, reading: reading))")
            }
            applyAttributedValue(text: parts.joined(separator: " / "), unit: unit)
        } else {
            let allVals: [Double] = pts.compactMap { $0.value }
                                  + pts.compactMap { $0.minValue }
                                  + pts.compactMap { $0.maxValue }
            if let lo = allVals.min(), let hi = allVals.max() {
                if abs(hi - lo) < 0.01 {
                    applyAttributedValue(text: "\(niceValue(lo, reading: reading))", unit: unit)
                } else {
                    applyAttributedValue(text: "\(niceValue(lo, reading: reading))–\(niceValue(hi, reading: reading))", unit: unit)
                }
            } else {
                applyAttributedValue(text: "--", unit: unit)
            }
        }
    }

    private func setEdgeValueLabel(from pts: [ChartDataPoint], reading: VitalReading, unit: String) {
        let ordered = sortChronologically(pts)
        guard let startPoint = ordered.first, let endPoint = ordered.last else {
            applyAttributedValue(text: "--", unit: unit)
            return
        }

        let startText = formattedPointValue(startPoint, reading: reading)
        let endText = formattedPointValue(endPoint, reading: reading)

        if startText == endText {
            applyAttributedValue(text: startText, unit: unit)
        } else {
            applyAttributedValue(text: "\(startText) → \(endText)", unit: unit)
        }
    }

    private func sortChronologically(_ points: [ChartDataPoint]) -> [ChartDataPoint] {
        let df = DateFormatter()
        df.dateFormat = "dd-MM-yyyy"
        return points.sorted { lhs, rhs in
            let leftDate = lhs.fullDate.flatMap { df.date(from: $0) } ?? .distantPast
            let rightDate = rhs.fullDate.flatMap { df.date(from: $0) } ?? .distantPast
            if leftDate == rightDate {
                return (lhs.hourOfDay ?? -1) < (rhs.hourOfDay ?? -1)
            }
            return leftDate < rightDate
        }
    }

    private func formattedPointValue(_ point: ChartDataPoint, reading: VitalReading) -> String {
        if reading.title == "Blood Pressure" {
            let sys = point.maxValue.map { niceValue($0, reading: reading) } ?? "--"
            let dia = point.minValue.map { niceValue($0, reading: reading) } ?? "--"
            return "\(sys)/\(dia)"
        }
        if let value = point.value {
            return niceValue(value, reading: reading)
        }
        if let max = point.maxValue {
            return niceValue(max, reading: reading)
        }
        if let min = point.minValue {
            return niceValue(min, reading: reading)
        }
        return "--"
    }

    private func extremaDateTag(from points: [ChartDataPoint], reading: VitalReading, df: DateFormatter) -> String {
        return "RANGE"
    }

    private func makeVisibleWindow(
        from points: [ChartDataPoint],
        visibleStartDate: Date?,
        visibleEndDate: Date?,
        cal: Calendar,
        df: DateFormatter,
        displayDf: DateFormatter,
        today: Date
    ) -> VisibleWindow {
        switch selectedPeriod {
        case 0:
            let targetStart = visibleStartDate ?? today
            let targetEnd = visibleEndDate ?? today
            let centerDate = targetStart.addingTimeInterval(targetEnd.timeIntervalSince(targetStart) / 2)
            let centerDayStart = cal.startOfDay(for: centerDate)
            
            let startDay = cal.startOfDay(for: targetStart)
            let endDay = cal.startOfDay(for: targetEnd)
            let isSameDay = cal.isDate(startDay, inSameDayAs: endDay)
            let hoursFromStart = centerDate.timeIntervalSince(centerDayStart) / 3600
            let isSnapped = abs(hoursFromStart - 12.0) < 0.5
            
            let label: String
            if isSnapped || isSameDay {
                let dayToUse = isSnapped ? centerDayStart : startDay
                displayDf.dateFormat = "d MMM yyyy"
                label = cal.isDateInToday(dayToUse) ? "Today" : displayDf.string(from: dayToUse)
            } else {
                label = rangeLabel(from: targetStart, to: targetEnd, displayDf: displayDf, cal: cal)
            }
            let dayPoints = points.filter { point in
                if isSnapped {
                    let targetString = df.string(from: centerDayStart)
                    return point.fullDate == targetString
                } else {
                    guard let fullDate = point.fullDate, let d = df.date(from: fullDate) else { return false }
                    let pointTime = d.addingTimeInterval((point.hourOfDay ?? 0) * 3600)
                    return pointTime >= targetStart && pointTime <= targetEnd
                }
            }
            return VisibleWindow(
                points: sortChronologically(dayPoints),
                startDate: targetStart,
                endDate: targetEnd,
                label: label,
                isCurrentPeriod: cal.isDate(centerDayStart, inSameDayAs: today)
            )
        case 1:
            let targetStart = visibleStartDate ?? normalizedWeekStart(from: today, cal: cal)
            let targetEnd = visibleEndDate ?? cal.date(byAdding: .day, value: 6, to: targetStart) ?? targetStart
            let weekPoints = points.filter { point in
                guard let fullDate = point.fullDate, let date = df.date(from: fullDate) else { return false }
                return date >= targetStart && date <= targetEnd
            }
            let currentWeekStart = normalizedWeekStart(from: today, cal: cal)
            return VisibleWindow(
                points: sortChronologically(weekPoints),
                startDate: targetStart,
                endDate: targetEnd,
                label: rangeLabel(from: targetStart, to: targetEnd, displayDf: displayDf, cal: cal),
                isCurrentPeriod: cal.isDate(targetStart, inSameDayAs: currentWeekStart)
            )
        default:
            var comps = cal.dateComponents([.year, .month], from: visibleStartDate ?? today)
            comps.day = 1
            let monthStart = cal.date(from: comps) ?? today
            let monthEndFallback = cal.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart
            
            let targetStart = visibleStartDate ?? monthStart
            let targetEnd = visibleEndDate ?? monthEndFallback
            
            let monthPoints = points.filter { point in
                guard let fullDate = point.fullDate, let date = df.date(from: fullDate) else { return false }
                return date >= targetStart && date <= targetEnd
            }
            let currentMonth = cal.dateComponents([.year, .month], from: today)
            let visibleMonth = cal.dateComponents([.year, .month], from: targetStart)
            return VisibleWindow(
                points: sortChronologically(monthPoints),
                startDate: targetStart,
                endDate: targetEnd,
                label: rangeLabel(from: targetStart, to: targetEnd, displayDf: displayDf, cal: cal),
                isCurrentPeriod: currentMonth.year == visibleMonth.year && currentMonth.month == visibleMonth.month
            )
        }
    }

    private func normalizedWeekStart(from date: Date, cal: Calendar) -> Date {
        let startOfDay = cal.startOfDay(for: date)
        let weekday = cal.component(.weekday, from: startOfDay) 
        let daysFromMonday = (weekday + 5) % 7
        return cal.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
    }

    private func rangeLabel(from start: Date, to end: Date, displayDf: DateFormatter, cal: Calendar) -> String {
        displayDf.dateFormat = "d MMM yyyy"
        let endString = displayDf.string(from: end)
        if cal.component(.year, from: start) == cal.component(.year, from: end) {
            displayDf.dateFormat = "d MMM"
            return "\(displayDf.string(from: start))–\(endString)"
        }
        return "\(displayDf.string(from: start))–\(endString)"
    }

    private func makeMetricCards(for reading: VitalReading, window: VisibleWindow, cal: Calendar, df: DateFormatter) -> [MetricCardModel] {
        let shortName: String
        switch reading.title {
        case "Heart Rate": shortName = "HR"
        case "Blood Pressure": shortName = "BP"
        case "Blood Glucose": shortName = "Glucose"
        case "Body Weight": shortName = "Weight"
        default: shortName = ""
        }

        let subtitle = metricSubtitle(for: window, cal: cal)
        let previousPoints = previousWindowPoints(for: reading, currentWindow: window, cal: cal, df: df)
        let variabilityModel = variabilityCard(for: reading, currentWindow: window, current: window.points, previous: previousPoints, cal: cal)

        return [
            MetricCardModel(
                title: "Average \(shortName)",
                value: metricValue(for: reading, points: window.points, kind: .average),
                unit: reading.unit,
                subtitle: subtitle,
                icon: nil,
                isTextValue: false
            ),
            variabilityModel,
            MetricCardModel(
                title: "Peak \(shortName)",
                value: metricValue(for: reading, points: window.points, kind: .peak),
                unit: reading.unit,
                subtitle: subtitle,
                icon: nil,
                isTextValue: false
            ),
            MetricCardModel(
                title: "Base \(shortName)",
                value: metricValue(for: reading, points: window.points, kind: .base),
                unit: reading.unit,
                subtitle: subtitle,
                icon: nil,
                isTextValue: false
            )
        ]
    }

    private enum MetricKind {
        case average
        case peak
        case base
    }

    private func metricValue(for reading: VitalReading, points: [ChartDataPoint], kind: MetricKind) -> String {
        guard !points.isEmpty else { return "--" }

        if reading.title == "Blood Pressure" {
            let sys = points.compactMap(\.maxValue)
            let dia = points.compactMap(\.minValue)
            guard !sys.isEmpty, !dia.isEmpty else { return "--" }

            let sysValue: Double
            let diaValue: Double
            switch kind {
            case .average:
                let rawSys = sys.reduce(0, +) / Double(sys.count)
                let rawDia = dia.reduce(0, +) / Double(dia.count)
                sysValue = floor(rawSys)
                diaValue = floor(rawDia)
            case .peak:
                sysValue = sys.max() ?? 0
                diaValue = dia.max() ?? 0
            case .base:
                sysValue = sys.min() ?? 0
                diaValue = dia.min() ?? 0
            }
            return "\(niceValue(sysValue, reading: reading))/\(niceValue(diaValue, reading: reading))"
        }

        let values = points.compactMap(\.value)
        guard !values.isEmpty else { return "--" }
        switch kind {
        case .average:
            let rawAvg = values.reduce(0, +) / Double(values.count)
            let avg = reading.title == "Body Weight" ? rawAvg : floor(rawAvg)
            return niceValue(avg, reading: reading)
        case .peak:
            return niceValue(values.max() ?? 0, reading: reading)
        case .base:
            return niceValue(values.min() ?? 0, reading: reading)
        }
    }

    private func metricSubtitle(for window: VisibleWindow, cal: Calendar) -> String {
        let displayDf = DateFormatter()
        displayDf.dateFormat = "d MMM"

        switch selectedPeriod {
        case 0:
            return window.isCurrentPeriod ? "TODAY" : displayDf.string(from: window.startDate).uppercased()
        case 1:
            return window.isCurrentPeriod ? "THIS WEEK" : window.label.uppercased()
        default:
            if window.isCurrentPeriod { return "THIS MONTH" }
            return window.label.uppercased()
        }
    }

    private func previousWindowPoints(for reading: VitalReading, currentWindow: VisibleWindow, cal: Calendar, df: DateFormatter) -> [ChartDataPoint] {
        let allPoints = currentChartPoints.isEmpty ? chartPoints(for: reading) : currentChartPoints
        let previousStart: Date
        let previousEnd: Date

        switch selectedPeriod {
        case 0:
            previousStart = cal.date(byAdding: .day, value: -1, to: currentWindow.startDate) ?? currentWindow.startDate
            previousEnd = previousStart
        case 1:
            previousStart = cal.date(byAdding: .day, value: -7, to: currentWindow.startDate) ?? currentWindow.startDate
            previousEnd = cal.date(byAdding: .day, value: -1, to: currentWindow.startDate) ?? currentWindow.startDate
        default:
            previousStart = cal.date(byAdding: .month, value: -1, to: currentWindow.startDate) ?? currentWindow.startDate
            previousEnd = cal.date(byAdding: DateComponents(month: 1, day: -1), to: previousStart) ?? previousStart
        }

        return allPoints.filter { point in
            guard let fullDate = point.fullDate, let date = df.date(from: fullDate) else { return false }
            return date >= previousStart && date <= previousEnd
        }
    }

    private func variabilityCard(for reading: VitalReading, currentWindow: VisibleWindow, current: [ChartDataPoint], previous: [ChartDataPoint], cal: Calendar) -> MetricCardModel {
        let currentSpread = spreadValue(for: reading, points: current)
        let previousSpread = spreadValue(for: reading, points: previous)
        let delta = currentSpread - previousSpread

        let title = "Variability"
        let subtitle: String
        let df = DateFormatter()
        df.dateFormat = "d MMM"

        switch selectedPeriod {
        case 0: 
            if currentWindow.isCurrentPeriod {
                subtitle = "FROM YESTERDAY"
            } else {
                let prevDate = cal.date(byAdding: .day, value: -1, to: currentWindow.startDate) ?? currentWindow.startDate
                subtitle = "FROM \(df.string(from: prevDate).uppercased())"
            }
        case 1: 
            subtitle = currentWindow.isCurrentPeriod ? "FROM LAST WEEK" : "FROM PREV WEEK"
        default: 
            subtitle = currentWindow.isCurrentPeriod ? "FROM LAST MONTH" : "FROM PREV MONTH"
        }

        let iconName: String
        let iconTint: UIColor
        let value: String
        if previous.isEmpty || abs(delta) < 0.01 {
            iconName = "checkmark.circle.fill"
            iconTint = .systemGreen
            value = "Stable"
        } else if delta > 0 {
            iconName = "arrow.up.circle.fill"
            iconTint = .systemRed
            value = "Higher"
        } else {
            iconName = "arrow.down.circle.fill"
            iconTint = .systemBlue
            value = "Lower"
        }

        let icon = UIImage(systemName: iconName)?.withTintColor(iconTint, renderingMode: .alwaysOriginal)
        return MetricCardModel(title: title, value: value, unit: "", subtitle: subtitle, icon: icon, isTextValue: true)
    }

    private func spreadValue(for reading: VitalReading, points: [ChartDataPoint]) -> Double {
        if reading.title == "Blood Pressure" {
            let sys = points.compactMap(\.maxValue)
            let dia = points.compactMap(\.minValue)
            guard let sysMin = sys.min(), let sysMax = sys.max(), let diaMin = dia.min(), let diaMax = dia.max() else { return 0 }
            return (sysMax - sysMin) + (diaMax - diaMin)
        }

        let values = points.compactMap(\.value)
        guard let min = values.min(), let max = values.max() else { return 0 }
        return max - min
    }

    var currentFilterType: String = "Fasting"
    
    private func updateFilterTitle(_ title: String) {
        graphFilterButton?.setTitle(title, for: .normal)
        currentFilterType = title
        setupHeroSection()
        reloadChart()
        NotificationCenter.default.post(
            name: .glucoseFilterTypeDidChange,
            object: nil,
            userInfo: ["glucoseFilterType": title]
        )
    }

    private func chartPoints(for reading: VitalReading) -> [ChartDataPoint] {
        guard reading.title == "Blood Glucose" else {
            switch selectedPeriod {
            case 1:
                return buildDailyPoints(from: reading.hourlyChartData, reading: reading)
            case 2:
                return buildDailyPoints(from: reading.persistedHourlyChartData, reading: reading)
            default:
                return reading.hourlyChartData.isEmpty ? reading.chartData : reading.hourlyChartData
            }
        }

        let filteredHourly = reading.hourlyChartData.filter {
            ($0.glucoseType ?? BloodGlucoseType.fasting.rawValue) == currentFilterType
        }

        switch selectedPeriod {
        case 1:
            return buildDailyPoints(from: filteredHourly, reading: reading)
        case 2:
            let persistedFiltered = reading.persistedHourlyChartData.filter {
                ($0.glucoseType ?? BloodGlucoseType.fasting.rawValue) == currentFilterType
            }
            return buildDailyPoints(from: persistedFiltered, reading: reading)
        default:
            return filteredHourly
        }
    }

    private func glucoseTargetRange(for reading: VitalReading) -> (min: Double, max: Double)? {
        guard reading.title == "Blood Glucose" else { return nil }
        return BloodGlucoseType(rawValue: currentFilterType)?.targetRange ?? BloodGlucoseType.fasting.targetRange
    }

    private func currentBaseline(for reading: VitalReading, points: [ChartDataPoint]) -> Double {
        guard reading.title == "Body Weight" else { return reading.baselineValue ?? 0 }
        return points.last?.baselineValue ?? reading.baselineValue ?? 0
    }

    private func buildDailyPoints(from points: [ChartDataPoint], reading: VitalReading) -> [ChartDataPoint] {
        let df = DateFormatter()
        df.dateFormat = "dd-MM-yyyy"
        var groups: [String: [ChartDataPoint]] = [:]

        for point in points {
            guard let fullDate = point.fullDate else { continue }
            groups[fullDate, default: []].append(point)
        }

        return groups.compactMap { (fullDate, groupedPoints) in
            guard df.date(from: fullDate) != nil else { return nil }

            if let firstRangePoint = groupedPoints.first, firstRangePoint.minValue != nil || firstRangePoint.maxValue != nil {
                let minValues = groupedPoints.compactMap(\.minValue)
                let maxValues = groupedPoints.compactMap(\.maxValue)
                guard !minValues.isEmpty, !maxValues.isEmpty else { return nil }
                
                let rawMin = minValues.reduce(0, +) / Double(minValues.count)
                let rawMax = maxValues.reduce(0, +) / Double(maxValues.count)
                let avgMin = reading.title == "Body Weight" ? rawMin : floor(rawMin)
                let avgMax = reading.title == "Body Weight" ? rawMax : floor(rawMax)
                
                return ChartDataPoint(
                    day: fullDate,
                    min: avgMin,
                    max: avgMax,
                    fullDate: fullDate,
                    baselineValue: groupedPoints.compactMap(\.baselineValue).last
                )
            }

            let values = groupedPoints.compactMap(\.value)
            guard !values.isEmpty else { return nil }
            let rawAvg = values.reduce(0, +) / Double(values.count)
            let avg = reading.title == "Body Weight" ? rawAvg : floor(rawAvg)
            return ChartDataPoint(
                day: fullDate,
                value: avg,
                fullDate: fullDate,
                glucoseType: groupedPoints.last?.glucoseType,
                baselineValue: groupedPoints.compactMap(\.baselineValue).last
            )
        }
        .sorted {
            (df.date(from: $0.fullDate ?? "") ?? .distantPast) < (df.date(from: $1.fullDate ?? "") ?? .distantPast)
        }
    }

}

extension VitalDetailViewController: VitalChartScrollDelegate {
    func vitalChartDidScroll(visibleStartDate: Date?, visibleEndDate: Date?) {
        let points = currentChartPoints
        guard !points.isEmpty else { return }
        updateChartInfo(points: points, visibleStartDate: visibleStartDate, visibleEndDate: visibleEndDate)
    }

    func vitalChartDidHighlightPoint(_ point: ChartDataPoint?) {
        let isHighlighted = point != nil
        UIView.animate(withDuration: 0.2) {
            self.chartInfoView?.alpha = isHighlighted ? 0 : 1
        }
    }
}

extension VitalDetailViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return metricCards.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VitalMetricCollectionViewCell", for: indexPath) as? VitalMetricCollectionViewCell else {
            return UICollectionViewCell()
        }
        
        guard indexPath.item < metricCards.count else { return cell }
        let model = metricCards[indexPath.item]
        cell.configure(
            title: model.title,
            value: model.value,
            unit: model.unit,
            subtitle: model.subtitle,
            icon: model.icon,
            isTextValue: model.isTextValue
        )
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let totalSpacing: CGFloat = 42
        let width = floor((collectionView.bounds.width - totalSpacing) / 2)
        return CGSize(width: width, height: 100)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    }
}
