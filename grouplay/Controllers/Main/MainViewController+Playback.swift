//
//  MainViewController+Playback.swift
//  grouplay
//
//  Created by Sam Lerner on 5/10/18.
//  Copyright © 2018 Sam Lerner. All rights reserved.
//

import UIKit

extension MainViewController {
    
    @objc func queueChanged() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name(rawValue: "queue-changed"), object: nil)
        
        guard let nextUp = SessionStore.session?.approved.first else {
            print("song went into pending")
            NotificationCenter.default.addObserver(self, selector: #selector(queueChanged), name: Notification.Name(rawValue: "queue-changed"), object: nil)
            return
        }
        
        print("QUEUE CHANGED")
        SpotifyManager.shared.appRemote.playerAPI?.play("spotify:track:"+nextUp.trackID, callback: { (result, err) in
            guard err == nil else {
                print("error playing song")
                return
            }
            self.didStartPlaying(nextUp.trackID)
        })
    }
    
    func didStartPlaying(_ trackID: String) {
        guard let nextUp = SessionStore.session!.approved.first(where: { "spotify:track:" + $0.trackID == trackID }) else {
            print("AudioStreaming:didStartPlayingTrack - Could not find track in session")
            if current == nil {
                FirebaseManager.shared.setCurrent(current)
            }
            return
        }
        
        FirebaseManager.shared.dequeue(nextUp, pending: false)
        SessionStore.session!.approved = SessionStore.session!.approved.filter({ $0.trackID != nextUp.trackID })
        
        print("Did start playing: \(nextUp.title), \(nextUp.trackID)")
        paused = false
        current = nextUp
    }
    
    // Pause playback if currently playing. Otherwise, unpause playback.
    @objc func togglePause() {
        guard current != nil else { return }
        
        if !firstPlayOccurred && paused {
            firstPlayOccurred = true

            
            paused = !paused
            return
        }
        
        if paused { SpotifyManager.shared.appRemote.playerAPI?.resume() }
        else { SpotifyManager.shared.appRemote.playerAPI?.pause(nil) }
        paused = !paused
    }
    
    // Set the player to the duration of the current song. Then didStopPlayingTrack will be called and the next song will be played.
    @objc func skip() {
        if paused { paused = false }
        
        if current != nil {
            prev.append(current)
        }
        
        var nextUp: String
        if SessionStore.session!.approved.count == 0 {
            print("Skip - No remaining songs in queue")
            
            guard isOwner else { return }
            let idx = Int(arc4random_uniform(UInt32(self.tracks.count)))
            nextUp = tracks[idx].trackID
        } else {
            nextUp = SessionStore.session!.approved[0].trackID
        }
        
        print("SKIP - ", nextUp)
        SpotifyManager.shared.appRemote.playerAPI?.play("spotify:track:"+nextUp, callback: { (result, err) in
            guard err == nil else {
                print("error playing song")
                return
            }
            self.didStartPlaying(nextUp)
        })
    }
    
    // If the previous list is nonempty, pop the last item off and play it.
    @objc func back() {
        guard let prevTrack = prev.popLast() else {
            print("no previous track")
            return
        }
        
        SessionStore.session?.approved.insert(current, at: 0)
        
        var insertBefore = Date.now()
        if SessionStore.session!.approved.count > 1 { insertBefore = SessionStore.session!.approved[1].timestamp }
        FirebaseManager.shared.insert(current, pending: false, before: insertBefore)
        
        SessionStore.session?.approved.insert(prevTrack, at: 0)
        SpotifyManager.shared.appRemote.playerAPI?.play("spotify:track:"+prevTrack.trackID, callback: { (result, err) in
            guard err == nil else {
                print("error playing song")
                return
            }
            self.didStartPlaying(prevTrack.trackID)
        })
    }
    
}
