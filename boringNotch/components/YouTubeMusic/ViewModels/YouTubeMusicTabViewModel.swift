//
//  YouTubeMusicTabViewModel.swift
//  boringNotch
//

import Combine
import Defaults
import Foundation
import SwiftUI

@MainActor
public final class YouTubeMusicTabViewModel: ObservableObject {
    public static let shared = YouTubeMusicTabViewModel()

    // MARK: - Published Properties
    @Published public var searchQuery: String = ""
    @Published public var searchResults: [InnerTubeTrack] = []
    @Published public var isSearching: Bool = false
    @Published public var searchError: String?
    @Published public var isSignInSheetPresented: Bool = false

    private let innerTube = InnerTubeService.shared
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // Default trending / recommended initial suggestions
    @Published public var defaultRecommendations: [InnerTubeTrack] = [
        InnerTubeTrack(videoId: "fHI8X483mQw", title: "Blinding Lights", artist: "The Weeknd", album: "After Hours", duration: "3:20", durationSeconds: 200, thumbnailUrl: URL(string: "https://i.ytimg.com/vi/fHI8X483mQw/hqdefault.jpg")),
        InnerTubeTrack(videoId: "JGwWNGJdvx8", title: "Shape of You", artist: "Ed Sheeran", album: "÷ (Divide)", duration: "3:53", durationSeconds: 233, thumbnailUrl: URL(string: "https://i.ytimg.com/vi/JGwWNGJdvx8/hqdefault.jpg")),
        InnerTubeTrack(videoId: "kJQP7kiw5Fk", title: "Despacito", artist: "Luis Fonsi ft. Daddy Yankee", album: "VIDA", duration: "4:41", durationSeconds: 281, thumbnailUrl: URL(string: "https://i.ytimg.com/vi/kJQP7kiw5Fk/hqdefault.jpg")),
        InnerTubeTrack(videoId: "RgKAFK5djSk", title: "See You Again", artist: "Wiz Khalifa ft. Charlie Puth", album: "Furious 7", duration: "3:49", durationSeconds: 229, thumbnailUrl: URL(string: "https://i.ytimg.com/vi/RgKAFK5djSk/hqdefault.jpg")),
        InnerTubeTrack(videoId: "OPf0YbXqDm0", title: "Uptown Funk", artist: "Mark Ronson ft. Bruno Mars", album: "Uptown Special", duration: "4:30", durationSeconds: 270, thumbnailUrl: URL(string: "https://i.ytimg.com/vi/OPf0YbXqDm0/hqdefault.jpg"))
    ]

    private init() {
        // Observe search query with debounce
        $searchQuery
            .removeDuplicates()
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
    }

    public func performSearch(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            self.searchResults = []
            self.isSearching = false
            self.searchError = nil
            return
        }

        self.isSearching = true
        self.searchError = nil

        searchTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let results = try await self.innerTube.searchSongs(query: trimmed)
                guard !Task.isCancelled else { return }
                self.searchResults = results
                self.isSearching = false
            } catch {
                guard !Task.isCancelled else { return }
                self.searchError = "Could not fetch search results"
                self.isSearching = false
            }
        }
    }

    public func clearSearch() {
        searchQuery = ""
        searchResults = []
        isSearching = false
    }

    public func signOutGoogle() {
        Defaults[.ytMusicSignedEmail] = nil
        Defaults[.ytMusicIsPremium] = false
    }
}
