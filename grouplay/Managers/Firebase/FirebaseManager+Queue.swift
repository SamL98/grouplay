//
//  FirebaseManager+Queue.swift
//  grouplay
//
//  Created by Sam Lerner on 8/27/18.
//  Copyright © 2018 Sam Lerner. All rights reserved.
//

import Foundation
import Firebase
import FirebaseDatabase

extension FirebaseManager {
    
    func archiveTrack(_ track: QueuedTrack, to session: Session) {
        dbRef.child("history").child(session.id).child("\(Date.now())").setValue(track.trackID)
    }

    func addTrack(_ track: QueuedTrack) {
        sessRef?.child("queue").child(track.uuid).setValue(track.unmarshal())
    }
    
    func removeTrack(_ track: QueuedTrack) {
        sessRef?.child("queue").child(track.uuid).removeValue()
    }
    
    func observeQueue() {
        observeQueueAdd()
        observeQueueRemove()
    }
    
    private func observeQueueAdd() {
        sessRef?.child("queue").observe(.childAdded, with: { snap in
            let uuid = snap.key
            print("Observing \(uuid) just added")
            
            if
                let queue = SessionStore.current?.queue.tracks,
                queue.contains(where: { $0.uuid == uuid })
            {
                return
            }
            
            guard
                let trackJSON = snap.value as? [String:AnyObject]
            else
            {
                print("Could not cast value added to queue as a dictionary")
                return
            }
            
            guard
                let track = QueuedTrack.marshal(uuid: uuid, json: trackJSON)
            else
            {
                print("Could not marshal added track: \(trackJSON)")
                return
            }

            SessionStore.current?.trackAdded(track)
        })
    }
    
    private func observeQueueRemove() {
        sessRef?.child("queue").observe(.childRemoved, with: { snap in
            guard
                let trackJSON = snap.value as? [String:AnyObject]
            else
            {
                print("Could not cast value added to queue as a dictionary")
                return
            }

            let uuid = snap.key
            
            guard
                let track = QueuedTrack.marshal(uuid: uuid, json: trackJSON)
            else
            {
                print("Could not marshal removed track: \(trackJSON)")
                return
            }

            SessionStore.current?.trackRemoved(track)
        })
    }
    
}
