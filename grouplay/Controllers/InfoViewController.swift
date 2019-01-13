//
//  InfoViewController.swift
//  grouplay
//
//  Created by Sam Lerner on 1/9/19.
//  Copyright © 2019 Sam Lerner. All rights reserved.
//

import UIKit

class InfoViewController: UIViewController, UITableViewDataSource, UITextFieldDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var textField: UITextField!
    
    var canEdit = false
    var sess: Session!
    var members = [String]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        textField.delegate = self
        
        guard let sess = SessionStore.session else {
            dismiss(animated: true, completion: nil)
            return
        }
        
        if let uid = UserDefaults.standard.string(forKey: "uid") {
            canEdit = sess.owner == uid
        }
        textField.isEnabled = canEdit
        textField.text = sess.name
        
        for (_, member_dict) in sess.members {
            if member_dict.keys.contains("username") {
                members.append(member_dict["username"] as! String)
            }
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return members.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "member cell")!
        guard members.count > 0 else { return cell }
        (cell.viewWithTag(10) as? UILabel)?.text = members[indexPath.row]
        return cell
    }
    
    func displayCollisionError() {
        if let sess = SessionStore.session {
            textField.text = sess.name
        }
        let alert = UIAlertController(title: "Nope", message: "That names taken.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {_ in
            alert.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
    }
    
    func updateSessionName(with name: String) {
        SessionStore.session?.name = name
        FirebaseManager.shared.updateId(with: name)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let name = textField.text else { return false }
        if name == "" { return false }
        textField.resignFirstResponder()

        FirebaseManager.shared.checkForCollision(name) { collided in
            if collided {
                DispatchQueue.main.async {
                    self.displayCollisionError()
                }
            } else {
                self.updateSessionName(with: name)
            }
        }
        return true
    }

}
