import SwiftUI
import WebKit
import PhotosUI

struct WebViewContainer: UIViewRepresentable {

    let url: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {

        let config = WKWebViewConfiguration()

        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .default()

        if #available(iOS 14.0, *) {
            let prefs = WKWebpagePreferences()
            prefs.allowsContentJavaScript = true
            config.defaultWebpagePreferences = prefs
        } else {
            config.preferences.javaScriptEnabled = true
        }

        if #available(iOS 14.5, *) {
            config.limitsNavigationsToAppBoundDomains = false
            config.allowsPictureInPictureMediaPlayback = true
        }

        let antiDetectJS = """
        Object.defineProperty(navigator, 'webdriver', { get: () => false });
        Object.defineProperty(navigator, 'platform', { get: () => 'iPhone' });
        Object.defineProperty(navigator, 'vendor', { get: () => 'Apple Computer, Inc.' });

        window.chrome = { runtime: {} };

        Object.defineProperty(navigator, 'languages', {
            get: () => ['en-US', 'en']
        });

        const originalQuery = window.navigator.permissions.query;
        window.navigator.permissions.query = (parameters) =>
            parameters.name === 'notifications'
                ? Promise.resolve({ state: Notification.permission })
                : originalQuery(parameters);
        """

        let script = WKUserScript(
            source: antiDetectJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )

        config.userContentController.addUserScript(script)

        let viewport = """
        var meta = document.createElement('meta');
        meta.name = 'viewport';
        meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
        document.head.appendChild(meta);
        """

        config.userContentController.addUserScript(
            WKUserScript(source: viewport, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )

        HTTPCookieStorage.shared.cookies?.forEach {
            config.websiteDataStore.httpCookieStore.setCookie($0)
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        
        webView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        webView.configuration.setValue(true, forKey: "allowUniversalAccessFromFileURLs")

        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        webView.customUserAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        let refresh = UIRefreshControl()
        refresh.addTarget(context.coordinator, action: #selector(Coordinator.refresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        context.coordinator.webView = webView

        let final = WebStorage.get() ?? url

        if let link = URL(string: final) {
            print("🌍 Initial load:", link.absoluteString)
            webView.load(URLRequest(url: link))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate,
                   PHPickerViewControllerDelegate,
                   UIImagePickerControllerDelegate,
                   UINavigationControllerDelegate {

    weak var webView: WKWebView?
    var pickerCompletion: (([URL]?) -> Void)?

    private var lastRedirectedUrl: URL?
    private var retryCount = 0

    @objc func refresh(_ sender: UIRefreshControl) {
        webView?.reload()
        sender.endRefreshing()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            print("✅ Loaded:", url.absoluteString)
            WebStorage.save(url: url.absoluteString)
        }
    }
    
    func webView(_ webView: WKWebView,
                 didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {

            completionHandler(.useCredential, URLCredential(trust: trust))
            return
        }

        completionHandler(.performDefaultHandling, nil)
    }

    func webView(_ webView: WKWebView,
                 didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {

        if let url = webView.url {
            lastRedirectedUrl = url
            print("🔁 Redirect:", url.absoluteString)
        }
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {

        let nsError = error as NSError

        if nsError.code == NSURLErrorCancelled {
            return
        }

        print("❌ Provisional failed:", error.localizedDescription)
        
        if nsError.code == NSURLErrorHTTPTooManyRedirects {

            guard let last = lastRedirectedUrl else { return }

            if retryCount < 3 {
                retryCount += 1

                print("🌀 RETRY #\(retryCount):", last.absoluteString)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    webView.load(URLRequest(url: last))
                }

            } else {
                print("⛔️ fallback to Safari")

                UIApplication.shared.open(last)
            }
        }
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        print("➡️ Navigation:", url.absoluteString)

        lastRedirectedUrl = url

        if url.absoluteString == "about:blank" {
            decisionHandler(.cancel)
            return
        }

        let scheme = url.scheme ?? ""

        if scheme != "http" && scheme != "https" {

            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }

            decisionHandler(.cancel)
            return
        }

        if navigationAction.navigationType == .linkActivated {

            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {

        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }

        return nil
    }

    @available(iOS 18.4, *)
    func webView(_ webView: WKWebView,
                 runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping ([URL]?) -> Void) {

        openFilePicker(completionHandler: completionHandler)
    }

    private func openFilePicker(completionHandler: @escaping ([URL]?) -> Void) {

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let vc = scene.windows.first?.rootViewController else {
            completionHandler(nil)
            return
        }

        let picker = PHPickerViewController(configuration: {
            var config = PHPickerConfiguration()
            config.selectionLimit = 1
            config.filter = .images
            return config
        }())

        picker.delegate = self
        self.pickerCompletion = completionHandler
        vc.present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let item = results.first?.itemProvider else {
            pickerCompletion?(nil)
            return
        }

        item.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
            DispatchQueue.main.async {
                self.pickerCompletion?(url != nil ? [url!] : nil)
            }
        }
    }
}
