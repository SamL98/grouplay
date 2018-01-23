import UIKit
import WebKit
import OAuthSwift

class WebView: OAuthWebViewController {
    
    typealias WebView = WKWebView
    
    var targetURL : URL?
    let webView : WebView = WKWebView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.webView.frame = UIScreen.main.bounds
        self.webView.navigationDelegate = self
        self.view.addSubview(self.webView)
        loadAddressURL()
    }
    
    
    override func doHandle(_ url: URL) {
        targetURL = url
        DispatchQueue.main.async {
            super.doHandle(url)
        }
        loadAddressURL()
    }
    
    func loadAddressURL() {
        guard let url = targetURL else {
            print("target url is nil")
            return
        }
        let req = URLRequest(url: url)
        self.webView.load(req)
    }
    
}

extension WebView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, (url.scheme == "grouplay-callback") {
            self.dismissWebViewController()
        }
        decisionHandler(WKNavigationActionPolicy(rawValue: 0)!)
    }
}
