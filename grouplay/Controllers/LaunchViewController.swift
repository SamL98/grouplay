//
//  LaunchViewController.swift
//  grouplay
//
//  Created by Sam Lerner on 12/9/17.
//  Copyright © 2017 Sam Lerner. All rights reserved.
//

import UIKit

class LaunchViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    var isOwner = false
    
    var recents = [String]() {
        didSet {
            tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        recents = UserDefaults.standard.array(forKey: "recents") as? [String] ?? []
    }
    
    func displayError(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {_ in alert.dismiss(animated: true, completion: nil) }))
        present(alert, animated: true, completion: nil)
    }
    
    func displayCreateError() {
        displayError(title: "Oops!", message: "An error occurred creating your session.")
    }
    
    func displayJoinError() {
        displayError(title: "Oops!", message: "An error occurred joining this session.")
    }
    
    func displayJoinPrompt(completion: @escaping (String) -> Void) {
        let alert = UIAlertController(title: "Join", message: "Enter the code of the session to join", preferredStyle: .alert)
        alert.addTextField(configurationHandler: nil)
        alert.addAction(UIAlertAction(title: "Go", style: .default, handler: { _ in
            guard let textfield = alert.textFields?.first else {
                completion("")
                return
            }
            guard let text = textfield.text else {
                completion("")
                return
            }
            completion(text)
        }))
        present(alert, animated: true, completion: nil)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recents.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "recent cell")!
        (cell.viewWithTag(10) as! UILabel).text = recents[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        join(code: recents[indexPath.row])
    }

    @IBAction func joinSession(_ sender: UIButton) {
        displayJoinPrompt { code in
            self.join(code: code)
        }
    }
    
    func join(code: String) {
        FirebaseManager.shared.joinSession(code: code, completion: { (sess, errStr) in
            guard errStr == nil else {
                print(errStr!)
                return
            }
            SessionStore.session = sess
            if !self.recents.contains(code) {
                self.recents.append(code)
                UserDefaults.standard.set(self.recents, forKey: "recents")
            }
            DispatchQueue.main.async {
                if sess != nil && sess!.owner == UserDefaults.standard.string(forKey: "uid")! {
                    self.isOwner = true
                }
                self.performSegue(withIdentifier: "to search", sender: nil)
            }
        })
    }
    
    @IBAction func createSession(_ sender: UIButton) {
        FirebaseManager.shared.createSession { (code, errStr) in
            guard errStr == nil else {
                print(errStr!)
                DispatchQueue.main.async {
                    self.displayCreateError()
                }
                return
            }
            guard code != nil else {
                print("code is nil from create")
                DispatchQueue.main.async {
                    self.displayCreateError()
                }
                return
            }
            guard let uid = UserDefaults.standard.string(forKey: "uid") else {
                DispatchQueue.main.async {
                    self.displayCreateError()
                }
                return
            }
            SessionStore.session = Session(owner: uid, members: [], approved: [], pending: [])
            self.recents.append(code!)
            UserDefaults.standard.set(self.recents, forKey: "recents")
            DispatchQueue.main.async {
                self.isOwner = true
                self.performSegue(withIdentifier: "to search", sender: nil)
            }
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "to" {
            return SessionStore.session != nil
        }
        return true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let mainVC = (segue.destination as? UINavigationController)?.viewControllers[0] as? MainViewController {
            mainVC.isOwner = self.isOwner
        }
    }
    
}
