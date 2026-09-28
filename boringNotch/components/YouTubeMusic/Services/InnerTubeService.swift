//
//  InnerTubeService.swift
//  boringNotch
//

import Foundation

public final class InnerTubeService {
    public static let shared = InnerTubeService()

    private let endpoint = "https://music.youtube.com/youtubei/v1/search?alt=json&key=AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30"
    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }

    /// Performs an instant song search against YouTube Music InnerTube API (unauthenticated)
    public func searchSongs(query: String) async throws -> [InnerTubeTrack] {
        guard let url = URL(string: endpoint) else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Referer")

        // Filter params for songs: "Eg-KAQwIABAAGAEgASgB" (corresponds to songs filter in WEB_REMIX)
        let body: [String: Any] = [
            "query": query,
            "params": "Eg-KAQwIABAAGAEgASgB",
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20240901.01.00",
                    "hl": "en",
                    "gl": "US"
                ],
                "user": [:]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        return parseSearchResponse(json)
    }

    /// Parses nested InnerTube JSON structures to extract track details
    private func parseSearchResponse(_ json: [String: Any]) -> [InnerTubeTrack] {
        var tracks: [InnerTubeTrack] = []

        // Navigate: contents -> tabbedSearchResultsRenderer -> tabs[0] -> tabRenderer -> content -> sectionListRenderer -> contents
        guard let contents = json["contents"] as? [String: Any],
              let tabbed = contents["tabbedSearchResultsRenderer"] as? [String: Any],
              let tabs = tabbed["tabs"] as? [[String: Any]],
              let firstTab = tabs.first,
              let tabRenderer = firstTab["tabRenderer"] as? [String: Any],
              let tabContent = tabRenderer["content"] as? [String: Any],
              let sectionList = tabContent["sectionListRenderer"] as? [String: Any],
              let sectionContents = sectionList["contents"] as? [[String: Any]] else {
            return []
        }

        for section in sectionContents {
            guard let musicShelf = section["musicShelfRenderer"] as? [String: Any],
                  let items = musicShelf["contents"] as? [[String: Any]] else {
                continue
            }

            for item in items {
                guard let listItem = item["musicResponsiveListItemRenderer"] as? [String: Any] else {
                    continue
                }

                if let track = parseListItem(listItem) {
                    tracks.append(track)
                }
            }
        }

        return tracks
    }

    private func parseListItem(_ item: [String: Any]) -> InnerTubeTrack? {
        // Extract video ID from play navigation endpoint or playlist item overlay
        var videoId: String?

        if let overlay = item["overlay"] as? [String: Any],
           let thumbOverlay = overlay["musicItemThumbnailOverlayRenderer"] as? [String: Any],
           let content = thumbOverlay["content"] as? [String: Any],
           let playBtn = content["musicPlayButtonRenderer"] as? [String: Any],
           let playNav = playBtn["playNavigationEndpoint"] as? [String: Any],
           let watchEndpoint = playNav["watchEndpoint"] as? [String: Any] {
            videoId = watchEndpoint["videoId"] as? String
        }

        // Flex columns: column 0 = Title, column 1 = Artist / Album / Duration
        guard let flexColumns = item["flexColumns"] as? [[String: Any]],
              flexColumns.count >= 2 else {
            return nil
        }

        // Title
        guard let col0 = flexColumns[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
              let text0 = col0["text"] as? [String: Any],
              let runs0 = text0["runs"] as? [[String: Any]],
              let firstRun0 = runs0.first,
              let title = firstRun0["text"] as? String else {
            return nil
        }

        if videoId == nil {
            if let navEndpoint = firstRun0["navigationEndpoint"] as? [String: Any],
               let watchEndpoint = navEndpoint["watchEndpoint"] as? [String: Any] {
                videoId = watchEndpoint["videoId"] as? String
            }
        }

        guard let resolvedVideoId = videoId, !resolvedVideoId.isEmpty else {
            return nil
        }

        // Subtitle runs: Artist • Album • Duration
        var artist = "Unknown Artist"
        var album: String?
        var duration = ""
        var durationSeconds = 0

        if let col1 = flexColumns[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
           let text1 = col1["text"] as? [String: Any],
           let runs1 = text1["runs"] as? [[String: Any]] {
            let validRuns = runs1.compactMap { $0["text"] as? String }.filter { $0 != " • " && $0 != "•" }

            if let firstArtist = validRuns.first {
                artist = firstArtist
            }

            if validRuns.count >= 2 {
                let candidate = validRuns.last ?? ""
                if candidate.contains(":") {
                    duration = candidate
                    durationSeconds = parseDurationToSeconds(candidate)
                    if validRuns.count >= 3 {
                        album = validRuns[1]
                    }
                } else {
                    album = candidate
                }
            }
        }

        // Thumbnail
        var thumbnailUrl: URL?
        if let thumbnail = item["thumbnail"] as? [String: Any],
           let renderer = thumbnail["musicThumbnailRenderer"] as? [String: Any],
           let thumbObj = renderer["thumbnail"] as? [String: Any],
           let thumbs = thumbObj["thumbnails"] as? [[String: Any]],
           let bestThumb = thumbs.last,
           let urlStr = bestThumb["url"] as? String {
            thumbnailUrl = URL(string: urlStr)
        }

        return InnerTubeTrack(
            videoId: resolvedVideoId,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            durationSeconds: durationSeconds,
            thumbnailUrl: thumbnailUrl
        )
    }

    private func parseDurationToSeconds(_ durationStr: String) -> Int {
        let parts = durationStr.split(separator: ":").compactMap { Int($0) }
        if parts.count == 2 {
            return (parts[0] * 60) + parts[1]
        } else if parts.count == 3 {
            return (parts[0] * 3600) + (parts[1] * 60) + parts[2]
        }
        return 0
    }
}
