//
//  QueueViewController.swift
//  grouplay
//
//  Created by Sam Lerner on 1/23/18.
//  Copyright © 2018 Sam Lerner. All rights reserved.
//

import UIKit

class QueueViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    var session: Session!
    var canEdit = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard SessionStore.session != nil else {
            dismiss(animated: true, completion: nil)
            return
        }
        session = SessionStore.session!
        
        if let uid = UserDefaults.standard.string(forKey: "uid") {
            canEdit = session.owner == uid
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(queueChanged), name: Notification.Name(rawValue: "queue-changed"), object: nil)
    }
    
    @objc func queueChanged() {
        print("queue change")
        tableView.reloadData()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return session.queue.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "queue cell")!
        guard let trackCell = cell as? QueueTableViewCell else {
            return cell
        }
        
        let track = session.queue[indexPath.row]
        trackCell.track = track
        trackCell.titleLabel.text = track.title
        trackCell.artistLabel.text = track.artist
        trackCell.imageURL = track.albumImageURL
        trackCell.queuerLabel.text = track.queuer == "username" ? "" : "Queued by: \(track.queuer)"
        return trackCell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return canEdit
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        var actions = [UITableViewRowAction]()
        let remove = UITableViewRowAction(style: .destructive, title: "Remove", handler: { _, indexPath in
            FirebaseManager.shared.dequeue(self.session.queue[indexPath.row], pending: false)
            self.session.queue.remove(at: indexPath.row)
            self.tableView.reloadData()
        })
        
        actions.append(remove)
        return actions
    }

    @IBAction func toggleType(_ sender: Any) {
        tableView.reloadData()
    }
}
