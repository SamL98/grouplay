//
//  MainViewController+Playback.swift
//  grouplay
//
//  Created by Sam Lerner on 5/10/18.
//  Copyright © 2018 Sam Lerner. All rights reserved.
//

import UIKit

extension MainViewController {
    
    func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController!) {
        print("streaming logged in")
        UserDefaults.standard.set(true, forKey: "stream-logged-in")
    }
    
    func queueApproved() {
        for track in SessionStore.session!.approved {
            print("queueing \(track.trackID)")
            SpotifyManager.shared.player.queueSpotifyURI("spotify:track:" + track.trackID, callback: nil)
        }
    }
    
    func audioStreamingDidPopQueue(_ audioStreaming: SPTAudioStreamingController!) {
        print("queue popped")
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didStartPlayingTrack trackUri: String!) {
        guard let nextUp = SessionStore.session!.approved.first(where: { "spotify:track:" + $0.trackID == trackUri }) else {
            print("could not find track in session: \(trackUri!)")
            if current != nil {
                FirebaseManager.shared.setCurrent(current, timeLeft: timeLeft)
            }
            return
        }
        FirebaseManager.shared.dequeue(nextUp, pending: false)
        SessionStore.session!.approved = SessionStore.session!.approved.filter({ $0.trackID != nextUp.trackID })
        
        showCurrView()
        current = nextUp
        timeLeft = Int(current.duration/1000)
        updateCurrDisplay()
        
        FirebaseManager.shared.setCurrent(current, timeLeft: timeLeft)
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didStopPlayingTrack trackUri: String!) {
        prev.append(current)
        let nextUp = SessionStore.session!.approved[0].trackID
        SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + nextUp, startingWith: 0, startingWithPosition: 0.0, callback: nil)
    }
    
    @objc func togglePause() {
        //SpotifyManager.shared.togglePause()
        guard current != nil else {
            return
        }
        if !firstPlayOccurred && paused {
            firstPlayOccurred = true
            SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + current!.trackID, startingWith: 0, startingWithPosition: 0.0, callback: nil)
        }
        SpotifyManager.shared.player.setIsPlaying(paused, callback: nil)
        paused = !paused
    }
    
    @objc func skip() {
        SpotifyManager.shared.player.seek(to: TimeInterval(current.duration/1000), callback: nil)
    }
    
    @objc func back() {
        guard let prevTrack = prev.last else {
            print("no previous track")
            return
        }
        prev.remove(at: prev.count-1)
        SessionStore.session?.approved.insert(prevTrack, at: 0)
        SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + prevTrack.trackID, startingWith: 0, startingWithPosition: 0.0, callback: nil)
    }
    
}
