//
//  YouTubePlayerEngine.swift
//  boringNotch
//

import AppKit
import Combine
import Foundation
import WebKit

@MainActor
public final class YouTubePlayerEngine: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate {
    public static let shared = YouTubePlayerEngine()

    // MARK: - Published Properties
    @Published public private(set) var currentTrack: InnerTubeTrack?
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentTime: Double = 0
    @Published public private(set) var duration: Double = 0
    @Published public private(set) var queue: [InnerTubeTrack] = []
    @Published public private(set) var queueIndex: Int = 0
    @Published public private(set) var isBuffering: Bool = false
    @Published public private(set) var artworkImage: NSImage?

    private var webView: WKWebView!
    private var isPlayerReady: Bool = false
    private var pendingVideoIdToLoad: String?
    private var artworkCancellable: AnyCancellable?

    private override init() {
        super.init()
        setupWebView()
    }

    private func setupWebView() {
        let contentController = WKUserContentController()
        contentController.add(self, name: "ytPlayer")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        config.websiteDataStore = WKWebsiteDataStore.default()

        // macOS standard Safari desktop user agent so YouTube treats this as a legitimate desktop player
        let customUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = customUA
        webView.navigationDelegate = self

        loadPlayerHTML()
    }

    private func loadPlayerHTML() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body { margin: 0; background: #000; overflow: hidden; }
                #player { width: 100vw; height: 100vh; }
            </style>
        </head>
        <body>
            <div id="player"></div>
            <script>
                var tag = document.createElement('script');
                tag.src = "https://www.youtube.com/iframe_api";
                var firstScriptTag = document.getElementsByTagName('script')[0];
                firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

                var player;
                var timePollInterval = null;

                function onYouTubeIframeAPIReady() {
                    player = new YT.Player('player', {
                        height: '100%',
                        width: '100%',
                        playerVars: {
                            'autoplay': 1,
                            'controls': 0,
                            'disablekb': 1,
                            'enablejsapi': 1,
                            'fs': 0,
                            'modestbranding': 1,
                            'playsinline': 1,
                            'origin': 'https://music.youtube.com'
                        },
                        events: {
                            'onReady': onPlayerReady,
                            'onStateChange': onPlayerStateChange,
                            'onError': onPlayerError
                        }
                    });
                }

                function onPlayerReady(event) {
                    window.webkit.messageHandlers.ytPlayer.postMessage({ type: 'ready' });
                }

                function onPlayerStateChange(event) {
                    // -1: unstarted, 0: ended, 1: playing, 2: paused, 3: buffering, 5: video cued
                    window.webkit.messageHandlers.ytPlayer.postMessage({
                        type: 'state',
                        state: event.data,
                        duration: player.getDuration ? player.getDuration() : 0
                    });

                    if (event.data === 1) { // Playing
                        startTimePoll();
                    } else {
                        stopTimePoll();
                    }
                }

                function onPlayerError(event) {
                    window.webkit.messageHandlers.ytPlayer.postMessage({
                        type: 'error',
                        code: event.data
                    });
                }

                function startTimePoll() {
                    stopTimePoll();
                    timePollInterval = setInterval(function() {
                        if (player && player.getCurrentTime) {
                            window.webkit.messageHandlers.ytPlayer.postMessage({
                                type: 'time',
                                current: player.getCurrentTime(),
                                duration: player.getDuration()
                            });
                        }
                    }, 500);
                }

                function stopTimePoll() {
                    if (timePollInterval) {
                        clearInterval(timePollInterval);
                        timePollInterval = null;
                    }
                }

                function playTrack(videoId) {
                    if (player && player.loadVideoById) {
                        player.loadVideoById(videoId);
                    }
                }

                function pauseTrack() {
                    if (player && player.pauseVideo) {
                        player.pauseVideo();
                    }
                }

                function resumeTrack() {
                    if (player && player.playVideo) {
                        player.playVideo();
                    }
                }

                function seekTrack(seconds) {
                    if (player && player.seekTo) {
                        player.seekTo(seconds, true);
                    }
                }
            </script>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: URL(string: "https://music.youtube.com"))
    }

    // MARK: - Playback Controls
    public func play(track: InnerTubeTrack, in queue: [InnerTubeTrack] = []) {
        self.currentTrack = track
        if !queue.isEmpty {
            self.queue = queue
            if let idx = queue.firstIndex(of: track) {
                self.queueIndex = idx
            }
        } else if !self.queue.contains(track) {
            self.queue.append(track)
            self.queueIndex = self.queue.count - 1
        }

        self.currentTime = 0
        self.duration = Double(track.durationSeconds)
        self.fetchArtwork(for: track)

        if isPlayerReady {
            let js = "playTrack('\(track.videoId)');"
            webView.evaluateJavaScript(js, completionHandler: nil)
        } else {
            pendingVideoIdToLoad = track.videoId
        }
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    public func pause() {
        webView.evaluateJavaScript("pauseTrack();", completionHandler: nil)
        isPlaying = false
        syncWithMusicManager(playing: false)
    }

    public func resume() {
        webView.evaluateJavaScript("resumeTrack();", completionHandler: nil)
        isPlaying = true
        syncWithMusicManager(playing: true)
    }

    public func seek(to seconds: Double) {
        self.currentTime = seconds
        webView.evaluateJavaScript("seekTrack(\(seconds));", completionHandler: nil)
    }

    public func nextTrack() {
        guard !queue.isEmpty else { return }
        let nextIndex = queueIndex + 1
        if nextIndex < queue.count {
            queueIndex = nextIndex
            play(track: queue[nextIndex], in: queue)
        }
    }

    public func previousTrack() {
        guard !queue.isEmpty else { return }
        if currentTime > 3.0 {
            seek(to: 0)
            return
        }
        let prevIndex = queueIndex - 1
        if prevIndex >= 0 {
            queueIndex = prevIndex
            play(track: queue[prevIndex], in: queue)
        }
    }

    // MARK: - Artwork Fetching
    private func fetchArtwork(for track: InnerTubeTrack) {
        artworkCancellable?.cancel()
        guard let url = track.thumbnailUrl else {
            self.artworkImage = nil
            return
        }

        artworkCancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { NSImage(data: $0.data) }
            .replaceError(with: nil)
            .receive(on: RunLoop.main)
            .sink { [weak self] image in
                guard let self = self else { return }
                self.artworkImage = image
                if self.isPlaying, let img = image {
                    Task { @MainActor in
                        MusicManager.shared.albumArt = img
                    }
                }
            }
    }

    private func syncWithMusicManager(playing: Bool) {
        Task { @MainActor in
            if playing, let track = self.currentTrack {
                MusicManager.shared.songTitle = track.title
                MusicManager.shared.artistName = track.artist
                MusicManager.shared.songDuration = self.duration
                MusicManager.shared.elapsedTime = self.currentTime
                MusicManager.shared.isPlaying = true
                MusicManager.shared.isPlayerIdle = false
                if let art = self.artworkImage {
                    MusicManager.shared.albumArt = art
                }
            } else if !playing && MusicManager.shared.isPlaying {
                MusicManager.shared.isPlaying = false
            }
        }
    }

    // MARK: - WKScriptMessageHandler
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let type = dict["type"] as? String else {
            return
        }

        switch type {
        case "ready":
            isPlayerReady = true
            if let pending = pendingVideoIdToLoad {
                pendingVideoIdToLoad = nil
                let js = "playTrack('\(pending)');"
                webView.evaluateJavaScript(js, completionHandler: nil)
            }

        case "state":
            if let state = dict["state"] as? Int {
                switch state {
                case 1: // Playing
                    isPlaying = true
                    isBuffering = false
                    syncWithMusicManager(playing: true)
                case 2: // Paused
                    isPlaying = false
                    isBuffering = false
                    syncWithMusicManager(playing: false)
                case 3: // Buffering
                    isBuffering = true
                case 0: // Ended
                    isPlaying = false
                    syncWithMusicManager(playing: false)
                    nextTrack()
                default:
                    break
                }
            }
            if let dur = dict["duration"] as? Double, dur > 0 {
                self.duration = dur
            }

        case "time":
            if let current = dict["current"] as? Double {
                self.currentTime = current
            }
            if let dur = dict["duration"] as? Double, dur > 0 {
                self.duration = dur
            }

        case "error":
            isBuffering = false
            // On embed error (e.g. copyright restricted or age restricted), skip to next track
            nextTrack()

        default:
            break
        }
    }
}
