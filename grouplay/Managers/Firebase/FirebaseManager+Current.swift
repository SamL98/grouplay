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
    func fetchCurrent(isOwner: Bool, completion: @escaping (Track?, NSError?) -> Void) {
        if sessRef == nil {
            print("sess ref nil")
            completion(nil, NSError(domain: "current-fetch", code: 4234, userInfo: nil))
            return
        }
        
        let comp: (DataSnapshot) -> Void = { snap in
            guard let val = snap.value as? [String:AnyObject] else {
                return
            }
            
            guard
                let id = val["id"] as? String,
                let title = val["title"] as? String,
                let artist = val["artist"] as? String,
                let imgUrl = val["imageURL"] as? String,
                let duration = val["duration"] as? Int,
                let timestamp = val["timestamp"] as? UInt64 else {
                    
                    completion(nil, NSError(domain: "current-fetch", code: 4234, userInfo: nil))
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
        
            completion(track,  nil)
        }
        
        if isOwner {
            sessRef?.child("current").observeSingleEvent(of: .value,
                                                        with: comp,
                                                        withCancel: { err in
                                                            print("could not fetch current (firebase): \(err)")
                                                            completion(nil, NSError(domain: "current-fetch", code: 4234, userInfo: nil))
            })
        } else {
            sessRef?.child("current").observe(.value,
                                                with: comp,
                                                withCancel: { err in
                                                    print("could not fetch current (firebase): \(err)")
                                                    completion(nil, NSError(domain: "current-fetch", code: 4324, userInfo: nil))
            })
        }
    }
    
    // Set the current track in the database. Only called if the session is owned by the current user.
    func setCurrent(_ track: Track) {
        print(track.title)
        sessRef?.child("current").setValue([
            "id": track.trackID,
            "title": track.title,
            "artist": track.artist,
            "imageURL": "\(track.albumImageURL)",
            "duration": track.duration,
            "timestamp": Date.now()
            ])
        
        SessionStore.session?.current = (track, timeLeft, ts, !paused)
    }
    
    func observePaused(sess: Session, eventOccurred: @escaping (Bool) -> Void) {
        guard sessRef != nil else {
            print("sess ref is nil")
            eventOccurred(false)
            return
        }
        
        sessRef!.child("paused").observe(.value, with: { snap in
            guard let paused = snap.value as? Bool else {
                print("Could not parse value of paused from snapshot: \(String(describing: snap.value))")
                return
            }
            
            eventOccurred(paused)
            return
        })
    }
    
    func setPaused(paused: Bool) {
        sessRef?.child("paused").setValue(paused)
    }
}
