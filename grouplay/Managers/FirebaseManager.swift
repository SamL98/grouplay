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
                completion(code, nil)
            } else {
                completion(nil, "\(err!)")
            }
        })
    }
    
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
            
            var members: [String] = []
            if let memberDict = dict["members"] as? [String:AnyObject] {
                members = memberDict.map{ $0.key }
            }
            
            var queue: [Track] = []
            if let queueDict = dict["queue"] as? [String:AnyObject] {
                queue = queueDict.map {
                    guard let trackDict = $0.value as? [String:String] else {
                        return Track(title: "", artist: "", trackID: "", imageURL: URL(string: "")!, image: nil, preview: nil, duration: 0)
                    }
                    guard let title = trackDict["title"]
                        , let artist = trackDict["artist"]
                        , let trackId = trackDict["trackID"]
                        , let imageUrl = trackDict["imageURL"] else {
                            return Track(title: "", artist: "", trackID: "", imageURL: URL(string: "")!, image: nil, preview: nil, duration: 0)
                    }
                    return Track(title: title, artist: artist, trackID: trackId, imageURL: URL(string: imageUrl)!, image: nil, preview: nil, duration: 0)
                }
                queue = queue.filter{ $0.title != "" }
            }
            
            completion(Session(owner: owner, members: members, queue: queue), nil)
        })
    }
    
}
