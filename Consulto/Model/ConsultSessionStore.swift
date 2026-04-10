import Foundation

final class ConsultSessionStore {
    static let shared = ConsultSessionStore()

    private let fileManager = FileManager.default
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

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
            // If the file exists but decoded to empty, it might be stale from a
            // previous crash.  Re-seed when the bundle still has data.
            if sessions.isEmpty, let seedURL = Bundle.main.url(forResource: "seed_consult_sessions", withExtension: "json") {
                let seedData = try Data(contentsOf: seedURL)
                let seedSessions = try decoder.decode([ConsultSession].self, from: seedData)
                if !seedSessions.isEmpty {
                    try seedData.write(to: sessionsFileURL(), options: .atomic)
                    return seedSessions
                }
            }
            return sessions
        } catch {
            print("⚠️ Failed to load consult sessions: \(error)")
            // Attempt recovery: remove the corrupt writable file so the next
            // call re-copies from the seed bundle.
            let fileURL = sessionsFileURL()
            if fileManager.fileExists(atPath: fileURL.path) {
                try? fileManager.removeItem(at: fileURL)
            }
            // Retry once after removing the bad file
            do {
                try ensureWritableStoreExists()
                let data = try Data(contentsOf: sessionsFileURL())
                return try decoder.decode([ConsultSession].self, from: data)
            } catch {
                print("⚠️ Recovery also failed: \(error)")
                return []
            }
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

    // MARK: - Private Helpers

    private func ensureWritableStoreExists() throws {
        try ensureDirectoryExists()
        let fileURL = sessionsFileURL()
        guard !fileManager.fileExists(atPath: fileURL.path) else { return }

        // First launch — copy seed JSON from bundle into writable location
        guard let seedURL = Bundle.main.url(forResource: "seed_consult_sessions", withExtension: "json") else {
            throw NSError(domain: "ConsultSessionStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Missing seed_consult_sessions.json"])
        }
        try fileManager.copyItem(at: seedURL, to: fileURL)
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
