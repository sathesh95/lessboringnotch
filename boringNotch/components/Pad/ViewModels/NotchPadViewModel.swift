//
//  NotchPadViewModel.swift
//  boringNotch
//

import AppKit
import Combine
import Foundation
import SwiftUI

public enum SlashCommandItem: String, CaseIterable, Identifiable {
    case todo = "To-do List"
    case bullet = "Bullet List"
    case heading1 = "Heading 1"
    case heading2 = "Heading 2"
    case text = "Normal Text"
    case code = "Code Snippet"
    case clearCompleted = "Clear Completed Items"
    case clearAll = "Clear All Notes"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .todo: return "checklist"
        case .bullet: return "list.bullet"
        case .heading1: return "textformat.size.larger"
        case .heading2: return "textformat.size"
        case .text: return "paragraphsign"
        case .code: return "curlybraces"
        case .clearCompleted: return "checkmark.circle.badge.xmark"
        case .clearAll: return "trash"
        }
    }

    public var shortcutHint: String {
        switch self {
        case .todo: return "[]"
        case .bullet: return "-"
        case .heading1: return "#"
        case .heading2: return "##"
        case .text: return "p"
        case .code: return "```"
        case .clearCompleted: return "clean"
        case .clearAll: return "reset"
        }
    }
}

@MainActor
final class NotchPadViewModel: ObservableObject {
    static let shared = NotchPadViewModel()

    @Published var blocks: [NotchPadBlock] = []
    @Published var focusedBlockID: UUID? = nil
    @Published var isSlashMenuVisible: Bool = false
    @Published var slashMenuBlockID: UUID? = nil
    @Published var slashMenuQuery: String = ""
    @Published var slashMenuSelectedIndex: Int = 0

    @Published var lastSavedText: String = "Saved"
    @Published var isCopiedToastVisible: Bool = false

    private var saveDebounceTask: Task<Void, Never>?
    private let persistence = NotchPadPersistenceService.shared

    init() {
        self.blocks = persistence.load()
        if blocks.isEmpty {
            self.blocks = [NotchPadBlock(type: .text, content: "")]
        }
    }

    // MARK: - Auto-Save
    func scheduleAutoSave() {
        lastSavedText = "Saving..."
        saveDebounceTask?.cancel()
        saveDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            persistence.save(blocks)
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            lastSavedText = "Auto-saved \(formatter.string(from: Date()))"
        }
    }

    // MARK: - Content Modifications
    func updateBlockContent(id: UUID, newContent: String) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }

        // Check for markdown shortcuts at start of line
        var text = newContent
        var changedType: BlockType? = nil

        if text.hasPrefix("[] ") || text.hasPrefix("[ ] ") || text.hasPrefix("- [ ] ") {
            text = text.replacingOccurrences(of: "^(\\[\\]|\\[ \\]|- \\[ \\])\\s*", with: "", options: .regularExpression)
            changedType = .todo(isCompleted: false)
        } else if text.hasPrefix("[x] ") || text.hasPrefix("[X] ") || text.hasPrefix("- [x] ") {
            text = text.replacingOccurrences(of: "^(\\[x\\]|\\[X\\]|- \\[x\\])\\s*", with: "", options: .regularExpression)
            changedType = .todo(isCompleted: true)
        } else if text.hasPrefix("- ") || text.hasPrefix("* ") {
            text = text.replacingOccurrences(of: "^(-|\\*)\\s+", with: "", options: .regularExpression)
            changedType = .bullet
        } else if text.hasPrefix("## ") {
            text = text.replacingOccurrences(of: "^##\\s+", with: "", options: .regularExpression)
            changedType = .heading2
        } else if text.hasPrefix("# ") {
            text = text.replacingOccurrences(of: "^#\\s+", with: "", options: .regularExpression)
            changedType = .heading1
        } else if text.hasPrefix("```") {
            text = text.replacingOccurrences(of: "^```\\s*", with: "", options: .regularExpression)
            changedType = .code
        }

        // Check for slash menu trigger
        if text.hasPrefix("/") {
            let query = String(text.dropFirst()).lowercased()
            isSlashMenuVisible = true
            slashMenuBlockID = id
            slashMenuQuery = query
            slashMenuSelectedIndex = 0
        } else if isSlashMenuVisible && slashMenuBlockID == id {
            isSlashMenuVisible = false
            slashMenuBlockID = nil
        }

        blocks[index].content = text
        if let newType = changedType {
            blocks[index].type = newType
        }

        scheduleAutoSave()
    }

    func toggleTodo(id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        if case .todo(let isCompleted) = blocks[index].type {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                blocks[index].type = .todo(isCompleted: !isCompleted)
            }
            scheduleAutoSave()
        }
    }

    func setBlockType(id: UUID, type: BlockType) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.smooth(duration: 0.2)) {
            blocks[index].type = type
        }
        scheduleAutoSave()
    }

    func insertBlockAfter(id: UUID, inheritType: Bool = true) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        let currentBlock = blocks[index]

        var newType: BlockType = .text
        if inheritType {
            switch currentBlock.type {
            case .todo:
                newType = .todo(isCompleted: false)
            case .bullet:
                newType = .bullet
            default:
                newType = .text
            }
        }

        let newBlock = NotchPadBlock(type: newType, content: "")
        blocks.insert(newBlock, at: index + 1)
        focusedBlockID = newBlock.id
        scheduleAutoSave()
    }

    func deleteBlock(id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        
        if blocks.count > 1 {
            let prevIndex = max(0, index - 1)
            let prevID = blocks[prevIndex].id
            blocks.remove(at: index)
            focusedBlockID = prevID
        } else {
            blocks[0].type = .text
            blocks[0].content = ""
            focusedBlockID = blocks[0].id
        }
        scheduleAutoSave()
    }

    func handleBackspaceOnEmptyBlock(id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        let block = blocks[index]

        if block.type != .text {
            // Convert to normal text instead of deleting
            setBlockType(id: id, type: .text)
        } else if blocks.count > 1 {
            deleteBlock(id: id)
        }
    }

    // MARK: - Slash Commands
    var filteredSlashCommands: [SlashCommandItem] {
        if slashMenuQuery.isEmpty {
            return SlashCommandItem.allCases
        }
        return SlashCommandItem.allCases.filter {
            $0.rawValue.lowercased().contains(slashMenuQuery) ||
            $0.shortcutHint.lowercased().contains(slashMenuQuery)
        }
    }

    func applySlashCommand(_ item: SlashCommandItem) {
        guard let targetID = slashMenuBlockID ?? focusedBlockID,
              let index = blocks.firstIndex(where: { $0.id == targetID }) else {
            isSlashMenuVisible = false
            return
        }

        switch item {
        case .todo:
            blocks[index].type = .todo(isCompleted: false)
            blocks[index].content = ""
        case .bullet:
            blocks[index].type = .bullet
            blocks[index].content = ""
        case .heading1:
            blocks[index].type = .heading1
            blocks[index].content = ""
        case .heading2:
            blocks[index].type = .heading2
            blocks[index].content = ""
        case .text:
            blocks[index].type = .text
            blocks[index].content = ""
        case .code:
            blocks[index].type = .code
            blocks[index].content = ""
        case .clearCompleted:
            clearCompleted()
            return
        case .clearAll:
            clearAll()
            return
        }

        isSlashMenuVisible = false
        slashMenuBlockID = nil
        focusedBlockID = targetID
        scheduleAutoSave()
    }

    func moveSlashMenuSelectionUp() {
        let count = filteredSlashCommands.count
        guard count > 0 else { return }
        slashMenuSelectedIndex = (slashMenuSelectedIndex - 1 + count) % count
    }

    func moveSlashMenuSelectionDown() {
        let count = filteredSlashCommands.count
        guard count > 0 else { return }
        slashMenuSelectedIndex = (slashMenuSelectedIndex + 1) % count
    }

    func confirmSlashMenuSelection() {
        let commands = filteredSlashCommands
        guard slashMenuSelectedIndex >= 0, slashMenuSelectedIndex < commands.count else { return }
        applySlashCommand(commands[slashMenuSelectedIndex])
    }

    func focusPreviousBlock(from currentID: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == currentID }), index > 0 else { return }
        focusedBlockID = blocks[index - 1].id
    }

    func focusNextBlock(from currentID: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == currentID }), index < blocks.count - 1 else { return }
        focusedBlockID = blocks[index + 1].id
    }

    // MARK: - Actions
    func clearCompleted() {
        withAnimation(.smooth(duration: 0.25)) {
            blocks.removeAll { block in
                if case .todo(let completed) = block.type {
                    return completed
                }
                return false
            }
            if blocks.isEmpty {
                blocks = [NotchPadBlock(type: .text, content: "")]
            }
        }
        isSlashMenuVisible = false
        scheduleAutoSave()
    }

    func clearAll() {
        withAnimation(.smooth(duration: 0.25)) {
            blocks = [NotchPadBlock(type: .text, content: "")]
            focusedBlockID = blocks.first?.id
        }
        isSlashMenuVisible = false
        scheduleAutoSave()
    }

    func copyToClipboard() {
        let markdown = blocks.map { block in
            switch block.type {
            case .text:
                return block.content
            case .todo(let isCompleted):
                return "- [\(isCompleted ? "x" : " ")] \(block.content)"
            case .bullet:
                return "- \(block.content)"
            case .heading1:
                return "# \(block.content)"
            case .heading2:
                return "## \(block.content)"
            case .code:
                return "```\n\(block.content)\n```"
            }
        }.joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isCopiedToastVisible = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            withAnimation(.smooth(duration: 0.3)) {
                self?.isCopiedToastVisible = false
            }
        }
    }
}
