//
//  YouTubeMusicTabView.swift
//  boringNotch
//

import Defaults
import SwiftUI

struct YouTubeMusicTabView: View {
    @StateObject private var tabVM = YouTubeMusicTabViewModel.shared
    @ObservedObject private var player = YouTubePlayerEngine.shared
    @Default(.ytMusicSignedEmail) private var signedEmail
    @Default(.ytMusicIsPremium) private var isPremium

    var body: some View {
        VStack(spacing: 8) {
            // MARK: - Header & Search Bar
            HStack(spacing: 8) {
                // Search Field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    TextField("Search YouTube Music...", text: $tabVM.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)

                    if !tabVM.searchQuery.isEmpty {
                        Button(action: {
                            tabVM.clearSearch()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    if tabVM.isSearching {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 14, height: 14)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                )

                // Google Account / Premium Badge Button
                Button(action: {
                    tabVM.isSignInSheetPresented = true
                }) {
                    HStack(spacing: 4) {
                        if signedEmail != nil {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(isPremium ? .yellow : .green)
                                .font(.system(size: 11))
                            Text(isPremium ? "Premium" : "Signed In")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(isPremium ? .yellow : .white)
                        } else {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.8))
                            Text("Sign In")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(signedEmail != nil ? (isPremium ? Color.yellow.opacity(0.2) : Color.white.opacity(0.12)) : Color.red.opacity(0.8))
                    )
                }
                .buttonStyle(.plain)
                .help(signedEmail != nil ? (isPremium ? "YouTube Music Premium Active" : "Google Account Connected") : "Sign in with Google for YouTube Premium")
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)

            // MARK: - Track List (Search Results or Recommended)
            let displayList = !tabVM.searchResults.isEmpty ? tabVM.searchResults : tabVM.defaultRecommendations

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 3) {
                    ForEach(displayList) { track in
                        TrackRowView(
                            track: track,
                            isPlaying: player.currentTrack?.videoId == track.videoId && player.isPlaying,
                            isCurrent: player.currentTrack?.videoId == track.videoId
                        ) {
                            player.play(track: track, in: displayList)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(maxHeight: .infinity)

            // MARK: - Mini Player Footer
            if let current = player.currentTrack {
                HStack(spacing: 10) {
                    // Artwork Thumbnail
                    if let image = player.artworkImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            )
                    }

                    // Title & Artist
                    VStack(alignment: .leading, spacing: 2) {
                        Text(current.title)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(current.artist)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Controls: Prev / Play-Pause / Next
                    HStack(spacing: 8) {
                        Button(action: {
                            player.previousTrack()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            player.togglePlayPause()
                        }) {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            player.nextTrack()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }

                    // Scrubber Duration Text
                    Text(formatSeconds(player.currentTime) + " / " + (current.duration.isEmpty ? formatSeconds(player.duration) : current.duration))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 62, alignment: .trailing)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $tabVM.isSignInSheetPresented) {
            GoogleSignInSheet()
        }
    }

    private func formatSeconds(_ seconds: Double) -> String {
        let sec = Int(seconds)
        let m = sec / 60
        let s = sec % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Track Row View
struct TrackRowView: View {
    let track: InnerTubeTrack
    let isPlaying: Bool
    let isCurrent: Bool
    let onSelect: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // Thumbnail or play icon
                ZStack {
                    if let url = track.thumbnailUrl {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                            default:
                                Color.white.opacity(0.08)
                            }
                        }
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    } else {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 26, height: 26)
                    }

                    if isPlaying {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                    }
                }

                // Title and Artist
                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title)
                        .font(.system(size: 11, weight: isCurrent ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isCurrent ? .red : .white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(track.artist + (track.album != nil ? " • \(track.album!)" : ""))
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Duration
                Text(track.duration)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.white.opacity(0.08) : (isCurrent ? Color.white.opacity(0.04) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
