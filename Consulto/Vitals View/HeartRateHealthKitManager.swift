import Foundation
import HealthKit

class HeartRateHealthKitManager {

    static let shared = HeartRateHealthKitManager()
    private let store = HKHealthStore()
    private init() {}

    // MARK: — Types

    private var heartRateType: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .heartRate)!
    }
    private var restingHRType: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
    }

    // MARK: — Availability

    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: — Authorization

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard isHealthKitAvailable else {
            completion(false, nil); return
        }
        let readTypes: Set<HKObjectType> = [heartRateType, restingHRType]
        store.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            DispatchQueue.main.async { completion(success, error) }
        }
    }

    func fetchHeartRateSamples(
        forLastDays days: Int = 90,
        completion: @escaping ([(bpm: Double, date: Date)]) -> Void
    ) {
        guard isHealthKitAvailable else { completion([]); return }

        let startDate = Calendar.current.date(
            byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: Date())
        )!
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate, end: Date(), options: .strictStartDate
        )
        let unit = HKUnit(from: "count/min")

        let interval = DateComponents(hour: 1)
        var anchorComponents = Calendar.current.dateComponents([.day, .month, .year], from: Date())
        anchorComponents.hour = 0
        let anchorDate = Calendar.current.date(from: anchorComponents)!

        let query = HKStatisticsCollectionQuery(
            quantityType: heartRateType,
            quantitySamplePredicate: predicate,
            options: [.discreteMin, .discreteMax],
            anchorDate: anchorDate,
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { _, results, error in
            guard let statsCollection = results, error == nil else {
                DispatchQueue.main.async { completion([]) }; return
            }
            
            var result: [(bpm: Double, date: Date)] = []
            statsCollection.enumerateStatistics(from: startDate, to: Date()) { stats, _ in
                let date = stats.startDate
                if let minQty = stats.minimumQuantity() {
                    result.append((bpm: minQty.doubleValue(for: unit), date: date))
                }
                if let maxQty = stats.maximumQuantity() {
                    let maxDate = date.addingTimeInterval(60) // slight offset for sorting/distinct visual points
                    result.append((bpm: maxQty.doubleValue(for: unit), date: maxDate))
                }
            }
            DispatchQueue.main.async { completion(result) }
        }
        store.execute(query)
    }

    // MARK: — Fetch Resting Heart Rate Samples (last N days)

    func fetchRestingHeartRateSamples(
        forLastDays days: Int = 90,
        completion: @escaping ([(bpm: Double, date: Date)]) -> Void
    ) {
        guard isHealthKitAvailable else { completion([]); return }

        let startDate = Calendar.current.date(
            byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: Date())
        )!
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate, end: Date(), options: .strictStartDate
        )
        let unit = HKUnit(from: "count/min")

        let interval = DateComponents(day: 1)
        var anchorComponents = Calendar.current.dateComponents([.day, .month, .year], from: Date())
        anchorComponents.hour = 0
        let anchorDate = Calendar.current.date(from: anchorComponents)!

        let query = HKStatisticsCollectionQuery(
            quantityType: restingHRType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage,
            anchorDate: anchorDate,
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { _, results, error in
            guard let statsCollection = results, error == nil else {
                DispatchQueue.main.async { completion([]) }; return
            }
            
            var result: [(bpm: Double, date: Date)] = []
            statsCollection.enumerateStatistics(from: startDate, to: Date()) { stats, _ in
                if let avgQty = stats.averageQuantity() {
                    result.append((bpm: avgQty.doubleValue(for: unit), date: stats.startDate))
                }
            }
            DispatchQueue.main.async { completion(result) }
        }
        store.execute(query)
    }

    // MARK: — Fetch Latest Single Reading

    func fetchLatestHeartRate(completion: @escaping (Double?) -> Void) {
        guard isHealthKitAvailable else { completion(nil); return }

        let startDate = Date().addingTimeInterval(-86400)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date())
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let unit = HKUnit(from: "count/min")

        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in
            let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
            DispatchQueue.main.async { completion(value) }
        }
        store.execute(query)
    }
}
