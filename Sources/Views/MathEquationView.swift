import SwiftUI
import WebKit

// MARK: - KaTeX Block Math Equation View
public struct MathEquationBlockView: View {
    public let latex: String
    public let isDark: Bool
    public let primaryAccent: Color
    
    @State private var webViewHeight: CGFloat = 60
    
    public init(latex: String, isDark: Bool = true, primaryAccent: Color = .blue) {
        self.latex = latex
        self.isDark = isDark
        self.primaryAccent = primaryAccent
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            KaTeXWebView(
                latex: latex,
                isDisplayMode: true,
                isDark: isDark,
                dynamicHeight: $webViewHeight
            )
            .frame(height: max(44, webViewHeight))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.cardBackground(isDark).opacity(0.6))
        .cornerRadius(AppRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.sm)
                .stroke(Color.subtleBorder(isDark), lineWidth: 1)
        )
        .padding(.vertical, 4)
    }
}

// MARK: - KaTeX Inline Math View
public struct InlineMathView: View {
    public let latex: String
    public let isDark: Bool
    
    @State private var calculatedWidth: CGFloat = 80
    
    public init(latex: String, isDark: Bool = true) {
        self.latex = latex
        self.isDark = isDark
    }
    
    public var body: some View {
        KaTeXWebView(
            latex: latex,
            isDisplayMode: false,
            isDark: isDark,
            dynamicHeight: .constant(24)
        )
        .frame(minWidth: 20, maxWidth: calculatedWidth, minHeight: 22, maxHeight: 26)
        .padding(.horizontal, 3)
        .padding(.vertical, 1)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(4)
    }
}

// MARK: - Embedded KaTeX WKWebView Representable
public struct KaTeXWebView: NSViewRepresentable {
    public let latex: String
    public let isDisplayMode: Bool
    public let isDark: Bool
    @Binding public var dynamicHeight: CGFloat

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "sizeNotification")
        config.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        loadKaTeXHTML(into: webView)
        return webView
    }

    public func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        loadKaTeXHTML(into: webView)
    }

    private func loadKaTeXHTML(into webView: WKWebView) {
        let textColor = isDark ? "#e2e8f0" : "#0f172a"
        let bgColor = "transparent"
        let display = isDisplayMode ? "true" : "false"
        
        // Escape special characters for JavaScript string
        let escapedLatex = latex
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "\n", with: " ")

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
            <script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    background-color: \(bgColor);
                    color: \(textColor);
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    display: flex;
                    justify-content: \(isDisplayMode ? "center" : "flex-start");
                    align-items: center;
                    overflow-x: auto;
                    overflow-y: hidden;
                    font-size: \(isDisplayMode ? "16px" : "14px");
                }
                #math-container {
                    padding: 4px;
                    display: inline-block;
                }
                .katex-display { margin: 0 !important; }
            </style>
        </head>
        <body>
            <div id="math-container"></div>
            <script>
                try {
                    const raw = `\(escapedLatex)`;
                    katex.render(raw, document.getElementById('math-container'), {
                        displayMode: \(display),
                        throwOnError: false
                    });
                    setTimeout(() => {
                        const height = Math.max(32, document.body.scrollHeight);
                        window.webkit.messageHandlers.sizeNotification.postMessage(height);
                    }, 50);
                } catch(e) {
                    document.getElementById('math-container').innerText = e.message;
                }
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: KaTeXWebView

        init(_ parent: KaTeXWebView) {
            self.parent = parent
        }

        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "sizeNotification", let height = message.body as? CGFloat {
                DispatchQueue.main.async {
                    self.parent.dynamicHeight = height + 8
                }
            }
        }
    }
}
