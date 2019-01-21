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
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    var isOwner = false
    var name: String?
    
    var recents = [String:String]()
    var recentNames = [String]()
    var recentCodes = [String]()

    override func viewDidLoad() {
        super.viewDidLoad()

        recents = UserDefaults.standard.dictionary(forKey: "recents") as? [String:String] ?? [:]
        for (code, name) in recents {
            recentCodes.append(code)
            recentNames.append(name)
        }
        tableView.reloadData()

        guard
            let uid = UserDefaults.standard.string(forKey: "uid"),
            let username = UserDefaults.standard.string(forKey: "username")
        else
        {
            print("No uid in UserDefaults")
            return
        }

        let hasPremium = UserDefaults.standard.bool(forKey: "hasPremium")
        let currentUser = Member(uid: uid, username: username, hasPremium: hasPremium)
        UserStore.current = currentUser
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if name != nil { join(name: name!) }
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
        let alert = UIAlertController(title: "Join", message: "Enter the name of the session to join", preferredStyle: .alert)
        alert.addTextField(configurationHandler: nil)
        alert.addAction(UIAlertAction(title: "Go", style: .default, handler: { _ in
            guard let textfield = alert.textFields?.first else {
                alert.dismiss(animated: true, completion: nil)
                return
            }
            guard let text = textfield.text else {
                alert.dismiss(animated: true, completion: nil)
                return
            }
            guard text.count > 0 else {
                alert.dismiss(animated: true, completion: nil)
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
        (cell.viewWithTag(10) as! UILabel).text = recentNames[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        name = recentNames[indexPath.row]
        join(code: recentCodes[indexPath.row])
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    @IBAction func scanQR(_ sender: UIButton) {
        performSegue(withIdentifier: "to scan QR", sender: nil)
    }

    @IBAction func joinSession(_ sender: UIButton) {
        displayJoinPrompt { name in
            self.join(name: name)
        }
    }
    
    func join(code: String) {
        FirebaseManager.shared.joinSession(code: code, completion: { _, errStr in
            if let error = errStr
            {
                print(error)
                return
            }
            
            guard
                let sess = SessionStore.current
            else
            {
                return
            }
            
            self.recentNames[self.recentCodes.firstIndex(where: { $0 == code })!] = sess.name
            self.recents[code] = sess.name
            UserDefaults.standard.set(self.recents, forKey: "recents")
            self.tableView.reloadData()
            
            UserDefaults.standard.set(self.name, forKey: "currName")
            
            DispatchQueue.main.async {
                self.isOwner = UserStore.current?.isOwner() ?? false
                self.performSegue(withIdentifier: "to search", sender: nil)
            }
        })
    }
    
    func join(name: String) {
        FirebaseManager.shared.joinSession(name: name, completion: { code, errStr in
            if let error = errStr
            {
                print(error)
                return
            }
            
            if code == nil
            {
                print("Code is nil from session join")
                return
            }
            
            if !self.recentNames.contains(name) {
                self.addToRecents(code: code!, name: name)
            }
            
            UserDefaults.standard.set(self.name, forKey: "currName")
            
            DispatchQueue.main.async {
                self.isOwner = UserStore.current?.isOwner() ?? false
                self.performSegue(withIdentifier: "to search", sender: nil)
            }
        })
    }
    
    @IBAction func createSession(_ sender: UIButton) {
        FirebaseManager.shared.createSession { (code, errStr) in
            guard 
                errStr == nil 
            else 
            {
                print(errStr!)
                DispatchQueue.main.async { self.displayCreateError() }
                return
            }

            if code == nil {
                print("Code is null from create")
                DispatchQueue.main.async { self.displayCreateError() }
                return
            }

            UserDefaults.standard.set(code!, forKey: "currName")
            self.addToRecents(code: code!, name: code!)
            
            DispatchQueue.main.async {
                self.isOwner = true
                self.performSegue(withIdentifier: "to search", sender: nil)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        var actions = [UITableViewRowAction]()
        let remove = UITableViewRowAction(style: .destructive, title: "Remove", handler: { _, indexPath in
            _ = self.recents.removeValue(forKey: self.recentNames[indexPath.row])
            self.recentNames.remove(at: indexPath.row)
            self.recentCodes.remove(at: indexPath.row)
            self.tableView.reloadData()
            UserDefaults.standard.set(self.recents, forKey: "recents")
        })
        actions.append(remove)
        return actions
    }
    
    @IBAction func deleteAll(sender: UIButton) {
        UserDefaults.standard.set([:], forKey: "recents")
        self.recentNames = []
        self.recentCodes = []
        self.recents = [:]
        tableView.reloadData()
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        print("perform segue")
        print(identifier)
        if identifier == "to" {
            return SessionStore.current != nil
        }
        return true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let mainVC = (segue.destination as? UINavigationController)?.viewControllers[0] as? MainViewController {
            mainVC.isOwner = self.isOwner
        }
    }
    
    func addToRecents(code: String, name: String) {
        recents[code] = name
        UserDefaults.standard.set(recentNames, forKey: "recents")
        
        recentNames.append(name)
        recentCodes.append(code)
        
        tableView.reloadData()
    }
    
}
