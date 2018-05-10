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
    }
    
    
    override func doHandle(_ url: URL) {
        targetURL = url
        DispatchQueue.main.async {
            super.doHandle(url)
        }
        loadAddressURL()
    }
    
    func loadAddressURL() {
        self.webView.frame = UIScreen.main.bounds
        self.webView.backgroundColor = UIColor.purple
        self.view.bringSubview(toFront: self.webView)
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
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        print("committed")
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("finished")
    }
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("received authetication challenge")
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print(error)
    }
}
