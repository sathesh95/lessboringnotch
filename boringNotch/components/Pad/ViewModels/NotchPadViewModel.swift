//
//  NotchPadViewModel.swift
//  boringNotch
//

import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class NotchPadViewModel: ObservableObject {
    static let shared = NotchPadViewModel()

    // Active View Mode (Freeform Notes is default)
    @Published var mode: NotchPadMode = .freeform {
        didSet {
            scheduleAutoSave()
        }
    }

    // Freeform Notes Text
    @Published var freeformText: String = "" {
        didSet {
            scheduleAutoSave()
        }
    }

    // Interactive Checklist Items
    @Published var checklistItems: [NotchPadBlock] = []
    @Published var focusedTodoID: UUID? = nil

    // Auto-save & Feedback Toast
    @Published var lastSavedText: String = "Saved"
    @Published var isCopiedToastVisible: Bool = false
    @Published var isFormatMenuVisible: Bool = false

    private var saveDebounceTask: Task<Void, Never>?
    private let persistence = NotchPadPersistenceService.shared

    init() {
        let data = persistence.load()
        self.mode = data.mode
        self.freeformText = data.freeformText
        self.checklistItems = data.checklistItems.isEmpty ? defaultTodos() : data.checklistItems
    }

    private func defaultTodos() -> [NotchPadBlock] {
        return [
            NotchPadBlock(type: .todo(isCompleted: false), content: "Welcome to Checklist!"),
            NotchPadBlock(type: .todo(isCompleted: false), content: "Tap checkbox to mark as completed"),
            NotchPadBlock(type: .todo(isCompleted: true), content: "Press Return to add a new task")
        ]
    }

    // MARK: - Auto-Save
    func scheduleAutoSave() {
        lastSavedText = "Saving..."
        saveDebounceTask?.cancel()
        saveDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            
            let data = NotchPadData(
                freeformText: self.freeformText,
                checklistItems: self.checklistItems,
                mode: self.mode
            )
            self.persistence.save(data)
            
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            self.lastSavedText = "Saved \(formatter.string(from: Date()))"
        }
    }

    // MARK: - Checklist Management
    func toggleTodo(id: UUID) {
        guard let index = checklistItems.firstIndex(where: { $0.id == id }) else { return }
        let currentCompleted = checklistItems[index].isCompleted
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            checklistItems[index].type = .todo(isCompleted: !currentCompleted)
        }
        scheduleAutoSave()
    }

    func updateTodoContent(id: UUID, newContent: String) {
        guard let index = checklistItems.firstIndex(where: { $0.id == id }) else { return }
        checklistItems[index].content = newContent
        scheduleAutoSave()
    }

    func insertTodoAfter(id: UUID? = nil) {
        let newBlock = NotchPadBlock(type: .todo(isCompleted: false), content: "")
        if let targetID = id, let index = checklistItems.firstIndex(where: { $0.id == targetID }) {
            checklistItems.insert(newBlock, at: index + 1)
        } else {
            checklistItems.append(newBlock)
        }
        focusedTodoID = newBlock.id
        scheduleAutoSave()
    }

    func deleteTodo(id: UUID) {
        guard let index = checklistItems.firstIndex(where: { $0.id == id }) else { return }
        if checklistItems.count > 1 {
            let prevIndex = max(0, index - 1)
            let prevID = checklistItems[prevIndex].id
            checklistItems.remove(at: index)
            focusedTodoID = prevID
        } else {
            checklistItems[0].content = ""
            checklistItems[0].type = .todo(isCompleted: false)
            focusedTodoID = checklistItems[0].id
        }
        scheduleAutoSave()
    }

    func clearCompletedTodos() {
        withAnimation(.smooth(duration: 0.25)) {
            checklistItems.removeAll { $0.isCompleted }
            if checklistItems.isEmpty {
                checklistItems = [NotchPadBlock(type: .todo(isCompleted: false), content: "")]
            }
        }
        scheduleAutoSave()
    }

    func clearAll() {
        withAnimation(.smooth(duration: 0.25)) {
            if mode == .freeform {
                freeformText = ""
            } else {
                checklistItems = [NotchPadBlock(type: .todo(isCompleted: false), content: "")]
                focusedTodoID = checklistItems.first?.id
            }
        }
        scheduleAutoSave()
    }

    // MARK: - Freeform Quick Helpers
    func insertMarkdownSnippet(_ snippet: String) {
        if freeformText.isEmpty {
            freeformText = snippet
        } else if freeformText.hasSuffix("\n") {
            freeformText += snippet
        } else {
            freeformText += "\n" + snippet
        }
        scheduleAutoSave()
    }

    // MARK: - Clipboard Export
    func copyToClipboard() {
        let exportText: String
        if mode == .freeform {
            exportText = freeformText
        } else {
            exportText = checklistItems.map { item in
                "- [\(item.isCompleted ? "x" : " ")] \(item.content)"
            }.joined(separator: "\n")
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(exportText, forType: .string)

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
