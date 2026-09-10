//
//  NotchPadSlashMenu.swift
//  boringNotch
//

import SwiftUI

struct NotchPadSlashMenu: View {
    @ObservedObject var vm: NotchPadViewModel

    var body: some View {
        HStack(spacing: 6) {
            formatButton(icon: "checklist", label: "To-do", snippet: "- [ ] ")
            formatButton(icon: "list.bullet", label: "Bullet", snippet: "- ")
            formatButton(icon: "textformat.size.larger", label: "H1", snippet: "# ")
            formatButton(icon: "textformat.size", label: "H2", snippet: "## ")
            formatButton(icon: "curlybraces", label: "Code", snippet: "```\n\n```")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
                .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
        )
    }

    private func formatButton(icon: String, label: String, snippet: String) -> some View {
        Button(action: {
            vm.insertMarkdownSnippet(snippet)
        }) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
