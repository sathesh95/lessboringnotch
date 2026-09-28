//
//  PomodoroViewModel.swift
//  boringNotch
//

import AppKit
import Combine
import Defaults
import Foundation
import SwiftUI

public enum PomodoroState: String, Equatable {
    case idle
    case running
    case paused
    case completed
}

public enum PomodoroPreset: String, CaseIterable, Identifiable {
    case ten = "10m"
    case twenty = "20m"
    case thirty = "30m"
    case custom = "Custom"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ten: return "10 mins"
        case .twenty: return "20 mins"
        case .thirty: return "30 mins"
        case .custom: return "Custom"
        }
    }

    public var subtitle: String {
        switch self {
        case .ten: return "Quick Sprint"
        case .twenty: return "Standard"
        case .thirty: return "Deep Focus"
        case .custom: return "Customized"
        }
    }

    public var minutes: Int {
        switch self {
        case .ten: return 10
        case .twenty: return 20
        case .thirty: return 30
        case .custom: return 25
        }
    }
}

@MainActor
final class PomodoroViewModel: ObservableObject {
    static let shared = PomodoroViewModel()

    @Published var selectedPreset: PomodoroPreset = .twenty
    @Published var customMinutes: Int = 25
    @Published var totalDurationSeconds: Int = 20 * 60
    @Published var remainingSeconds: Int = 20 * 60
    @Published var state: PomodoroState = .idle

    // Celebration & Pulse State
    @Published var isPulsingGreen: Bool = false
    @Published var celebrationMessage: String = "Your Session is Complete ✨🎉"
    @Published var completedSessionsCount: Int = 0

    private var timerTask: Task<Void, Never>?
    private var pulseEndTask: Task<Void, Never>?

    static let celebrationMessages: [String] = [
        "Your Session is Complete ✨🎉",
        "Time for a well-deserved break! ☕️🌿",
        "Crushed it! Take 5 and recharge 🚀🏆",
        "Session Finished! Great focus! 💫🌟",
        "Outstanding work! Stretch & relax 🧘✨"
    ]

    private init() {
        let savedDuration = Defaults[.defaultPomodoroDuration]
        if savedDuration == 10 {
            selectPreset(.ten)
        } else if savedDuration == 20 {
            selectPreset(.twenty)
        } else if savedDuration == 30 {
            selectPreset(.thirty)
        } else {
            customMinutes = max(1, min(90, savedDuration))
            selectPreset(.custom)
        }
    }

    // MARK: - Timer Presets & Setup
    func selectPreset(_ preset: PomodoroPreset) {
        guard state != .running else { return }
        selectedPreset = preset
        let minutes = (preset == .custom) ? customMinutes : preset.minutes
        totalDurationSeconds = minutes * 60
        remainingSeconds = totalDurationSeconds
        state = .idle
        isPulsingGreen = false
    }

    func setCustomMinutes(_ minutes: Int) {
        guard state != .running else { return }
        customMinutes = max(1, min(90, minutes))
        if selectedPreset == .custom {
            totalDurationSeconds = customMinutes * 60
            remainingSeconds = totalDurationSeconds
            state = .idle
            isPulsingGreen = false
        }
    }

    // MARK: - Timer Control
    func start() {
        isPulsingGreen = false
        pulseEndTask?.cancel()
        state = .running
        startTimerLoop()
    }

    func pause() {
        state = .paused
        timerTask?.cancel()
        timerTask = nil
    }

    func resume() {
        state = .running
        startTimerLoop()
    }

    func togglePlayPause() {
        switch state {
        case .idle:
            start()
        case .running:
            pause()
        case .paused:
            resume()
        case .completed:
            reset()
            start()
        }
    }

    func reset() {
        timerTask?.cancel()
        timerTask = nil
        pulseEndTask?.cancel()
        pulseEndTask = nil
        isPulsingGreen = false
        state = .idle

        let minutes = (selectedPreset == .custom) ? customMinutes : selectedPreset.minutes
        totalDurationSeconds = minutes * 60
        remainingSeconds = totalDurationSeconds
    }

    // MARK: - Internal Loop
    private func startTimerLoop() {
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self = self, !Task.isCancelled else { break }

                if self.state == .running {
                    if self.remainingSeconds > 1 {
                        self.remainingSeconds -= 1
                    } else {
                        self.remainingSeconds = 0
                        self.handleTimerCompleted()
                        break
                    }
                }
            }
        }
    }

    private func handleTimerCompleted() {
        timerTask?.cancel()
        timerTask = nil

        state = .completed
        completedSessionsCount += 1
        celebrationMessage = Self.celebrationMessages.randomElement() ?? "Your Session is Complete ✨🎉"

        withAnimation(.easeInOut(duration: 0.5)) {
            isPulsingGreen = true
        }

        playCompletionSound()

        // Automatically stop the intense pulse after 12 seconds, but keep completion badge
        pulseEndTask?.cancel()
        pulseEndTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(12))
            guard let self = self, !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.6)) {
                self.isPulsingGreen = false
            }
        }
    }

    func playCompletionSound() {
        guard Defaults[.pomodoroSoundEnabled] else { return }

        // Try playing system celebratory sounds in order of preference
        if let sound = NSSound(named: "Hero") {
            sound.play()
        } else if let sound = NSSound(named: "Glass") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    // MARK: - Formatted Output
    var timeRemainingFormatted: String {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    var progress: Double {
        guard totalDurationSeconds > 0 else { return 0 }
        let elapsed = totalDurationSeconds - remainingSeconds
        return min(1.0, max(0.0, Double(elapsed) / Double(totalDurationSeconds)))
    }

    var isRunning: Bool {
        state == .running
    }

    var isCompleted: Bool {
        state == .completed
    }
}
