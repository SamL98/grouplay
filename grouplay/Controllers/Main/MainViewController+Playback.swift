//
//  MainViewController+Playback.swift
//  grouplay
//
//  Created by Sam Lerner on 5/10/18.
//  Copyright © 2018 Sam Lerner. All rights reserved.
//

import UIKit

extension MainViewController {
    
    // Delegate method called when audio streaming has been authenticated. Just record this in UserDefaults
    func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController!) {
        print("streaming logged in")
        UserDefaults.standard.set(true, forKey: "stream-logged-in")
    }
    
    // Queue all of the tracks in the approved queue of the session. Currently not being used since I cannot get the queueSpotifyURI functionality of the Spotify SDK to work :(
    func queueApproved() {
        for track in SessionStore.session!.approved {
            print("queueing \(track.trackID)")
            SpotifyManager.shared.player.queueSpotifyURI("spotify:track:" + track.trackID, callback: nil)
        }
    }
    
    // Delegate method called when a track is being played. Dequeue from the database (if from that queue) and update the currView.
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didStartPlayingTrack trackUri: String!) {
        guard let nextUp = SessionStore.session!.approved.first(where: { "spotify:track:" + $0.trackID == trackUri }) else {
            print("could not find track in session: \(trackUri!)")
            if current != nil {
                FirebaseManager.shared.setCurrent(current, timeLeft: timeLeft, paused: paused)
            }
            return
        }
        FirebaseManager.shared.dequeue(nextUp, pending: false)
        SessionStore.session!.approved = SessionStore.session!.approved.filter({ $0.trackID != nextUp.trackID })
        
        showCurrView()
        current = nextUp
        
        timeLeft = Int(current.duration/1000)
        arcLayer.timeLimit = timeLeft
        
        paused = false
        updateCurrDisplay()
        
        FirebaseManager.shared.setCurrent(current, timeLeft: timeLeft, paused: paused)
    }
    
    // Delegate method called when a track is done playing. Append to the list of previous songs (for backtracking) and play the next song.
    // Would preferably use queueSpotifyURI but again, I cannot get that to work.
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didStopPlayingTrack trackUri: String!) {
        prev.append(current)
        guard SessionStore.session!.approved.count > 0 else {
            print("no remaining songs in queue")
            NotificationCenter.default.addObserver(self, selector: #selector(queueChanged), name: Notification.Name(rawValue: "queue-changed"), object: nil)
            paused = true
            return
        }
        let nextUp = SessionStore.session!.approved[0].trackID
        SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + nextUp, startingWith: 0, startingWithPosition: 0.0, callback: nil)
    }
    
    @objc func queueChanged() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name(rawValue: "queue-changed"), object: nil)
        guard let nextUp = SessionStore.session?.approved.first else {
            print("song went into pending")
            NotificationCenter.default.addObserver(self, selector: #selector(queueChanged), name: Notification.Name(rawValue: "queue-changed"), object: nil)
            return
        }
        SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + nextUp.trackID, startingWith: 0, startingWithPosition: 0.0, callback: nil)
    }
    
    // Pause playback if currently playing. Otherwise, unpause playback.
    @objc func togglePause() {
        guard current != nil else {
            return
        }
        if !firstPlayOccurred && paused {
            firstPlayOccurred = true
            SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + current.trackID, startingWith: 0, startingWithPosition: Double(current.duration)/1000.0 - Double(timeLeft), callback: nil)
        }
        SpotifyManager.shared.player.setIsPlaying(paused, callback: nil)
        paused = !paused
    }
    
    // Set the player to the duration of the current song. Then didStopPlayingTrack will be called and the next song will be played.
    @objc func skip() {
        guard SessionStore.session!.approved.count > 0 else {
            print("no remaining items in queue")
            return
        }
        SpotifyManager.shared.player.seek(to: TimeInterval(current.duration/1000), callback: nil)
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
        SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + prevTrack.trackID, startingWith: 0, startingWithPosition: 0.0, callback: nil)
    }
    
}
