//
//  NotchPadSlashMenu.swift
//  boringNotch
//

import SwiftUI

struct NotchPadSlashMenu: View {
    @ObservedObject var vm: NotchPadViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("BASIC BLOCKS")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.gray.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 2)

            ForEach(Array(vm.filteredSlashCommands.enumerated()), id: \.element.id) { index, item in
                Button(action: {
                    vm.applySlashCommand(item)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: item.icon)
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 16, height: 16)
                            .foregroundStyle(.white)

                        Text(item.rawValue)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)

                        Spacer()

                        Text(item.shortcutHint)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SlashMenuButtonStyle(isSelected: vm.slashMenuSelectedIndex == index))
            }
        }
        .frame(width: 210)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 4)
        )
    }
}

struct SlashMenuButtonStyle: ButtonStyle {
    var isSelected: Bool
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovering || isSelected ? Color.white.opacity(0.12) : Color.clear)
            )
            .onHover { hovering in
                isHovering = hovering
            }
    }
}
