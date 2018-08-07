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
                self.sess = Session(id: code, owner: uid, members: [:], approved: [], pending: [])
                completion(code, nil)
            } else {
                completion(nil, "\(err!)")
            }
        })
    }
    
    // Attempt to join a session given a code.
    func joinSession(code: String, completion: @escaping (Session?, String?) -> Void) {
        dbRef.child("sessions").child(code).observeSingleEvent(of: .value, with: { (snapshot) in
            guard let dict = snapshot.value as? [String:AnyObject] else {
                completion(nil, "Unable to parse snapshot value")
                return
            }
            guard let owner = dict["owner"] as? String else {
                completion(nil, "Unable to parse owner from snapshot")
                return
            }
            
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
            
            let members = dict["members"] as? [String:[String:AnyObject]] ?? [String:[String:AnyObject]]()
            
            self.sessRef = Database.database().reference().child("sessions").child(code)
            self.sess = Session(id: code, owner: owner, members: members, approved: approved, pending: pending)
            
            completion(self.sess, nil)
        })
    }
    
    func enter() {
        guard let uid = UserDefaults.standard.string(forKey: "uid") else { return }
        
        var members = SessionStore.session?.members ?? [String:[String:AnyObject]]()
        members[uid] = [
            "username": (UserDefaults.standard.string(forKey: "user_id") ?? "username") as AnyObject,
            "has_premium": UserDefaults.standard.bool(forKey: "hasPremium") as AnyObject
        ]
        
        sessRef?.child("members").setValue(members)
        
        if let session = SessionStore.session, uid == session.owner {
            sessRef?.child("tmp_owner").removeValue()
        }
    }
    
    // Remove the current user from the current session
    func leave() {
        guard let uid = UserDefaults.standard.string(forKey: "uid") else { return }
        
        let members = (SessionStore.session?.members.removeValue(forKey: uid) as? [String:[String:AnyObject]]) ?? [String:[String:AnyObject]]()
        sessRef?.child("members").setValue(members as [String:AnyObject])
        
        if let session = SessionStore.session, uid == session.owner {
            let premiumMembers = members.filter({ ($0.value["has_premium"] as? Bool) ?? false })
            let choice = arc4random_uniform(UInt32(premiumMembers.count))
            var newOwner: String = uid
            
            var i = 0
            for (k, _) in premiumMembers {
                if i == choice {
                    newOwner = k
                    break
                }
                i += 1
            }
            
            sessRef?.child("tmp_owner").setValue(newOwner)
        }
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
        return queue.filter{ $0.title != "" }.sorted(by: { $0.timestamp < $1.timestamp })
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
                var timeLeft = val["time_left"] as? Int, let duration = val["duration"] as? Int,
                let timestamp = val["timestamp"] as? UInt64,
                let paused = val["paused"] as? Bool else {
                    //print("irrelevant info in current dict")
                    completion(nil, nil, nil, NSError(domain: "current-fetch", code: 4234, userInfo: nil))
                    return
            }
            let track = Track(title: title, artist: artist, trackID: id, imageURL: URL(string: imgUrl)!, image: nil, preview: nil, duration: duration, timestamp: timestamp)
            timeLeft -= Int((Date.now() - timestamp)/1000)
            
            SessionStore.session?.current = (track, timeLeft, timestamp, !paused)
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
    
    func refresh() {
        guard sessRef != nil else {
            print("sess ref is nil")
            return
        }
        
        sessRef?.observeSingleEvent(of: .value, with: { snap in
            guard let val = snap.value as? [String:AnyObject] else { return }
            
            if let approvedDict = (val["queue"] as? [String:AnyObject])?["approved"] as? [String:AnyObject] {
                SessionStore.session?.approved = self.parseQueue(dict: approvedDict)
            }
            if let pendingDict = (val["queue"] as? [String:AnyObject])?["pending"] as? [String:AnyObject] {
                SessionStore.session?.approved = self.parseQueue(dict: pendingDict)
            }
            
            if let currDict = val["current"] as? [String:AnyObject] {
                guard let trackId = currDict["id"] as? String else { return }
                
                let currTrack = self.parseTrack(id: trackId, trackDict: currDict)
                guard let timeLeft = currDict["time_left"] as? Int,
                    let paused = currDict["paused"] as? Bool else { return }
                
                SessionStore.session?.current = (currTrack, timeLeft, currTrack.timestamp, !paused)
            }
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
    
    // Enqueue the given track in the database. If the current user is the owner, it is automatically set to approved. Otherwise, it is pending.
    func enqueue(_ track: Track, pending: Bool) {
        insert(track, pending: false, before: Date.now())
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
