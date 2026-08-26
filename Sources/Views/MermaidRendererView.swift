import SwiftUI
import WebKit

// MARK: - Interactive Mermaid Diagram View
public struct MermaidRendererView: View {
    public let code: String
    public let isDark: Bool
    public let primaryAccent: Color
    
    @State private var dynamicHeight: CGFloat = 160
    @State private var isCopied = false
    @State private var hasError = false
    @State private var errorMessage = ""
    
    public init(code: String, isDark: Bool = true, primaryAccent: Color = .blue) {
        self.code = code
        self.isDark = isDark
        self.primaryAccent = primaryAccent
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(primaryAccent)
                    Text("MERMAID DIAGRAM")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Copy Code Button
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    withAnimation(.easeInOut(duration: 0.15)) { isCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { isCopied = false }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9, weight: .semibold))
                        Text(isCopied ? "Copied" : "Copy")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(isCopied ? .emerald : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.sidebarBackground(isDark).opacity(0.7))
            
            Divider()
                .background(Color.subtleBorder(isDark))
            
            // Mermaid Diagram Web View
            if hasError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.amber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mermaid Syntax Error")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.amber)
                        Text(errorMessage)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
            } else {
                MermaidWKWebView(
                    code: code,
                    isDark: isDark,
                    dynamicHeight: $dynamicHeight,
                    onError: { err in
                        self.hasError = true
                        self.errorMessage = err
                    }
                )
                .frame(height: max(100, dynamicHeight))
            }
        }
        .background(Color.cardBackground(isDark))
        .cornerRadius(AppRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.sm)
                .stroke(Color.subtleBorder(isDark), lineWidth: 1)
        )
        .padding(.vertical, 6)
    }
}

// MARK: - Mermaid WKWebView Representable
public struct MermaidWKWebView: NSViewRepresentable {
    public let code: String
    public let isDark: Bool
    @Binding public var dynamicHeight: CGFloat
    public var onError: (String) -> Void

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "sizeNotification")
        userContentController.add(context.coordinator, name: "errorNotification")
        config.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        loadMermaidHTML(into: webView)
        return webView
    }

    public func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        loadMermaidHTML(into: webView)
    }

    private func loadMermaidHTML(into webView: WKWebView) {
        let themeName = isDark ? "dark" : "default"
        let bgColor = "transparent"
        let textColor = isDark ? "#e2e8f0" : "#0f172a"
        
        let escapedCode = code
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <script src="https://cdn.jsdelivr.net/npm/mermaid@10.9.0/dist/mermaid.min.js"></script>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    background-color: \(bgColor);
                    color: \(textColor);
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    padding: 16px;
                    overflow-x: auto;
                    overflow-y: hidden;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                }
                #diagram {
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    width: 100%;
                }
                svg {
                    max-width: 100%;
                    height: auto;
                }
            </style>
        </head>
        <body>
            <div id="diagram"></div>
            <script>
                try {
                    mermaid.initialize({
                        startOnLoad: false,
                        theme: '\(themeName)',
                        securityLevel: 'loose',
                        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif'
                    });
                    
                    const code = `\(escapedCode)`;
                    mermaid.render('mermaid-svg', code).then(result => {
                        document.getElementById('diagram').innerHTML = result.svg;
                        setTimeout(() => {
                            const svgEl = document.querySelector('svg');
                            const height = svgEl ? svgEl.getBoundingClientRect().height + 32 : document.body.scrollHeight;
                            window.webkit.messageHandlers.sizeNotification.postMessage(Math.max(120, height));
                        }, 60);
                    }).catch(err => {
                        window.webkit.messageHandlers.errorNotification.postMessage(err.message || 'Syntax error in Mermaid definition');
                    });
                } catch(e) {
                    window.webkit.messageHandlers.errorNotification.postMessage(e.message);
                }
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MermaidWKWebView

        init(_ parent: MermaidWKWebView) {
            self.parent = parent
        }

        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "sizeNotification", let height = message.body as? CGFloat {
                DispatchQueue.main.async {
                    self.parent.dynamicHeight = height
                }
            } else if message.name == "errorNotification", let errorStr = message.body as? String {
                DispatchQueue.main.async {
                    self.parent.onError(errorStr)
                }
            }
        }
    }
}
