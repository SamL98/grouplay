//
//  MainViewController+Playback.swift
//  grouplay
//
//  Created by Sam Lerner on 5/10/18.
//  Copyright © 2018 Sam Lerner. All rights reserved.
//

import UIKit
import MediaPlayer

extension MainViewController {
    
    func setupMPCommandCenter() {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        
        MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = true
        MPRemoteCommandCenter.shared().nextTrackCommand.addTarget(self, action: #selector(skip))
        MPRemoteCommandCenter.shared().togglePlayPauseCommand.isEnabled = true
        MPRemoteCommandCenter.shared().togglePlayPauseCommand.addTarget(self, action: #selector(togglePause))
        MPRemoteCommandCenter.shared().previousTrackCommand.isEnabled = true
        MPRemoteCommandCenter.shared().previousTrackCommand.addTarget(self, action: #selector(back))
        UserDefaults.standard.set(true, forKey: "controls-started")
    }
    
    func updateLockScreen(with img: UIImage, elapsedTime: Int) {
        if !firstPlayOccurred { return }
        guard let current = SessionStore.current?.current else { return }
        
        if !UserDefaults.standard.bool(forKey: "controls-started") {
            setupMPCommandCenter()
        }
        
        nowPlayingInfo = [String:Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = current.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = current.artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = albumName
        nowPlayingInfo[MPMediaItemPropertyAlbumArtist] = albumArtist
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = playbackRate
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Double(current.duration)
        nowPlayingInfo[MPMediaItemPropertyMediaType] = MPMediaType.music
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(elapsedTime)
        nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size, requestHandler: { (size) -> UIImage in
            return self.currImageView.image!
        })
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // Delegate method called when audio streaming has been authenticated. Just record this in UserDefaults
    func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController!) {
        UserDefaults.standard.set(true, forKey: "stream-logged-in")
    }
    
    // Delegate method called when a track is being played. Dequeue from the database (if from that queue) and update the currView.
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didStartPlayingTrack trackUri: String!) {
        guard 
            let nextUp = SessionStore.current!.queue.tracks.first(where: { "spotify:track:" + $0.trackID == trackUri })
        else 
        {
            print("Playing track not in the queue")
            return
        }
        
        paused = false
        SessionStore.current?.setCurrent(nextUp)
    }
    
    // Delegate method called when a track is done playing. Append to the list of previous songs (for backtracking) and play the next song.
    // Would preferably use queueSpotifyURI but again, I cannot get that to work.
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didStopPlayingTrack trackUri: String!) {
        guard
            let session = SessionStore.current,
            let current = session.current
        else
        {
            return
        }
        
        prev.append(current)
        
        if session.queue.tracks.count == 0 {
            print("No remaining songs in queue")
            let idx = Int(arc4random_uniform(UInt32(self.tracks.count)))
            let indexPath = IndexPath(row: idx, section: 0)
            self.tableView(self.tableView, didSelectRowAt: indexPath)
            return
        }
        
        let nextUp = session.queue.tracks[0].trackID
        SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + nextUp, 
                                                    startingWith: 0, 
                                                    startingWithPosition: 0.0, 
                                                    callback: nil)
    }
    
    // Pause playback if currently playing. Otherwise, unpause playback.
    @objc func togglePause() {
        if 
            let current = SessionStore.current?.current,
            !firstPlayOccurred && paused 
        {
            firstPlayOccurred = true
            SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + current.trackID,
                                                        startingWith: 0,
                                                        //startingWithPosition: Double(current.duration)/1000.0 - Double(timeLeft),
                                                        startingWithPosition: 0.0,
                                                        callback: nil)
            
            paused = false
            return
        }
        
        SpotifyManager.shared.player.setIsPlaying(paused, callback: nil)
        paused = !paused
    }
    
    // Set the player to the duration of the current song. Then didStopPlayingTrack will be called and the next song will be played.
    @objc func skip() {
        guard 
            let current = SessionStore.current?.current
        else
        {
            print("Cannot skip; no current track")
            return
        }
        
        // If we haven't even played yet, we play the current song then seek to the end
        // Otherwise, the unpause if paused and then seek to the end
        if !firstPlayOccurred {
            SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + current.trackID, 
                                                        startingWith: 0, 
                                                        startingWithPosition: 0.0, 
                                                        callback: { _ in
                SpotifyManager.shared.player.seek(to: TimeInterval(current.duration/1000), callback: nil)
            })
            paused = false
        } else {
            if paused {
                SpotifyManager.shared.player.setIsPlaying(true, callback: nil)
                paused = false
            }
            SpotifyManager.shared.player.seek(to: TimeInterval(current.duration/1000), callback: nil)
        }
    }
    
    // If the previous list is nonempty, pop the last item off and play it.
    @objc func back() {
        guard 
            let prevTrack = prev.popLast() 
        else 
        {
            print("No previous track")
            return
        }

        guard
            let current = SessionStore.current?.current
        else
        {
            print("No current track")
            return
        }

        SessionStore.current?.prepend(current)
        SessionStore.current?.setCurrent(prevTrack)

        SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + prevTrack.trackID, 
                                                    startingWith: 0, 
                                                    startingWithPosition: 0.0, 
                                                    callback: nil)
    }
    
}
