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
    func fetchCurrent(isOwner: Bool, completion: @escaping (Track?, Int?, Bool?, NSError?) -> Void) {
        if sessRef == nil {
            print("sess ref nil")
            completion(nil, nil, nil, NSError(domain: "current-fetch", code: 4234, userInfo: nil))
            return
        }
        
        var comp: (DataSnapshot) -> Void = { snap in
            guard let val = snap.value as? [String:AnyObject] else {
                return
            }
            
            guard
                let id = val["id"] as? String,
                let title = val["title"] as? String,
                let artist = val["artist"] as? String,
                let imgUrl = val["imageURL"] as? String,
                let duration = val["duration"] as? Int else {
                    
                    //completion(nil, nil, nil, NSError(domain: "current-fetch", code: 4234, userInfo: nil))
                    return
            }
            
            if let curr = SessionStore.session?.current?.track {
                guard curr.trackID != id else { return }
            }
            
            let track = Track(title: title,
                              artist: artist,
                              trackID: id,
                              imageURL: URL(string: imgUrl)!,
                              image: nil,
                              preview: nil,
                              duration: duration,
                              timestamp: timestamp)
            
            SessionStore.session?.current = (track, timeLeft, timestamp, !paused)
            completion(track, timeLeft, paused,  nil)
        }
        
        if isOwner {
            sessRef?.child("current").observeSingleEvent(of: .value,
                                                        with: comp,
                                                        withCancel: { err in
                                                            print("could not fetch current (firebase): \(err)")
                                                            completion(nil, nil, nil, NSError(domain: "current-fetch", code: 4234, userInfo: nil))
            })
        } else {
            sessRef?.child("current").observe(.value,
                                                with: comp,
                                                withCancel: { err in
                                                    print("could not fetch current (firebase): \(err)")
                                                    completion(nil, nil, nil, NSError(domain: "current-fetch", code: 4324, userInfo: nil))
            })
        }
    }
    
    // Set the current track in the database. Only called if the session is owned by the current user.
    func setCurrent(_ track: Track, timeLeft: Int, paused: Bool) {
        sessRef?.child("current").setValue([
            "id": track.trackID,
            "title": track.title,
            "artist": track.artist,
            "imageURL": "\(track.albumImageURL)",
            "duration": track.duration
            ])
    }
    
    func pause() {
        sessRef?.child("paused").setValue(true)
    }
    
    func play() {
        sessRef?.child("paused").setValue(false)
    }
    
}
