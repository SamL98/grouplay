//
//  FirebaseManager.swift
//  grouplay
//
//  Created by Sam Lerner on 12/9/17.
//  Copyright © 2017 Sam Lerner. All rights reserved.
//

import Foundation
import Firebase
import FirebaseDatabase

class FirebaseManager {
    
    static let shared = FirebaseManager()
    private let dbRef = Database.database().reference()
    
    private var sess: Session?
    private var sessRef: DatabaseReference?
    
    // Create a session with the current user as the owner.
    func createSession(completion: @escaping (String?, String?) -> Void) {
        let code = Utility.generateRandomStr(with: 5)
        guard let uid = UserDefaults.standard.string(forKey: "uid") else {
            completion(nil, "No uid in userdefaults")
            return
        }
        dbRef.child("sessions").child(code).setValue([
            "owner": uid as AnyObject
        ], withCompletionBlock: { (err, _) in
            if err == nil {
                self.sessRef = Database.database().reference().child("sessions").child(code)
                self.sess = Session(owner: uid, members: [], approved: [], pending: [])
                completion(code, nil)
            } else {
                completion(nil, "\(err!)")
            }
        })
    }
    
    // Attempt to join a session given a code.
    func joinSession(code: String, completion: @escaping (Session?, String?) -> Void) {
        guard let uid = UserDefaults.standard.string(forKey: "uid") else {
            return
        }
        dbRef.child("sessions").child(code).observeSingleEvent(of: .value, with: { (snapshot) in
            guard let dict = snapshot.value as? [String:AnyObject] else {
                completion(nil, "Unable to parse snapshot value")
                return
            }
            guard let owner = dict["owner"] as? String else {
                completion(nil, "Unable to parse owner from snapshot")
                return
            }
            
            var members = dict["members"] as? [String] ?? []
            if !members.contains(uid) { members.append(uid) }
            
            var approved: [Track] = []
            var pending: [Track] = []
            
            if let queueDict = dict["queue"] as? [String:AnyObject] {
                if let approvedDict = queueDict["approved"] as? [String:AnyObject] {
                    approved = self.parseQueue(dict: approvedDict)
                }
                if let pendingDict = queueDict["pending"] as? [String:AnyObject] {
                    pending = self.parseQueue(dict: pendingDict)
                }
            }
            
            self.sessRef = Database.database().reference().child("sessions").child(code)
            self.sessRef?.child("members").setValue(members)
            self.sess = Session(owner: owner, members: members, approved: approved, pending: pending)
            completion(self.sess, nil)
        })
    }
    
    // Remove the current user from the current session
    func leave() {
        guard let uid = UserDefaults.standard.string(forKey: "uid") else {
            return
        }
        let members = SessionStore.session == nil ? [] : SessionStore.session!.members.filter({ $0 != uid })
        sessRef?.child("members").setValue(members)
    }
    
    // Parse a dictionary into a Track object.
    func parseTrack(id: String, trackDict: [String:AnyObject]) -> Track {
        guard let title = trackDict["title"] as? String
            , let artist = trackDict["artist"] as? String
            , let imageUrl = trackDict["imageURL"] as? String
            , let duration = trackDict["duration"] as? Int else {
                return Track(title: "", artist: "", trackID: "", imageURL: URL(string: "https://fake.com")!, image: nil, preview: nil, duration: 0, timestamp: 0)
        }
        return Track(title: title, artist: artist, trackID: id, imageURL: URL(string: imageUrl)!, image: nil, preview: nil, duration: duration, timestamp: trackDict["timestamp"] as? UInt64 ?? Date.now())
    }
    
    // Parse a queue from the database into an array of Track objects.
    func parseQueue(dict: [String:AnyObject]) -> [Track] {
        let queue = dict.map { (subDict) -> Track in
            guard let trackDict = subDict.value as? [String:AnyObject] else {
                return Track(title: "", artist: "", trackID: "", imageURL: URL(string: "")!, image: nil, preview: nil, duration: 0, timestamp: 0)
            }
            return parseTrack(id: subDict.key, trackDict: trackDict)
        }
        return queue.filter{ $0.title != "" }
    }
    
    // Observe the realtime current track in the database. Only called if the session is not owned by the current user.
    func fetchCurrent(completion: @escaping (Track?, Int?, Bool?, NSError?) -> Void) {
        if sessRef == nil {
            print("sess ref nil")
            completion(nil, nil, nil, NSError(domain: "current-fetch", code: 4234, userInfo: nil))
            return
        }
        sessRef?.child("current").observe(.value, with: { snap in
            if let pausedVal = snap.value as? Bool {
                NotificationCenter.default.post(name: Notification.Name(rawValue: "paused-changed"), object: nil, userInfo: ["paused": pausedVal])
                return
            }

            guard let val = snap.value as? [String:AnyObject] else {
                completion(nil, nil, nil, NSError(domain: "current-fetch", code: 4234, userInfo: nil))
                return
            }
            guard let id = val["id"] as? String, let title = val["title"] as? String,
                let artist = val["artist"] as? String, let imgUrl = val["imageURL"] as? String,
                let timeLeft = val["time_left"] as? Int, let duration = val["duration"] as? Int,
                let timestamp = val["timestamp"] as? UInt64,
                let paused = val["paused"] as? Bool else {
                    //print("irrelevant info in current dict")
                    completion(nil, nil, nil, NSError(domain: "current-fetch", code: 4234, userInfo: nil))
                    return
            }
            let track = Track(title: title, artist: artist, trackID: id, imageURL: URL(string: imgUrl)!, image: nil, preview: nil, duration: duration, timestamp: timestamp)
            //timeLeft -= Int((Date.now() - timestamp)/1000)
            completion(track, timeLeft, paused,  nil)
        }, withCancel: { err in
            print("could not fetch current (firebase): \(err)")
            completion(nil, nil, nil, NSError(domain: "current-fetch", code: 4234, userInfo: nil))
        })
    }
    
    // Fetch the approved and pending queues from the database for the given session.
    func fetchQueue(sess: Session, completion: @escaping (String?) -> Void) {
        if sessRef == nil {
            print("sess ref nil")
            completion("sess ref nil")
            return
        }
        sessRef?.child("queue").observeSingleEvent(of: .value, with: { snap in
            guard let queueDict = snap.value as? [String:AnyObject] else {
                completion("no snap val")
                return
            }
            if let approvedDict = queueDict["approved"] as? [String:AnyObject] {
                sess.approved = self.parseQueue(dict: approvedDict)
            }
            if let pendingDict = queueDict["pending"] as? [String:AnyObject] {
                sess.pending = self.parseQueue(dict: pendingDict)
            }
            completion(nil)
        })
    }
    
    func updatePause(_ paused: Bool) {
        sessRef?.child("current").child("paused").setValue(paused)
    }
    
    func setTimeLeft(_ timeLeft: Int) {
        sessRef?.child("current").child("time_left").setValue(timeLeft)
    }
    
    // Observe additions and removals from both the approved and pending queues.
    func observeQueue(sess: Session, eventOccurred: @escaping (Bool) -> Void) {
        guard sessRef != nil else {
            print("sess ref is nil")
            eventOccurred(false)
            return
        }
        observeQueuePathAdd(sess: sess, path: "approved", eventOccurred)
        observeQueuePathAdd(sess: sess, path: "pending", eventOccurred)
        observeQueuePathRemove(sess: sess, path: "approved", eventOccurred)
        observeQueuePathRemove(sess: sess, path: "pending", eventOccurred)
    }
    
    private func observeQueuePathAdd(sess: Session, path: String, _ eventOccurred: @escaping (Bool) -> Void) {
        sessRef!.child("queue").child(path).observe(.childAdded, with: { snap in
            guard let newTrackDict = snap.value as? [String:AnyObject] else {
                print("could not parse new track from snapshot: \(String(describing: snap.value))")
                eventOccurred(false)
                return
            }
            
            let newTrack = self.parseTrack(id: snap.key, trackDict: newTrackDict)
            var queue = path == "approved" ? sess.approved : sess.pending
            guard newTrack.trackID != "" && !queue.contains(where: { $0.trackID == newTrack.trackID }) else {
                //print("new track is nil or is already in approved queue")
                eventOccurred(false)
                return
            }
            queue.append(newTrack)
            if path == "approved" {
                SessionStore.session?.approved.append(newTrack)
            } else {
                SessionStore.session?.pending.append(newTrack)
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
            let newTrack = self.parseTrack(id: snap.key, trackDict: newTrackDict)
            var queue = path == "approved" ? sess.approved : sess.pending
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
    
    // Set the current track in the database. Only called if the session is owned by the current user.
    func setCurrent(_ track: Track, timeLeft: Int, paused: Bool) {
        sessRef?.child("current").setValue([
            "id": track.trackID,
            "title": track.title,
            "artist": track.artist,
            "imageURL": "\(track.albumImageURL)",
            "time_left": timeLeft,
            "duration": track.duration,
            "timestamp": Date.now(),
            "paused": paused
            ])
    }
    
    // Enqueue the given track in the database. If the current user is the owner, it is automatically set to approved. Otherwise, it is pending.
    func enqueue(_ track: Track, pending: Bool) {
        insert(track, pending: pending, before: Date.now())
    }
    
    // Remove the given track from the database queue.
    func dequeue(_ track: Track, pending: Bool) {
        let pathExt = pending ? "pending" : "approved"
        sessRef?.child("queue").child(pathExt).child(track.trackID).removeValue()
    }
    
    // Insert into the queue before the given position for when the previous track is skipped
    func insert(_ track: Track, pending: Bool, before: UInt64) {
        let pathExt = pending ? "pending" : "approved"
        sessRef?.child("queue").child(pathExt).child(track.trackID).setValue([
            "title": track.title,
            "artist": track.artist,
            "imageURL": "\(track.albumImageURL)",
            "duration": track.duration,
            "timestamp": before-1
            ])
    }
    
}
