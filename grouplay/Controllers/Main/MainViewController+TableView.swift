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
        
        AlbumArtCache.shared.loadImage(for: track) { img in
            DispatchQueue.main.async {
                trackCell.iconView.image = img
            }
        }
        
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
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard
            let sess = SessionStore.current,
            let me = UserStore.current
        else
        {
            return nil
        }
        
        var style: UITableViewRowAction.Style
        var title: String
        var handler: (UITableViewRowAction, IndexPath) -> Void
        
        if sess.queue.tracks.contains(where: { $0.queuer == me.username && $0.trackID == tracks[indexPath.row].trackID })
        {
            style = .destructive
            title = "Remove"
            handler = { (_, path) in
                guard
                    let qt = SessionStore.current?.queue.tracks.first(where: { $0.queuer == me.username && $0.trackID == self.tracks[path.row].trackID })
                else
                {
                    print("Could not get queued track from added array")
                    return
                }
                SessionStore.current?.removeTrack(qt)
            }
        }
        else
        {
            style = .normal
            title = "Add"
            handler = { (_, path) in
                SessionStore.current?.addTrack(self.tracks[path.row])
            }
        }
        
        return [UITableViewRowAction(style: style, title: title, handler: handler)]
    }
    
}
