//
//  ViewController.swift
//  grouplay
//
//  Created by Sam Lerner on 12/7/17.
//  Copyright © 2017 Sam Lerner. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if UserDefaults.standard.bool(forKey: "loggedIn") {
            SpotifyManager.shared.refreshAuthToken() {
                self.performSegue(withIdentifier: "to launch", sender: nil)
            }
        }
    }

    @IBAction func login(_ sender: UIButton) {
        SpotifyManager.shared.login {
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "to launch", sender: nil)
            }
        }
    }
    
}

