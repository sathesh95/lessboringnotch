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
        HStack(alignment: .center, spacing: 10) {
            // Interactive Checkbox Button
            Button(action: {
                vm.toggleTodo(id: block.id)
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(block.isCompleted ? Color.accentColor : Color.white.opacity(0.35), lineWidth: 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(block.isCompleted ? Color.accentColor : Color.white.opacity(0.06))
                        )
                        .frame(width: 17, height: 17)

                    if block.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Task Content TextField
            let binding = Binding<String>(
                get: { block.content },
                set: { vm.updateTodoContent(id: block.id, newContent: $0) }
            )

            TextField("New task...", text: binding)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(block.isCompleted ? Color.gray.opacity(0.65) : Color.white.opacity(0.92))
                .strikethrough(block.isCompleted, color: Color.gray.opacity(0.7))
                .focused($focusedID, equals: block.id)
                .onSubmit {
                    vm.insertTodoAfter(id: block.id)
                }
                .onKeyPress(.delete) {
                    if block.content.isEmpty {
                        vm.deleteTodo(id: block.id)
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.escape) {
                    NotificationCenter.default.post(name: .escapeKeyPressedInNotch, object: nil)
                    return .handled
                }

            Spacer(minLength: 4)

            // Hover Delete Button
            if isHovering {
                Button(action: {
                    vm.deleteTodo(id: block.id)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.gray.opacity(0.8))
                        .frame(width: 18, height: 18)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.opacity)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.white.opacity(0.03) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}
