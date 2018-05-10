//
//  ViewController.swift
//  grouplay
//
//  Created by Sam Lerner on 12/7/17.
//  Copyright © 2017 Sam Lerner. All rights reserved.
//

import UIKit
import KeychainSwift

class ViewController: UIViewController {
    
    var session: SPTSession!

    override func viewDidLoad() {
        super.viewDidLoad()
        if UserDefaults.standard.bool(forKey: "loggedIn") {
            SpotifyManager.shared.refreshAuthToken() {
                self.performSegue(withIdentifier: "to launch", sender: nil)
            }
        }
        /*if UserDefaults.standard.bool(forKey: "spotify-logged-in") {
            let keychain = KeychainSwift()
            guard let username = keychain.get("username"),
                let accessToken = keychain.get("accessToken"),
                let refreshToken = keychain.get("refreshToken"),
                let expireDate = keychain.get("expireDate") else {
                    print("missing data from keychain")
                    return
            }
            let formatter = DateFormatter()
            formatter.dateFormat = ""
            let sess = SPTSession(userName: username, accessToken: accessToken, encryptedRefreshToken: refreshToken, expirationDate: formatter.date(from: expireDate)!)
            SpotifyManager.shared.auth.renewSession(sess, callback: {(err, sessionOpt) in
                guard err == nil else {
                    print("error renewing session: \(err!)")
                    return
                }
                guard let session = sessionOpt else {
                    print("session is nil from renew")
                    return
                }
                SpotifyManager.shared.session = session
                SpotifyManager.shared.oauth.client.credential.oauthToken = sess!.accessToken
                self.goToMain()
            })
        }*/
    }

    @IBAction func login(_ sender: UIButton) {
        SpotifyManager.shared.login {
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "to launch", sender: nil)
            }
        }
        /*var loginUrl = SPTAuth.defaultInstance().spotifyAppAuthenticationURL()!
        if SPTAuth.supportsApplicationAuthentication() {
            UIApplication.shared.open(loginUrl, options: [:], completionHandler: { completed in
                if completed {
                    NotificationCenter.default.addObserver(self, selector: #selector(ViewController.goToMain), name: Notification.Name(rawValue: "login-complete"), object: nil)
                }
            })
        } else {
            loginUrl = SPTAuth.defaultInstance().spotifyWebAuthenticationURL()!
            UIApplication.shared.open(loginUrl, options: [:], completionHandler: { completed in
                if completed {
                    NotificationCenter.default.addObserver(self, selector: #selector(ViewController.goToMain), name: Notification.Name(rawValue: "login-complete"), object: nil)
                }
            })
        }*/
    }
    
//    @objc func goToMain() {
//        NotificationCenter.default.removeObserver(self, name: Notification.Name(rawValue: "login-complete"), object: nil)
//        performSegue(withIdentifier: "to launch", sender: nil)
//    }
    
}

