//
//  MainViewController+TableView.swift
//  grouplay
//
//  Created by Sam Lerner on 5/10/18.
//  Copyright © 2018 Sam Lerner. All rights reserved.
//

import UIKit

extension MainViewController {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tracks.count
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "trackCell")!
        guard let trackCell = cell as? TrackTableViewCell else {
            return cell
        }
        
        let track = tracks[indexPath.row]
        trackCell.titleLabel.text = track.title
        trackCell.artistLabel.text = track.artist
        
        trackCell.track = track
        trackCell.imageURL = track.albumImageURL
        
        return trackCell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isOwner {
            SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + tracks[indexPath.row].trackID, startingWith: 0, startingWithPosition: 0.0, callback: {_ in
                self.paused = false
                self.current = self.tracks[indexPath.row]
                self.showCurrView()
                self.updateCurrDisplay()
                //self.queueApproved()
            })
        }
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let action = UITableViewRowAction(style: .normal, title: "Enqueue", handler: { _, indexPath in
            FirebaseManager.shared.enqueue(self.tracks[indexPath.row], pending: !self.isOwner)
            if self.isOwner {
                //SpotifyManager.shared.player.queueSpotifyURI("spotify:track:" + self.tracks[indexPath.row].trackID, callback: nil)
                SessionStore.session!.approved.append(self.tracks[indexPath.row])
            }
        })
        return [action]
    }
    
}
