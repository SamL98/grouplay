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

    var canEdit = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard 
            let session = SessionStore.current
        else 
        {
            print("Current session is null")
            dismiss(animated: true, completion: nil)
            return
        }
        
        canEdit = (UserStore.current?.uid ?? "") == session.owner

        observeDatabase()
    }

    func observeDatabase() {
        NotificationCenter.default.addObserver(self, 
                                               selector: #selector(queueChanged), 
                                               name: Notification.Name("queue-changed"), 
                                               object: nil)
    }
    
    @objc func queueChanged() {
        tableView.reloadData()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return SessionStore.current!.queue.tracks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "queue cell")!

        guard let trackCell = cell as? QueueTableViewCell else {
            return cell
        }
        
        let track = SessionStore.current!.queue.tracks[indexPath.row]
        
        trackCell.track = SpotifyTrack.spotifyTrackFrom(track)
        trackCell.titleLabel.text = track.title
        trackCell.artistLabel.text = track.artist
        trackCell.imageURL = track.albumImageURL
        trackCell.queuerLabel.text = "Queued by: \(track.queuer)"

        return trackCell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return canEdit
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        var actions = [UITableViewRowAction]()
        let remove = UITableViewRowAction(style: .destructive, title: "Remove", handler: { _, indexPath in
            guard
                let track = SessionStore.current?.queue.tracks[indexPath.row]
            else
            {
                print("No corresponding track to remove")
                return
            }
            SessionStore.current?.removeTrack(track)
            self.tableView.reloadData()
        })
        
        actions.append(remove)
        return actions
    }
}
