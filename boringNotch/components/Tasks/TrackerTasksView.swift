//
//  TrackerTasksView.swift
//  boringNotch
//
//  The Tasks tab: your open tasks from the Outsyd Task Tracker on the left, and an
//  inline editor (or the new-task form) on the right. Everything is inline pills
//  rather than pop-up menus so the notch never loses hover while editing.
//

import SwiftUI

struct TrackerTasksView: View {
    @ObservedObject private var vm = TrackerTasksViewModel.shared
    @EnvironmentObject private var boringVM: BoringViewModel

    @State private var selectedID: String?
    @State private var draftTitle = ""
    @State private var newTitle = ""
    @State private var newBoard: String?
    @FocusState private var focus: Field?

    private enum Field: Hashable { case newTask, rename }

    private var selected: TrackerTask? {
        guard let selectedID else { return nil }
        return vm.tasks.first { $0.id == selectedID }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                header
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().overlay(Color.white.opacity(0.08))

            Group {
                if let task = selected {
                    editor(task)
                } else {
                    newTaskForm
                }
            }
            .frame(width: 260, alignment: .topLeading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.07), lineWidth: 1))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            vm.startPolling()
            boringVM.claimKeyFocus()
        }
        .onDisappear { vm.stopPolling() }
        .onTapGesture { boringVM.claimKeyFocus() }
        .onChange(of: selectedID) { _, _ in
            draftTitle = selected?.title ?? ""
        }
        .onChange(of: focus) { old, _ in
            // Save a rename when the field loses focus without Return.
            if old == .rename, let task = selected { vm.rename(task, draftTitle) }
        }
    }

    // MARK: - Left column

    private var header: some View {
        HStack(spacing: 8) {
            Text("My tasks")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            if !vm.tasks.isEmpty {
                Text("\(vm.tasks.filter { $0.status != "complete" }.count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer()
            linkBadge
            Button {
                selectedID = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focus = .newTask }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.1)))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .help("New task")
            .disabled(vm.link == .offline || vm.boards.isEmpty)
        }
    }

    private var linkBadge: some View {
        let (color, text): (Color, String) = {
            switch vm.link {
            case .live: return (.green, "Synced")
            case .waiting: return (.orange, "Open the tracker in Claude to sync")
            case .offline: return (.red, "Bridge offline")
            case .unknown: return (.gray, "Connecting…")
            }
        }()
        return HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.link == .offline && vm.tasks.isEmpty {
            message(
                icon: "bolt.horizontal.circle",
                title: "Tracker bridge isn't running",
                detail: "Open the Claude app. It starts the bridge, then open your Task Tracker once to sync."
            )
        } else if vm.link == .unknown {
            message(icon: "arrow.triangle.2.circlepath", title: "Loading tasks…", detail: nil)
        } else if vm.tasks.isEmpty {
            message(
                icon: "checkmark.seal",
                title: vm.syncedAt == nil ? "Nothing synced yet" : "No open tasks",
                detail: vm.syncedAt == nil ? "Open the Task Tracker in the Claude app to send your tasks here." : "Everything assigned to you is complete."
            )
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 2) {
                    ForEach(vm.sortedTasks) { task in
                        row(task)
                    }
                }
            }
        }
    }

    private func row(_ task: TrackerTask) -> some View {
        let done = task.status == "complete"
        let isSelected = task.id == selectedID
        return HStack(spacing: 8) {
            Button {
                withAnimation(.smooth(duration: 0.2)) {
                    vm.setStatus(task, done ? "working" : "complete")
                }
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(done ? Color.green : Color.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help(done ? "Reopen" : "Mark complete")

            Circle()
                .fill(priorityColor(task.priority))
                .frame(width: 5, height: 5)
                .opacity(task.priority.isEmpty ? 0 : 1)

            Text(task.title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(done ? Color.secondary : Color.white)
                .strikethrough(done, color: .secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            if let due = dueLabel(task) {
                Text(due.text)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(due.overdue && !done ? Color.red : Color.secondary)
            }

            Text(vm.statusLabel(task.status))
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(statusColor(task.status).opacity(0.85)))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
        )
        .opacity(task.pending == true ? 0.75 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            boringVM.claimKeyFocus()
            selectedID = isSelected ? nil : task.id
        }
    }

    private func message(icon: String, title: String, detail: String?) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            if let detail {
                Text(detail)
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Right column: editor

    private func editor(_ task: TrackerTask) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    TextField("Task name", text: $draftTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .focused($focus, equals: .rename)
                        .onSubmit { vm.rename(task, draftTitle) }
                        .onKeyPress(.escape) {
                            draftTitle = task.title
                            focus = nil
                            return .handled
                        }
                    Button {
                        selectedID = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Close")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.07)))

                pillRow("Status") {
                    ForEach(vm.statuses) { s in
                        Pill(text: s.label, color: statusColor(s.key), selected: task.status == s.key) {
                            vm.setStatus(task, s.key)
                        }
                    }
                }

                pillRow("Priority") {
                    Pill(text: "None", color: .gray, selected: task.priority.isEmpty) { vm.setPriority(task, "") }
                    ForEach(vm.priorities) { p in
                        Pill(text: p.label, color: priorityColor(p.key), selected: task.priority == p.key) {
                            vm.setPriority(task, p.key)
                        }
                    }
                }

                pillRow("Due") {
                    ForEach(dueChoices, id: \.label) { choice in
                        Pill(text: choice.label, color: .blue, selected: task.due == choice.value) {
                            vm.setDue(task, choice.value)
                        }
                    }
                    if !task.due.isEmpty, !dueChoices.contains(where: { $0.value == task.due }), let due = dueLabel(task) {
                        Pill(text: due.text, color: due.overdue ? .red : .blue, selected: true) {}
                    }
                }

                pillRow("Board") {
                    ForEach(vm.boards) { b in
                        Pill(text: b.name, color: boardColor(b.color), selected: task.board == b.id) {
                            vm.setBoard(task, b.id)
                        }
                    }
                }

                HStack {
                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                    Spacer()
                    DeleteButton {
                        vm.delete(task)
                        selectedID = nil
                    }
                }
            }
        }
    }

    // MARK: - Right column: new task

    private var newTaskForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("New task")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(0.8)

            TextField("What needs doing?", text: $newTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.07)))
                .focused($focus, equals: .newTask)
                .onSubmit(addTask)
                .onKeyPress(.escape) {
                    NotificationCenter.default.post(name: .escapeKeyPressedInNotch, object: nil)
                    return .handled
                }
                .disabled(vm.link == .offline || vm.boards.isEmpty)

            if !vm.boards.isEmpty {
                pillRow("Board") {
                    ForEach(vm.boards) { b in
                        Pill(text: b.name, color: boardColor(b.color), selected: (newBoard ?? vm.boards.first?.id) == b.id) {
                            newBoard = b.id
                        }
                    }
                }
            }

            HStack {
                Text(vm.link == .waiting ? "Saved here now, added to the tracker when it syncs." : "Press Return to add. It's assigned to you.")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
                Button("Add", action: addTask)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(newTitle.isEmpty ? 0.06 : 0.22)))
                    .foregroundStyle(newTitle.isEmpty ? Color.secondary : Color.white)
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addTask() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        vm.create(title: title, board: newBoard ?? vm.boards.first?.id)
        newTitle = ""
    }

    // MARK: - Helpers

    private func pillRow<Content: View>(_ label: String, @ViewBuilder _ pills: () -> Content) -> some View {
        HStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) { pills() }
            }
        }
    }

    private struct DueChoice { let label: String; let value: String }

    private var dueChoices: [DueChoice] {
        let cal = Calendar.current
        let today = Date()
        func iso(_ days: Int) -> String {
            Self.isoFormatter.string(from: cal.date(byAdding: .day, value: days, to: today) ?? today)
        }
        return [
            DueChoice(label: "None", value: ""),
            DueChoice(label: "Today", value: iso(0)),
            DueChoice(label: "Tomorrow", value: iso(1)),
            DueChoice(label: "In 3 days", value: iso(3)),
            DueChoice(label: "Next week", value: iso(7)),
        ]
    }

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMM d")
        return f
    }()

    private func dueLabel(_ task: TrackerTask) -> (text: String, overdue: Bool)? {
        guard !task.due.isEmpty, let date = Self.isoFormatter.date(from: task.due) else { return nil }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return ("Today", false)
        case 1: return ("Tomorrow", false)
        case -1: return ("Yesterday", true)
        default: return (Self.shortFormatter.string(from: date), days < 0)
        }
    }

    private func statusColor(_ key: String) -> Color {
        switch key {
        case "research": return Color(red: 0.48, green: 0.35, blue: 0.88)
        case "working": return Color(red: 0.96, green: 0.65, blue: 0.16)
        case "review": return Color(red: 0.17, green: 0.58, blue: 0.84)
        case "paused": return Color(red: 0.60, green: 0.52, blue: 0.38)
        case "stuck": return Color(red: 0.88, green: 0.28, blue: 0.30)
        case "complete": return Color(red: 0.14, green: 0.65, blue: 0.40)
        default: return Color.gray
        }
    }

    private func priorityColor(_ key: String) -> Color {
        switch key {
        case "critical": return Color(red: 0.85, green: 0.23, blue: 0.25)
        case "high": return Color(red: 0.88, green: 0.47, blue: 0.16)
        case "medium": return Color(red: 0.17, green: 0.58, blue: 0.84)
        case "low": return Color(red: 0.49, green: 0.53, blue: 0.59)
        default: return Color.gray
        }
    }

    private func boardColor(_ index: Int?) -> Color {
        let palette: [Color] = [
            Color(red: 0.18, green: 0.36, blue: 0.92), Color(red: 0.14, green: 0.65, blue: 0.40),
            Color(red: 0.88, green: 0.47, blue: 0.16), Color(red: 0.48, green: 0.35, blue: 0.88),
            Color(red: 0.84, green: 0.25, blue: 0.48), Color(red: 0.10, green: 0.60, blue: 0.65),
            Color(red: 0.71, green: 0.54, blue: 0.07), Color(red: 0.37, green: 0.42, blue: 0.49),
        ]
        return palette[((index ?? 0) % palette.count + palette.count) % palette.count]
    }
}

private struct Pill: View {
    let text: String
    let color: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 10.5, weight: selected ? .bold : .medium, design: .rounded))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(selected ? color.opacity(0.9) : Color.white.opacity(0.07)))
                .foregroundStyle(selected ? Color.white : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}

/// Two-step delete: the first click arms it, the second deletes.
private struct DeleteButton: View {
    let action: () -> Void
    @State private var armed = false

    var body: some View {
        Button {
            if armed {
                action()
            } else {
                armed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { armed = false }
            }
        } label: {
            Label(armed ? "Click to confirm" : "Delete", systemImage: "trash")
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(armed ? Color.red.opacity(0.85) : Color.white.opacity(0.06)))
                .foregroundStyle(armed ? Color.white : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}
