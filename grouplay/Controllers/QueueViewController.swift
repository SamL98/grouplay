//
//  QueueViewController.swift
//  grouplay
//
//  Created by Sam Lerner on 1/23/18.
//  Copyright © 2018 Sam Lerner. All rights reserved.
//

import UIKit

class QueueViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var segControl: UISegmentedControl!
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
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Refresh", style: .plain, target: self, action: #selector(QueueViewController.refresh))
        
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
        return segControl.selectedSegmentIndex == 0 ? session.approved.count : session.pending.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "queue cell")!
        guard let trackCell = cell as? TrackTableViewCell else {
            return cell
        }
        
        let track = segControl.selectedSegmentIndex == 0 ? session.approved[indexPath.row] : session.pending[indexPath.row]
        trackCell.track = track
        trackCell.titleLabel.text = track.title
        trackCell.artistLabel.text = track.artist
        trackCell.imageURL = track.albumImageURL
        return trackCell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return canEdit
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        var actions = [UITableViewRowAction]()
        let remove = UITableViewRowAction(style: .destructive, title: "Remove", handler: { _, indexPath in
            let pending = self.segControl.selectedSegmentIndex == 1
            FirebaseManager.shared.dequeue(pending ? self.session.pending[indexPath.row] : self.session.approved[indexPath.row], pending: pending)
            if pending {
                self.session.pending.remove(at: indexPath.row)
            } else {
                self.session.approved.remove(at: indexPath.row)
            }
            self.tableView.reloadData()
        })
        actions.append(remove)
        if segControl.selectedSegmentIndex == 1 {
            let approve = UITableViewRowAction(style: .normal, title: "Accept", handler: { _, indexPath in
                let track = self.session.pending[indexPath.row]
                FirebaseManager.shared.enqueue(track, pending: false)
                FirebaseManager.shared.dequeue(track, pending: true)
                self.session.pending.remove(at: indexPath.row)
                self.session.approved.append(track)
                self.tableView.reloadData()
            })
            actions.append(approve)
        }
        return actions
    }

    @IBAction func toggleType(_ sender: Any) {
        tableView.reloadData()
    }
    
    @objc func refresh() {
        FirebaseManager.shared.fetchQueue(sess: session) { err in
            if err != nil {
                print(err!)
                return
            }
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
}
