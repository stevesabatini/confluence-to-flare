import SwiftUI
import WebKit

/// Shows a rendered preview of a Confluence release note page.
struct PreviewView: View {
    let page: ConfluencePage
    @Environment(AppState.self) private var appState
    @State private var htmlContent: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(page.displayDate.isEmpty ? page.title : "Release: \(page.displayDate)")
                        .font(.headline)
                    Text(page.title)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                // Type badge
                Text(page.type.rawValue.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badgeColor.opacity(0.15))
                    .foregroundStyle(badgeColor)
                    .clipShape(Capsule())
            }
            .padding()
            .background(.bar)

            Divider()

            // Content
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Fetching content from Confluence...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                WebView(html: htmlContent)
            }
        }
        .frame(width: 750, height: 600)
        .task {
            await loadContent()
        }
    }

    private var badgeColor: Color {
        switch page.type {
        case .features: return .blue
        case .patch: return .orange
        case .other: return .gray
        }
    }

    private func loadContent() async {
        guard let client = appState.createConfluenceClient() else {
            errorMessage = "Unable to connect to Confluence. Check Settings."
            isLoading = false
            return
        }

        do {
            let xhtml = try await client.getPageContent(pageID: page.id)
            let bodyHTML = try ContentConverter.convert(
                xhtml: xhtml,
                imageMapping: [:],
                imageFolder: ""
            )
            htmlContent = wrapInPreviewHTML(title: page.displayDate, body: bodyHTML)
            isLoading = false
        } catch {
            errorMessage = "Failed to load: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func wrapInPreviewHTML(title: String, body: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                max-width: 700px;
                margin: 20px auto;
                padding: 0 20px;
                line-height: 1.6;
                color: #e0e0e0;
                background: #1e1e1e;
            }
            @media (prefers-color-scheme: light) {
                body { color: #333; background: #fff; }
                .note, .warning, .tip { border-left-color: #0066cc; background: #f0f7ff; color: #333; }
                .warning { border-left-color: #cc6600; background: #fff7f0; }
                .tip { border-left-color: #00994d; background: #f0fff5; }
                table { border-color: #ddd; }
                th { background: #f5f5f5; color: #333; }
                td { border-color: #ddd; }
                code { background: #f4f4f4; color: #333; }
                pre { background: #f4f4f4; color: #333; }
                h1, h2, h3 { color: #333; }
            }
            h1, h2, h3 { color: #fff; }
            h2 { border-bottom: 1px solid #444; padding-bottom: 6px; margin-top: 24px; }
            img { max-width: 100%; height: auto; border-radius: 4px; margin: 8px 0; }
            table { border-collapse: collapse; width: 100%; margin: 12px 0; border: 1px solid #444; }
            th, td { padding: 8px 12px; text-align: left; border: 1px solid #444; }
            th { background: #2a2a2a; font-weight: 600; }
            .note, .warning, .tip {
                padding: 12px 16px;
                margin: 12px 0;
                border-left: 4px solid #4a9eff;
                background: #1a2a3a;
                border-radius: 0 4px 4px 0;
            }
            .warning { border-left-color: #ff9f43; background: #2a2215; }
            .tip { border-left-color: #2ed573; background: #1a2a20; }
            code { background: #2a2a2a; padding: 2px 6px; border-radius: 3px; font-size: 0.9em; }
            pre { background: #2a2a2a; padding: 12px; border-radius: 6px; overflow-x: auto; }
            pre code { background: none; padding: 0; }
            ul, ol { padding-left: 24px; }
            li { margin: 4px 0; }
        </style>
        </head>
        <body>
            <h1>Release Notes - \(title)</h1>
            \(body)
        </body>
        </html>
        """
    }
}

// MARK: - WebView (NSViewRepresentable wrapper for WKWebView)

struct WebView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}
