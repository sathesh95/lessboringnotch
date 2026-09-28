//
//  GoogleSignInSheet.swift
//  boringNotch
//

import AppKit
import Defaults
import SwiftUI
import WebKit

struct GoogleSignInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading: Bool = true
    @State private var pageTitle: String = "Sign in to YouTube Music"

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundStyle(.red)
                    Text("YouTube Music & Premium")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .padding(.trailing, 4)
                }

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // WebKit Login View
            GoogleSignInWebView(isLoading: $isLoading, pageTitle: $pageTitle) { email, isPremium in
                Defaults[.ytMusicSignedEmail] = email
                Defaults[.ytMusicIsPremium] = isPremium
                dismiss()
            }
        }
        .frame(width: 540, height: 640)
        .preferredColorScheme(.dark)
    }
}

struct GoogleSignInWebView: NSViewRepresentable {
    @Binding var isLoading: Bool
    @Binding var pageTitle: String
    let onAuthSuccess: (String, Bool) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()

        let webView = WKWebView(frame: .zero, configuration: config)
        // Authentic Safari desktop user agent
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        webView.navigationDelegate = context.coordinator

        // Direct Google Sign-In with YouTube service context
        if let url = URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=https%3A%2F%2Fmusic.youtube.com%2F") {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: GoogleSignInWebView

        init(_ parent: GoogleSignInWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.pageTitle = webView.title ?? "Sign in"
            }

            guard let url = webView.url?.absoluteString else { return }

            // When redirected to YouTube Music after successful authentication
            if url.contains("music.youtube.com") {
                checkAuthAndPremiumStatus(webView: webView)
            }
        }

        private func checkAuthAndPremiumStatus(webView: WKWebView) {
            // Check if user is logged into YouTube Music by inspecting account avatar or cookies
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                let hasSapisid = cookies.contains { $0.name == "__Secure-3PAPISID" || $0.name == "SAPISID" }
                if hasSapisid {
                    // Extract email or username via document title or script
                    let js = """
                    (function() {
                        var email = '';
                        var isPremium = document.querySelector('ytmusic-logo[aria-label*="Premium"]') !== null;
                        if (!isPremium) {
                            isPremium = document.body.innerText.includes('Music Premium');
                        }
                        return { email: email, isPremium: isPremium };
                    })()
                    """
                    webView.evaluateJavaScript(js) { result, _ in
                        var isPremium = false
                        if let dict = result as? [String: Any], let premium = dict["isPremium"] as? Bool {
                            isPremium = premium
                        }
                        DispatchQueue.main.async {
                            self.parent.onAuthSuccess("Signed in", isPremium)
                        }
                    }
                }
            }
        }
    }
}
