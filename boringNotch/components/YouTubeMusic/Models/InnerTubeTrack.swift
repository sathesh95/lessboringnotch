//
//  InnerTubeTrack.swift
//  boringNotch
//

import Foundation

public struct InnerTubeTrack: Identifiable, Hashable, Equatable, Codable {
    public let id: String
    public let videoId: String
    public let title: String
    public let artist: String
    public let album: String?
    public let duration: String
    public let durationSeconds: Int
    public let thumbnailUrl: URL?

    public init(
        videoId: String,
        title: String,
        artist: String,
        album: String? = nil,
        duration: String = "",
        durationSeconds: Int = 0,
        thumbnailUrl: URL? = nil
    ) {
        self.id = videoId
        self.videoId = videoId
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.durationSeconds = durationSeconds
        self.thumbnailUrl = thumbnailUrl
    }
}
