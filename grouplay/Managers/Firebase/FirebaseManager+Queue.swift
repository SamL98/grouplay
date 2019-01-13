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
    
    // MARK: Setters
    
    func archiveTrack(_ track: Track, to session: Session) {
        dbRef.child("history").child(session.id).child("\(Date.now())").setValue(track.trackID)
    }
    
    // Enqueue the given track in the database. If the current user is the owner, it is automatically set to approved. Otherwise, it is pending.
    func enqueue(_ track: Track, pending: Bool) -> String {
        return insert(track, pending: false, before: Date.now())
    }
    
    // Remove the given track from the database queue.
    func dequeue(_ track: QueuedTrack, pending: Bool) {
        let pathExt = pending ? "pending" : "approved"
        
        for t in SessionStore.session!.queue {
            if t.trackID == track.trackID && t.queuer == track.queuer {
                sessRef?.child("queue").child(pathExt).child(t.dbID).removeValue()
                break
            }
        }
    }
    
    // Insert into the queue before the given position for when the previous track is skipped
    func insert(_ track: Track, pending: Bool, before: UInt64) -> String {
        let pathExt = pending ? "pending" : "approved"
        track.dbID = Utility.generateRandomStr(with: 15)
        sessRef?.child("queue").child(pathExt).child(track.dbID).setValue([
            "trackID": track.trackID,
            "title": track.title,
            "artist": track.artist,
            "imageURL": "\(track.albumImageURL)",
            "duration": track.duration,
            "timestamp": before-1,
            "queuer": UserDefaults.standard.string(forKey: "user_id") ?? "username"
            ])
        return track.dbID
    }
    
    // MARK: Observers
    
    // Observe additions and removals from both the approved and pending queues.
    func observeQueue(sess: Session, eventOccurred: @escaping (Bool) -> Void) {
        guard sessRef != nil else {
            print("sess ref is nil")
            eventOccurred(false)
            return
        }
        observeQueuePathAdd(sess: sess, path: "approved", eventOccurred)
        observeQueuePathRemove(sess: sess, path: "approved", eventOccurred)
    }
    
    private func observeQueuePathAdd(sess: Session, path: String, _ eventOccurred: @escaping (Bool) -> Void) {
        sessRef!.child("queue").child(path).observe(.childAdded, with: { snap in
            guard let newTrackDict = snap.value as? [String:AnyObject] else {
                print("could not parse new track from snapshot: \(String(describing: snap.value))")
                eventOccurred(false)
                return
            }
            
            let newTrack = self.parseTrack(dbID: snap.key, trackDict: newTrackDict)
            var queue = sess.queue
            guard newTrack.trackID != "" && !queue.contains(where: { $0.trackID == newTrack.trackID }) else {
                //print("new track is nil or is already in approved queue")
                eventOccurred(false)
                return
            }
            
            queue.append(newTrack)
            if path == "approved" {
                SessionStore.session?.queue.append(newTrack)
            }
            eventOccurred(true)
        })
    }
    
    private func observeQueuePathRemove(sess: Session, path: String, _ eventOccurred: @escaping (Bool) -> Void) {
        sessRef!.child("queue").child(path).observe(.childRemoved, with: { snap in
            guard let newTrackDict = snap.value as? [String:AnyObject] else {
                print("could not parse new track from snapshot: \(String(describing: snap.value))")
                eventOccurred(false)
                return
            }
            
            let newTrack = self.parseTrack(dbID: snap.key, trackDict: newTrackDict)
            var queue = sess.queue
            guard newTrack.trackID != "" && queue.contains(where: { $0.trackID == newTrack.trackID }) else {
                //print("new track is nil or is already in approved queue")
                eventOccurred(false)
                return
            }
            var i = 0
            for track in queue {
                if track.trackID == newTrack.trackID { break }
                i += 1
            }
            queue.remove(at: i)
            eventOccurred(true)
        })
    }
    
}
