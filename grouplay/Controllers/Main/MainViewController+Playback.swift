//
//  MainViewController+Playback.swift
//  grouplay
//
//  Created by Sam Lerner on 5/10/18.
//  Copyright © 2018 Sam Lerner. All rights reserved.
//

import UIKit

extension MainViewController {
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didChangePlaybackStatus isPlaying: Bool) {
        /*if isPlaying {
            SpotifyManager.shared.reactivateSession()
        } else {
            SpotifyManager.shared.deactivateSession()
        }*/
    }
    
    // Delegate method called when audio streaming has been authenticated. Just record this in UserDefaults
    func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController!) {
        UserDefaults.standard.set(true, forKey: "stream-logged-in")
    }
    
    // Delegate method called when a track is being played. Dequeue from the database (if from that queue) and update the currView.
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didStartPlayingTrack trackUri: String!) {
        guard let nextUp = SessionStore.session!.queue.first(where: { "spotify:track:" + $0.trackID == trackUri }) else {
            print("could not find track in session")
            if current != nil {
                FirebaseManager.shared.setCurrent(current)
            }
            return
        }
        
        FirebaseManager.shared.dequeue(nextUp, pending: false)
        SessionStore.session!.queue = SessionStore.session!.queue.filter({ $0.trackID != nextUp.trackID })
        
        paused = false
        current = nextUp
    }
    
    // Delegate method called when a track is done playing. Append to the list of previous songs (for backtracking) and play the next song.
    // Would preferably use queueSpotifyURI but again, I cannot get that to work.
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didStopPlayingTrack trackUri: String!) {
        prev.append(current)
        
        guard SessionStore.session!.queue.count > 0 else {
            print("no remaining songs in queue")
            
            if isOwner {
                let idx = Int(arc4random_uniform(UInt32(self.tracks.count)))
                let indexPath = IndexPath(row: idx, section: 0)
                self.tableView(self.tableView, didSelectRowAt: indexPath)
            }
            return
        }
        
        let nextUp = SessionStore.session!.queue[0].trackID
        SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + nextUp, startingWith: 0, startingWithPosition: 0.0, callback: nil)
    }
    
    @objc func queueChanged() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name(rawValue: "queue-changed"), object: nil)
        
        guard let nextUp = SessionStore.session?.queue.first else {
            print("song went into pending")
            NotificationCenter.default.addObserver(self, selector: #selector(queueChanged), name: Notification.Name(rawValue: "queue-changed"), object: nil)
            return
        }
        
        SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + nextUp.trackID, startingWith: 0, startingWithPosition: 0.0, callback: nil)
    }
    
    // Pause playback if currently playing. Otherwise, unpause playback.
    @objc func togglePause() {
        guard current != nil else { return }
        
        if !firstPlayOccurred && paused {
            firstPlayOccurred = true
            SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + current.trackID, startingWith: 0, startingWithPosition: Double(current.duration)/1000.0 - Double(timeLeft), callback: nil)
            
            paused = !paused
            return
        }
        
        SpotifyManager.shared.player.setIsPlaying(paused, callback: nil)
        paused = !paused
        FirebaseManager.shared.setPaused(paused: paused)
    }
    
    // Set the player to the duration of the current song. Then didStopPlayingTrack will be called and the next song will be played.
    @objc func skip() {
        if paused {
            SpotifyManager.shared.player.setIsPlaying(true, callback: nil)
            paused = false
            FirebaseManager.shared.setPaused(paused: paused)
        }
        
        if !firstPlayOccurred && current != nil {
            SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + current.trackID, startingWith: 0, startingWithPosition: 0.0, callback: { _ in
                
                SpotifyManager.shared.player.seek(to: TimeInterval(self.current.duration/1000), callback: nil)
            })
            return
        }
        
        SpotifyManager.shared.player.seek(to: TimeInterval(self.current.duration/1000), callback: nil)
    }
    
    // If the previous list is nonempty, pop the last item off and play it.
    @objc func back() {
        guard let prevTrack = prev.popLast() else {
            print("no previous track")
            return
        }
        
        SessionStore.session?.queue.insert(current, at: 0)
        
        var insertBefore = Date.now()
        if SessionStore.session!.queue.count > 1 { insertBefore = SessionStore.session!.queue[1].timestamp }
        FirebaseManager.shared.insert(current, pending: false, before: insertBefore)
        
        SessionStore.session?.queue.insert(prevTrack, at: 0)
        SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + prevTrack.trackID, startingWith: 0, startingWithPosition: 0.0, callback: nil)
    }
    
    /*func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didChangePlaybackStatus isPlaying: Bool) {
        if isPlaying { SpotifyManager.shared.deactivateSession() }
        else { SpotifyManager.shared.reactivateSession() }
    }*/
    
}
