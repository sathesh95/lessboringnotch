//
//  PomodoroTimerView.swift
//  boringNotch
//

import Defaults
import SwiftUI

struct PomodoroTimerView: View {
    @ObservedObject var vm = PomodoroViewModel.shared

    var body: some View {
        HStack(spacing: 24) {
            // MARK: - Left: Circular Progress Ring & Core Timer Display
            ZStack {
                // Background Track
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 9)

                // Animated Progress Arc
                Circle()
                    .trim(from: 0, to: vm.progress)
                    .stroke(
                        LinearGradient(
                            colors: vm.isCompleted
                                ? [Color(red: 0.2, green: 0.9, blue: 0.4), Color.green]
                                : [Color.orange, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: vm.progress)

                // Center Label Stack
                VStack(spacing: 2) {
                    if vm.isCompleted {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.green)
                            .symbolEffect(.bounce, value: vm.isPulsingGreen)

                        Text("Done!")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    } else {
                        Text(vm.timeFormatted)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)

                        Text(vm.state == .running ? "FOCUS" : (vm.state == .paused ? "PAUSED" : "READY"))
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(vm.state == .running ? .orange : .secondary)
                            .tracking(1.2)
                    }
                }
            }
            .frame(width: 120, height: 120)
            .padding(.leading, 8)

            // MARK: - Right: Controls, Presets & Messages
            VStack(alignment: .leading, spacing: 10) {
                // Preset Selection Pills
                HStack(spacing: 6) {
                    ForEach(PomodoroPreset.allCases) { preset in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                vm.selectPreset(preset)
                            }
                        }) {
                            Text(preset.rawValue)
                                .font(.system(size: 11, weight: vm.selectedPreset == preset ? .bold : .medium, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(vm.selectedPreset == preset ? Color.white.opacity(0.22) : Color.white.opacity(0.06))
                                )
                                .foregroundStyle(vm.selectedPreset == preset ? .white : .secondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.state == .running)
                        .opacity(vm.state == .running ? 0.6 : 1.0)
                    }
                }

                // Custom Minute Stepper (Visible when Custom preset is active)
                if vm.selectedPreset == .custom {
                    HStack(spacing: 8) {
                        Text("Duration:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        Button(action: {
                            vm.adjustCustomMinutes(-5)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.state == .running || vm.customMinutes <= 1)

                        Text("\(vm.customMinutes)m")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(minWidth: 32)

                        Button(action: {
                            vm.adjustCustomMinutes(5)
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.state == .running || vm.customMinutes >= 180)
                    }
                    .transition(.opacity)
                }

                // Completion Celebration / Status Message
                if vm.isCompleted {
                    HStack(spacing: 6) {
                        Text(vm.celebrationMessage)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.green)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.vertical, 2)
                    .transition(.opacity.combined(with: .scale))
                }

                // Main Play / Pause / Reset Control Buttons
                HStack(spacing: 12) {
                    if vm.state == .running {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                vm.pause()
                            }
                        }) {
                            Label("Pause", systemImage: "pause.fill")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(Color.orange.opacity(0.85)))
                                .foregroundStyle(.black)
                        }
                        .buttonStyle(.plain)
                    } else if vm.state == .paused {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                vm.resume()
                            }
                        }) {
                            Label("Resume", systemImage: "play.fill")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(Color.green.opacity(0.85)))
                                .foregroundStyle(.black)
                        }
                        .buttonStyle(.plain)
                    } else if vm.state == .completed {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                vm.start()
                            }
                        }) {
                            Label("Restart", systemImage: "arrow.counterclockwise")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(Color.green.opacity(0.85)))
                                .foregroundStyle(.black)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                vm.start()
                            }
                        }) {
                            Label("Start Focus", systemImage: "play.fill")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(Color.white))
                                .foregroundStyle(.black)
                        }
                        .buttonStyle(.plain)
                    }

                    // Reset button when timer has elapsed or is active
                    if vm.state != .idle {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                vm.reset()
                            }
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 12, weight: .bold))
                                .padding(7)
                                .background(Circle().fill(Color.white.opacity(0.12)))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .help("Reset Timer")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
}
