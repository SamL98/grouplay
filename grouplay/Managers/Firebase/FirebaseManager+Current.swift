//
//  FirebaseManager+Current.swift
//  grouplay
//
//  Created by Sam Lerner on 8/27/18.
//  Copyright © 2018 Sam Lerner. All rights reserved.
//

import Foundation
import Firebase
import FirebaseDatabase

extension FirebaseManager {
    
    // Observe the realtime current track in the database. Only called if the session is not owned by the current user.
    func fetchCurrent(completion: @escaping (Track?, Int?, Bool?, NSError?) -> Void) {
        if sessRef == nil {
            print("sess ref nil")
            completion(nil, nil, nil, NSError(domain: "current-fetch", code: 4234, userInfo: nil))
            return
        }
        
        sessRef?.child("current")
            .observe(.value,
                  with: { snap in
                    guard let val = snap.value as? [String:AnyObject] else {
                        return
                    }
                    
                    guard
                        let id = val["id"] as? String,
                        let title = val["title"] as? String,
                        let artist = val["artist"] as? String,
                        let imgUrl = val["imageURL"] as? String,
                        let timeLeft = val["time_left"] as? Int,
                        let duration = val["duration"] as? Int,
                        let timestamp = val["timestamp"] as? UInt64,
                        let paused = val["paused"] as? Bool else {
                            
                            //completion(nil, nil, nil, NSError(domain: "current-fetch", code: 4234, userInfo: nil))
                            return
                    }
                    
                    if let curr = SessionStore.session?.current?.track {
                        guard curr.trackID != id else { return }
                    }
                    
                    let track = Track(title: title, artist: artist, trackID: id, imageURL: URL(string: imgUrl)!, image: nil, preview: nil, duration: duration, timestamp: timestamp)
                    
                    SessionStore.session?.current = (track, timeLeft, timestamp, !paused)
                    completion(track, timeLeft, paused,  nil)
        },
          withCancel: { err in
            print("could not fetch current (firebase): \(err)")
            completion(nil, nil, nil, NSError(domain: "current-fetch", code: 4234, userInfo: nil))
        })
    }
    
    // Set the current track in the database. Only called if the session is owned by the current user.
    func setCurrent(_ track: Track, timeLeft: Int, paused: Bool) {
        let ts = Date.now()
        
        sessRef?.child("current").setValue([
            "id": track.trackID,
            "title": track.title,
            "artist": track.artist,
            "imageURL": "\(track.albumImageURL)",
            "time_left": timeLeft,
            "duration": track.duration,
            "timestamp": ts,
            "paused": paused
            ])
        
        SessionStore.session?.current = (track, timeLeft, ts, !paused)
    }
    
    func pause() {
        sessRef?.child("current").updateChildValues(["paused": true as Any])
    }
    
}
