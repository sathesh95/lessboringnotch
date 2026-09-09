//
//  NotchPadView.swift
//  boringNotch
//

import SwiftUI

struct NotchPadView: View {
    @StateObject private var vm = NotchPadViewModel.shared
    @FocusState private var focusedID: UUID?

    var body: some View {
        VStack(spacing: 6) {
            // Header Toolbar
            headerToolbar

            // Main Editor Canvas
            ZStack(alignment: .topLeading) {
                editorScrollArea

                // Slash Command Menu Overlay
                if vm.isSlashMenuVisible {
                    NotchPadSlashMenu(vm: vm)
                        .padding(.top, 24)
                        .padding(.leading, 24)
                        .transition(.scale(scale: 0.95, anchor: .topLeading).combined(with: .opacity))
                        .zIndex(10)
                }

                // "Copied to clipboard" Toast
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
                            .fill(Color.black.opacity(0.85))
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(20)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if let firstID = vm.blocks.first?.id {
                focusedID = firstID
                vm.focusedBlockID = firstID
            }
        }
        .onChange(of: focusedID) { _, newID in
            vm.focusedBlockID = newID
        }
        .onChange(of: vm.focusedBlockID) { _, newID in
            if focusedID != newID {
                focusedID = newID
            }
        }
    }

    // MARK: - Header Toolbar
    private var headerToolbar: some View {
        HStack(spacing: 8) {
            // Title & Status
            HStack(spacing: 5) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))

                Text("Scratchpad")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))

                Text("•")
                    .foregroundStyle(.gray.opacity(0.5))

                Text(vm.lastSavedText)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.gray.opacity(0.8))
            }

            Spacer()

            // Quick Action Buttons
            HStack(spacing: 6) {
                // Add Block Button
                Button(action: {
                    if let lastID = vm.blocks.last?.id {
                        vm.insertBlockAfter(id: lastID, inheritType: false)
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                        Text("Add")
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
                    vm.clearCompleted()
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

                // Copy All
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
            }
            .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Editor Scroll Area
    private var editorScrollArea: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(vm.blocks) { block in
                        NotchPadBlockRow(
                            block: block,
                            vm: vm,
                            focusedID: $focusedID
                        )
                        .id(block.id)
                    }
                }
                .padding(.bottom, 20)
            }
            .onChange(of: vm.focusedBlockID) { _, newID in
                if let targetID = newID {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(targetID, anchor: .center)
                    }
                }
            }
        }
    }
}
