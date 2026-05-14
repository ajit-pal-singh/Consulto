import Foundation

final class ConsultSessionStore {
    static let shared = ConsultSessionStore()

    private let fileManager = FileManager.default
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let legacySeedUserID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")

    private init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    // MARK: - Public API

    func loadSessions() -> [ConsultSession] {
        do {
            try ensureWritableStoreExists()
            let data = try Data(contentsOf: sessionsFileURL())
            let sessions = try decoder.decode([ConsultSession].self, from: data)
            let cleanedSessions = removeLegacySeedSessions(from: sessions)
            if cleanedSessions.count != sessions.count {
                saveSessions(cleanedSessions)
            }
            return cleanedSessions
        } catch {
            print("⚠️ Failed to load consult sessions: \(error)")
            let fileURL = sessionsFileURL()
            if fileManager.fileExists(atPath: fileURL.path) {
                try? fileManager.removeItem(at: fileURL)
            }
            saveSessions([])
            return []
        }
    }

    func saveSessions(_ sessions: [ConsultSession]) {
        do {
            try ensureDirectoryExists()
            let data = try encoder.encode(sessions)
            try data.write(to: sessionsFileURL(), options: .atomic)
        } catch {
            print("⚠️ Failed to save consult sessions: \(error)")
        }
    }

    func addSession(_ session: ConsultSession) {
        var sessions = loadSessions()
        sessions.insert(session, at: 0)
        saveSessions(sessions)
    }

    func updateSession(_ session: ConsultSession) {
        var sessions = loadSessions()
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            saveSessions(sessions)
        }
    }

    func deleteSession(id: UUID) {
        var sessions = loadSessions()
        sessions.removeAll { $0.id == id }
        saveSessions(sessions)
    }

    func nearestPendingSession(relativeTo now: Date = Date()) -> ConsultSession? {
        let sessions = loadSessions()
        let pendingSessions = sessions.filter { $0.status == .pending }

        let upcoming = pendingSessions
            .filter { $0.date >= now }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.date < rhs.date
            }

        if let nearestUpcoming = upcoming.first {
            return nearestUpcoming
        }

        return pendingSessions.sorted { lhs, rhs in
            let lhsDistance = abs(lhs.date.timeIntervalSince(now))
            let rhsDistance = abs(rhs.date.timeIntervalSince(now))
            if lhsDistance == rhsDistance {
                return lhs.createdAt > rhs.createdAt
            }
            return lhsDistance < rhsDistance
        }.first
    }

    func allPendingSessions(relativeTo now: Date = Date()) -> [ConsultSession] {
        let sessions = loadSessions()
        let pendingSessions = sessions.filter { $0.status == .pending }

        let upcoming = pendingSessions
            .filter { $0.date >= now }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.date < rhs.date
            }

        let past = pendingSessions
            .filter { $0.date < now }
            .sorted { lhs, rhs in
                let lhsDistance = abs(lhs.date.timeIntervalSince(now))
                let rhsDistance = abs(rhs.date.timeIntervalSince(now))
                if lhsDistance == rhsDistance {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhsDistance < rhsDistance
            }

        return upcoming + past
    }

    // MARK: - Private Helpers

    private func ensureWritableStoreExists() throws {
        try ensureDirectoryExists()
        let fileURL = sessionsFileURL()
        guard !fileManager.fileExists(atPath: fileURL.path) else { return }

        saveSessions([])
    }

    private func removeLegacySeedSessions(from sessions: [ConsultSession]) -> [ConsultSession] {
        guard let legacySeedUserID = legacySeedUserID else { return sessions }
        return sessions.filter { $0.userID != legacySeedUserID }
    }

    private func ensureDirectoryExists() throws {
        let dir = try applicationSupportDirectory()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
    }

    private func sessionsFileURL() -> URL {
        ((try? applicationSupportDirectory()) ?? fileManager.temporaryDirectory)
            .appendingPathComponent("consult_sessions.json")
    }

    private func applicationSupportDirectory() throws -> URL {
        try fileManager.url(for: .applicationSupportDirectory,
                            in: .userDomainMask,
                            appropriateFor: nil,
                            create: true)
    }
}
