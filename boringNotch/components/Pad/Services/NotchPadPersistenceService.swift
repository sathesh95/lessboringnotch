//
//  NotchPadPersistenceService.swift
//  boringNotch
//

import Foundation

final class NotchPadPersistenceService {
    static let shared = NotchPadPersistenceService()

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let fm = FileManager.default
        let support = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = (support ?? fm.temporaryDirectory)
            .appendingPathComponent("boringNotch", isDirectory: true)
            .appendingPathComponent("Pad", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("scratchpad.json")
        encoder.outputFormatting = [.prettyPrinted]
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    func load() -> NotchPadData {
        guard let data = try? Data(contentsOf: fileURL) else {
            return defaultInitialData()
        }

        // Try decoding modern NotchPadData structure
        if let padData = try? decoder.decode(NotchPadData.self, from: data) {
            return padData
        }

        // Fallback: try legacy [NotchPadBlock]
        if let blocks = try? decoder.decode([NotchPadBlock].self, from: data) {
            let legacyText = blocks.map { $0.content }.joined(separator: "\n")
            let todos = blocks.filter { $0.isTodo }
            return NotchPadData(freeformText: legacyText, checklistItems: todos.isEmpty ? defaultTodos() : todos, mode: .freeform)
        }

        return defaultInitialData()
    }

    func save(_ data: NotchPadData) {
        do {
            let encoded = try encoder.encode(data)
            try encoded.write(to: fileURL, options: .atomic)
        } catch {
            print("❌ Failed to save NotchPad data: \(error.localizedDescription)")
        }
    }

    private func defaultInitialData() -> NotchPadData {
        return NotchPadData(
            freeformText: "",
            checklistItems: defaultTodos(),
            mode: .freeform
        )
    }

    private func defaultTodos() -> [NotchPadBlock] {
        return [
            NotchPadBlock(type: .todo(isCompleted: false), content: "Welcome to Scratchpad!"),
            NotchPadBlock(type: .todo(isCompleted: false), content: "Click the checkbox to complete a task"),
            NotchPadBlock(type: .todo(isCompleted: true), content: "Press Return to add the next item")
        ]
    }
}
