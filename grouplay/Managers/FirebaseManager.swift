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
            
            var members: [String] = []
            if let memberDict = dict["members"] as? [String:AnyObject] {
                members = memberDict.map{ $0.key }
            }
            members.append(uid)
            
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
            self.sessRef?.child("member").setValue(members)
            self.sess = Session(owner: owner, members: members, approved: approved, pending: pending)
            completion(self.sess, nil)
        })
    }
    
    func leave() {
        guard let uid = UserDefaults.standard.string(forKey: "uid") else {
            return
        }
        let members = SessionStore.session == nil ? [] : SessionStore.session!.members.filter({ $0 != uid })
        sessRef?.child("members").setValue(members)
    }
    
    func parseQueue(dict: [String:AnyObject]) -> [Track] {
        let queue = dict.map { (subDict) -> Track in
            guard let trackDict = subDict.value as? [String:String] else {
                return Track(title: "", artist: "", trackID: "", imageURL: URL(string: "")!, image: nil, preview: nil, duration: 0)
            }
            guard let title = trackDict["title"]
                , let artist = trackDict["artist"]
                , let imageUrl = trackDict["imageURL"] else {
                    return Track(title: "", artist: "", trackID: "", imageURL: URL(string: "")!, image: nil, preview: nil, duration: 0)
            }
            return Track(title: title, artist: artist, trackID: subDict.key, imageURL: URL(string: imageUrl)!, image: nil, preview: nil, duration: 0)
        }
        return queue.filter{ $0.title != "" }
    }
    
    func fetchCurrent(completion: @escaping (Track?, Int?, NSError?) -> Void) {
        if sessRef == nil {
            print("sess ref nil")
            completion(nil, nil, NSError(domain: "current-fetch", code: 4234, userInfo: nil))
            return
        }
        sessRef?.child("current").observe(.value, with: { snap in
            guard let val = snap.value as? [String:AnyObject] else {
                completion(nil, nil, NSError(domain: "current-fetch", code: 4234, userInfo: nil))
                return
            }
            guard let id = val["id"] as? String, let title = val["title"] as? String,
                let artist = val["artist"] as? String, let imgUrl = val["imageURL"] as? String,
                var timeLeft = val["time_left"] as? Int, let duration = val["duration"] as? Int,
                let timestamp = val["timestamp"] as? UInt64 else {
                    print("irrelevant info in current dict")
                    completion(nil, nil, NSError(domain: "current-fetch", code: 4234, userInfo: nil))
                    return
            }
            let track = Track(title: title, artist: artist, trackID: id, imageURL: URL(string: imgUrl)!, image: nil, preview: nil, duration: duration)
            timeLeft -= Int((Date.now() - timestamp/1000)/1000)
            completion(track, timeLeft, nil)
        }, withCancel: { err in
            print(err)
            completion(nil, nil, NSError(domain: "current-fetch", code: 4234, userInfo: nil))
        })
    }
    
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
    
    func setCurrent(_ track: Track, timeLeft: Int) {
        sessRef?.child("current").setValue([
            "id": track.trackID,
            "title": track.title,
            "artist": track.artist,
            "imageURL": "\(track.albumImageURL)",
            "time_left": timeLeft,
            "duration": track.duration,
            "timestamp": Date.now()
            ])
    }
    
    func enqueue(_ track: Track, pending: Bool) {
        let pathExt = pending ? "pending" : "approved"
        sessRef?.child("queue").child(pathExt).child(track.trackID).setValue([
            "title": track.title,
            "artist": track.artist,
            "imageURL": "\(track.albumImageURL)"
            ])
    }
    
    func dequeue(_ track: Track, pending: Bool) {
        let pathExt = pending ? "pending" : "approved"
        sessRef?.child("queue").child(pathExt).child(track.trackID).removeValue()
    }
    
}
