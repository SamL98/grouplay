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
    var shdSegue = false
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if UserDefaults.standard.bool(forKey: "loggedIn") {
            SpotifyManager.shared.sessManager.renewSession()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if shdSegue {
            performSegue(withIdentifier: "to launch", sender: nil)
        }
    }
    
    @objc func finishLogin() {
        print("finish login")
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("login"), object: nil)
        DispatchQueue.main.async {
            self.shdSegue = true
        }
    }

    @IBAction func login(_ sender: UIButton) {
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.finishLogin), name: NSNotification.Name("login"), object: nil)
        SpotifyManager.shared.login()
    }
    
}

