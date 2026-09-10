//
//  NotchPadBlockRow.swift
//  boringNotch
//

import SwiftUI

struct NotchPadBlockRow: View {
    let block: NotchPadBlock
    @ObservedObject var vm: NotchPadViewModel
    @FocusState.Binding var focusedID: UUID?
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Block Type Icon / Checkbox / Bullet
            leadingIndicator

            // Text Input Field
            contentField

            // Trailing Delete Button (on hover)
            if isHovering {
                Button(action: {
                    vm.deleteBlock(id: block.id)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.gray.opacity(0.7))
                        .frame(width: 16, height: 16)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.opacity)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    @ViewBuilder
    private var leadingIndicator: some View {
        switch block.type {
        case .todo(let isCompleted):
            Button(action: {
                vm.toggleTodo(id: block.id)
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isCompleted ? Color.accentColor : Color.white.opacity(0.4), lineWidth: 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isCompleted ? Color.accentColor : Color.clear)
                        )
                        .frame(width: 15, height: 15)

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

        case .bullet:
            Circle()
                .fill(Color.gray.opacity(0.8))
                .frame(width: 5, height: 5)
                .frame(width: 15, height: 15)

        case .heading1:
            Text("H1")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.gray)
                .frame(width: 15, height: 15)

        case .heading2:
            Text("H2")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.gray)
                .frame(width: 15, height: 15)

        case .code:
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.gray)
                .frame(width: 15, height: 15)

        case .text:
            Menu {
                Button("Convert to To-do") { vm.setBlockType(id: block.id, type: .todo(isCompleted: false)) }
                Button("Convert to Bullet") { vm.setBlockType(id: block.id, type: .bullet) }
                Button("Convert to Heading 1") { vm.setBlockType(id: block.id, type: .heading1) }
                Button("Convert to Heading 2") { vm.setBlockType(id: block.id, type: .heading2) }
                Button("Convert to Code") { vm.setBlockType(id: block.id, type: .code) }
            } label: {
                Image(systemName: "circle.fill")
                    .font(.system(size: 4))
                    .foregroundStyle(isHovering ? Color.gray.opacity(0.6) : Color.clear)
                    .frame(width: 15, height: 15)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    @ViewBuilder
    private var contentField: some View {
        let binding = Binding<String>(
            get: { block.content },
            set: { vm.updateBlockContent(id: block.id, newContent: $0) }
        )

        TextField(placeholderText, text: binding)
            .textFieldStyle(PlainTextFieldStyle())
            .font(fontForBlock(block.type))
            .foregroundStyle(colorForBlock(block.type))
            .strikethrough(block.isCompleted, color: .gray)
            .focused($focusedID, equals: block.id)
            .onSubmit {
                if vm.isSlashMenuVisible {
                    vm.confirmSlashMenuSelection()
                } else {
                    vm.insertBlockAfter(id: block.id)
                }
            }
            .onKeyPress(.delete) {
                if block.content.isEmpty {
                    vm.handleBackspaceOnEmptyBlock(id: block.id)
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.upArrow) {
                if vm.isSlashMenuVisible {
                    vm.moveSlashMenuSelectionUp()
                    return .handled
                }
                vm.focusPreviousBlock(from: block.id)
                return .handled
            }
            .onKeyPress(.downArrow) {
                if vm.isSlashMenuVisible {
                    vm.moveSlashMenuSelectionDown()
                    return .handled
                }
                vm.focusNextBlock(from: block.id)
                return .handled
            }
            .onKeyPress(.escape) {
                if vm.isSlashMenuVisible {
                    vm.isSlashMenuVisible = false
                    return .handled
                }
                NotificationCenter.default.post(name: .escapeKeyPressedInNotch, object: nil)
                return .handled
            }
    }

    private var placeholderText: String {
        switch block.type {
        case .todo: return "To-do item (press Return to add next)..."
        case .bullet: return "List item..."
        case .heading1: return "Heading 1..."
        case .heading2: return "Heading 2..."
        case .code: return "Code snippet..."
        case .text: return "Type / for Notion menu or brainstorm..."
        }
    }

    private func fontForBlock(_ type: BlockType) -> Font {
        switch type {
        case .heading1:
            return .system(size: 15, weight: .bold, design: .rounded)
        case .heading2:
            return .system(size: 14, weight: .semibold, design: .rounded)
        case .code:
            return .system(size: 12, weight: .regular, design: .monospaced)
        case .todo, .bullet, .text:
            return .system(size: 13, weight: .regular, design: .rounded)
        }
    }

    private func colorForBlock(_ type: BlockType) -> Color {
        if block.isCompleted {
            return .gray.opacity(0.7)
        }
        switch type {
        case .heading1, .heading2:
            return .white
        case .code:
            return .green.opacity(0.9)
        case .todo, .bullet, .text:
            return .white.opacity(0.92)
        }
    }
}
