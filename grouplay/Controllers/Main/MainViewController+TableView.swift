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
        
        guard indexPath.row < tracks.count else {
            return cell
        }
        
        let track = tracks[indexPath.row]
        trackCell.titleLabel.text = track.title
        trackCell.artistLabel.text = track.artist
        
        trackCell.track = track
        trackCell.imageURL = track.albumImageURL
        
        trackCell.isOwner = isOwner
        trackCell.queued = SessionStore.session?.approved.contains(where: { $0.trackID == track.trackID }) ?? false
        
        return trackCell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard isOwner else { return }
        
        SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + tracks[indexPath.row].trackID, startingWith: 0, startingWithPosition: 0.0, callback: {_ in
            self.firstPlayOccurred = true
            self.paused = false
            self.current = self.tracks[indexPath.row]
        })
    }
    
}
