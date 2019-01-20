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
        
        if scrolling {
            trackCell.dontDownload = true
        }
        trackCell.imageURL = track.albumImageURL
        
        trackCell.isOwner = isOwner
        trackCell.queued = SessionStore.current?.isQueued(track) ?? false
        
        return trackCell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard isOwner else { return }

        SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + tracks[indexPath.row].trackID, 
                                                    startingWith: 0, 
                                                    startingWithPosition: 0.0, callback: {_ in
            guard
                let queuedTrack = QueuedTrack.queuedTrackFrom(self.tracks[indexPath.row])
            else
            {
                print("Could not create queued track from Spotify track: \(self.tracks[indexPath.row].trackID)")
                return
            }
                                                        
            self.firstPlayOccurred = true
            self.paused = false
                                                        
            SessionStore.current?.setCurrent(queuedTrack)
            self.updateCurrentUI()
        })
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let trackCell = cell as? TrackTableViewCell else { return }
        if let downloadTask = trackCell.imageDownloadTask {
            downloadTask.suspend()
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrolling = true
    }
    
    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        scrolling = false
        DispatchQueue.global(qos: .userInitiated).async {
            NotificationCenter.default.post(name: Notification.Name("stopped-scrolling"), object: nil)
        }
    }
    
}
