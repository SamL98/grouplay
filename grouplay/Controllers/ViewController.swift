//
//  ViewController.swift
//  grouplay
//
//  Created by Sam Lerner on 12/7/17.
//  Copyright © 2017 Sam Lerner. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    var session: SPTSession!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if UserDefaults.standard.bool(forKey: "loggedIn") {
            SpotifyManager.shared.refreshAuthToken() {
                self.performSegue(withIdentifier: "to launch", sender: nil)
            }
        }
    }
    
    @objc func finishLogin(comp: @escaping () -> Void) {
        comp()
    }

    @IBAction func login(_ sender: UIButton) {
        SpotifyManager.shared.setAuthHandler(for: self)
        SpotifyManager.shared.login {
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "to launch", sender: nil)
            }
        }
    }
    
}

