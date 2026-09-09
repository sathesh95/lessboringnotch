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

    func load() -> [NotchPadBlock] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return defaultInitialBlocks()
        }

        do {
            let blocks = try decoder.decode([NotchPadBlock].self, from: data)
            return blocks.isEmpty ? defaultInitialBlocks() : blocks
        } catch {
            print("⚠️ Failed to decode NotchPad blocks: \(error.localizedDescription)")
            return defaultInitialBlocks()
        }
    }

    func save(_ blocks: [NotchPadBlock]) {
        do {
            let data = try encoder.encode(blocks)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("❌ Failed to save NotchPad blocks: \(error.localizedDescription)")
        }
    }

    private func defaultInitialBlocks() -> [NotchPadBlock] {
        return [
            NotchPadBlock(type: .heading2, content: "Quick Scratchpad & Checklist"),
            NotchPadBlock(type: .todo(isCompleted: false), content: "Type / to open Notion menu or [] for todo"),
            NotchPadBlock(type: .text, content: "Brainstorm thoughts, notes, and tasks here...")
        ]
    }
}
