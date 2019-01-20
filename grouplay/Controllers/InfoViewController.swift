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

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        textField.delegate = self
        
        guard
            let sess = SessionStore.current
        else
        {
            print("Shared session object is null")
            dismiss(animated: true, completion: nil)
            return
        }
        
        canEdit = UserStore.current?.isOwner() ?? false
        
        textField.isEnabled = canEdit
        textField.text = sess.name
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return SessionStore.current?.members.members.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "member cell")!
        (cell.viewWithTag(10) as? UILabel)?.text = SessionStore.current!.members.members[indexPath.row].username
        return cell
    }
    
    func displayCollisionError() {
        if
            let name = SessionStore.current?.name
        {
            textField.text = name
        }
        
        let alert = UIAlertController(title: "Nope", message: "That names taken.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {_ in
            alert.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
    }
    
    func updateSessionName(with name: String) {
        SessionStore.current?.updateName(name)
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
