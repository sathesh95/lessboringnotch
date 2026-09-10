//
//  NotchPadView.swift
//  boringNotch
//

import SwiftUI

struct NotchPadView: View {
    @StateObject private var vm = NotchPadViewModel.shared
    @FocusState private var isNotesFocused: Bool
    @FocusState private var focusedTodoID: UUID?

    var body: some View {
        VStack(spacing: 8) {
            // Header Toolbar
            headerToolbar

            // Main Editor Canvas
            ZStack(alignment: .bottomTrailing) {
                if vm.mode == .freeform {
                    freeformEditor
                } else {
                    checklistEditor
                }

                // Toast Notification for Copy
                if vm.isCopiedToastVisible {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Copied to clipboard")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.9))
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(20)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header Toolbar
    private var headerToolbar: some View {
        HStack(spacing: 8) {
            // Mode Switcher (Notes vs Checklist)
            HStack(spacing: 2) {
                ForEach(NotchPadMode.allCases, id: \.self) { mode in
                    Button(action: {
                        withAnimation(.smooth(duration: 0.2)) {
                            vm.mode = mode
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: mode == .freeform ? "note.text" : "checklist")
                                .font(.system(size: 10, weight: .medium))
                            Text(mode.rawValue)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundStyle(vm.mode == mode ? .white : .gray)
                        .background(
                            Capsule()
                                .fill(vm.mode == mode ? Color.white.opacity(0.12) : Color.clear)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(2)
            .background(Capsule().fill(Color.white.opacity(0.05)))

            // Auto-Save Status
            Text(vm.lastSavedText)
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(.gray.opacity(0.7))
                .padding(.leading, 4)

            Spacer()

            // Mode-specific Quick Actions
            HStack(spacing: 6) {
                if vm.mode == .freeform {
                    // Quick Markdown Buttons
                    Button(action: { vm.insertMarkdownSnippet("- [ ] ") }) {
                        HStack(spacing: 2) {
                            Image(systemName: "checklist")
                            Text("Todo")
                        }
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { vm.insertMarkdownSnippet("- ") }) {
                        HStack(spacing: 2) {
                            Image(systemName: "list.bullet")
                            Text("Bullet")
                        }
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { vm.insertMarkdownSnippet("# ") }) {
                        Text("H1")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // Add Checklist Item
                    Button(action: {
                        vm.insertTodoAfter()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                            Text("Add Task")
                        }
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Clear Completed
                    Button(action: {
                        vm.clearCompletedTodos()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle")
                            Text("Clear Done")
                        }
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Copy
                Button(action: {
                    vm.copyToClipboard()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())

                // Clear All
                Button(action: {
                    vm.clearAll()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Freeform Editor
    private var freeformEditor: some View {
        ZStack(alignment: .topLeading) {
            if vm.freeformText.isEmpty {
                Text("Type thoughts, notes, brainstorms, or paste anything here...")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.gray.opacity(0.6))
                    .padding(.top, 4)
                    .padding(.leading, 4)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $vm.freeformText)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .foregroundStyle(.white.opacity(0.92))
                .focused($isNotesFocused)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(4)
    }

    // MARK: - Checklist Editor
    private var checklistEditor: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(vm.checklistItems) { item in
                        NotchPadBlockRow(
                            block: item,
                            vm: vm,
                            focusedID: $focusedTodoID
                        )
                        .id(item.id)
                    }
                }
                .padding(.bottom, 16)
            }
            .onChange(of: vm.focusedTodoID) { _, newID in
                if let targetID = newID {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(targetID, anchor: .center)
                    }
                }
            }
        }
    }
}
