//
//  TrackerTasksViewModel.swift
//  boringNotch
//
//  Reads and edits the owner's open tasks from the Outsyd Task Tracker through the
//  local tracker bridge (tools/tracker-bridge/server.mjs) at http://127.0.0.1:51789.
//

import Combine
import Foundation
import SwiftUI

struct TrackerTask: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var board: String
    var status: String
    var priority: String
    var due: String
    var pending: Bool?
}

struct TrackerBoard: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let color: Int?
}

struct TrackerOption: Codable, Identifiable, Equatable {
    let key: String
    let label: String
    var id: String { key }
}

struct TrackerBridgeState: Codable {
    let connected: Bool
    let syncedAt: Double
    let me: String?
    let boards: [TrackerBoard]
    let statuses: [TrackerOption]
    let priorities: [TrackerOption]
    let tasks: [TrackerTask]
    let pendingChanges: Int
}

enum TrackerBridgeError: LocalizedError {
    case offline
    case server(String)

    var errorDescription: String? {
        switch self {
        case .offline: return "The tracker bridge isn't running."
        case .server(let message): return message
        }
    }
}

private struct BridgeFailure: Decodable { let error: String }

/// Thin client for the bridge's localhost API.
struct TrackerBridgeClient {
    static let port = 51789
    private let base = URL(string: "http://127.0.0.1:\(TrackerBridgeClient.port)/v1/")!

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    func fetchState() async throws -> TrackerBridgeState {
        try await send("GET", "tasks", body: nil)
    }

    func createTask(_ fields: [String: Any]) async throws {
        let _: TrackerTask = try await send("POST", "tasks", body: fields)
    }

    func updateTask(_ id: String, _ fields: [String: Any]) async throws {
        let _: TrackerTask = try await send("PATCH", "tasks/\(id)", body: fields)
    }

    func deleteTask(_ id: String) async throws {
        struct Ok: Decodable { let ok: Bool }
        let _: Ok = try await send("DELETE", "tasks/\(id)", body: nil)
    }

    private func send<T: Decodable>(_ method: String, _ path: String, body: [String: Any]?) async throws -> T {
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("1", forHTTPHeaderField: "x-tracker-bridge")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TrackerBridgeError.offline
        }
        guard let http = response as? HTTPURLResponse else { throw TrackerBridgeError.offline }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(BridgeFailure.self, from: data))?.error ?? "The bridge answered \(http.statusCode)."
            throw TrackerBridgeError.server(message)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

@MainActor
final class TrackerTasksViewModel: ObservableObject {
    static let shared = TrackerTasksViewModel()

    enum Link: Equatable {
        case unknown
        case offline        // bridge not running
        case waiting        // bridge running, tracker page hasn't synced recently
        case live
    }

    @Published private(set) var tasks: [TrackerTask] = []
    @Published private(set) var boards: [TrackerBoard] = []
    @Published private(set) var statuses: [TrackerOption] = []
    @Published private(set) var priorities: [TrackerOption] = []
    @Published private(set) var link: Link = .unknown
    @Published private(set) var syncedAt: Date?
    @Published var errorMessage: String?

    private let client = TrackerBridgeClient()
    private var pollTask: Task<Void, Never>?
    private var viewers = 0

    /// Open tasks, most urgent first: overdue and soonest due, then priority.
    var sortedTasks: [TrackerTask] {
        let rank = ["critical": 0, "high": 1, "medium": 2, "low": 3]
        return tasks.sorted { a, b in
            let da = a.due.isEmpty ? "9999-99-99" : a.due
            let db = b.due.isEmpty ? "9999-99-99" : b.due
            if da != db { return da < db }
            let pa = rank[a.priority] ?? 9, pb = rank[b.priority] ?? 9
            if pa != pb { return pa < pb }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
    }

    func boardName(_ id: String) -> String {
        boards.first { $0.id == id }?.name ?? ""
    }

    func statusLabel(_ key: String) -> String {
        statuses.first { $0.key == key }?.label ?? key
    }

    // MARK: Polling while the tab is on screen

    func startPolling() {
        viewers += 1
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    func stopPolling() {
        viewers = max(0, viewers - 1)
        guard viewers == 0 else { return }
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() async {
        do {
            let state = try await client.fetchState()
            tasks = state.tasks
            boards = state.boards
            statuses = state.statuses
            priorities = state.priorities
            syncedAt = state.syncedAt > 0 ? Date(timeIntervalSince1970: state.syncedAt / 1000) : nil
            link = state.connected ? .live : .waiting
        } catch {
            link = .offline
        }
    }

    // MARK: Edits (optimistic, then confirmed by the next refresh)

    func setStatus(_ task: TrackerTask, _ status: String) {
        mutate(task.id, ["status": status]) { $0.status = status }
    }

    func setPriority(_ task: TrackerTask, _ priority: String) {
        mutate(task.id, ["priority": priority]) { $0.priority = priority }
    }

    func setDue(_ task: TrackerTask, _ due: String) {
        mutate(task.id, ["due": due]) { $0.due = due }
    }

    func setBoard(_ task: TrackerTask, _ board: String) {
        mutate(task.id, ["board": board]) { $0.board = board }
    }

    func rename(_ task: TrackerTask, _ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != task.title else { return }
        mutate(task.id, ["title": trimmed]) { $0.title = trimmed }
    }

    func complete(_ task: TrackerTask) {
        setStatus(task, "complete")
    }

    func delete(_ task: TrackerTask) {
        tasks.removeAll { $0.id == task.id }
        run { try await self.client.deleteTask(task.id) }
    }

    func create(title: String, board: String?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var fields: [String: Any] = ["title": trimmed]
        if let board, !board.isEmpty { fields["board"] = board }
        run { try await self.client.createTask(fields) }
    }

    private func mutate(_ id: String, _ fields: [String: Any], local: (inout TrackerTask) -> Void) {
        if let i = tasks.firstIndex(where: { $0.id == id }) {
            local(&tasks[i])
            tasks[i].pending = true
        }
        run { try await self.client.updateTask(id, fields) }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        Task {
            do {
                try await work()
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            await refresh()
        }
    }
}
