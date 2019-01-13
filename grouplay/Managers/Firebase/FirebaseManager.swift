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
    let dbRef = Database.database().reference()
    
    var sess: Session?
    var sessRef: DatabaseReference?
    
    // Create a session with the current user as the owner.
    func createSession(completion: @escaping (String?, String?) -> Void) {
        let code = Utility.generateRandomStr(with: 5)
        guard let uid = UserDefaults.standard.string(forKey: "uid") else {
            completion(nil, "No uid in userdefaults")
            return
        }
        dbRef.child("sessions").child(code).setValue([
            "name": code as AnyObject,
            "owner": uid as AnyObject,
            "paused": true as AnyObject
        ], withCompletionBlock: { (err, _) in
            if err == nil {
                self.sessRef = Database.database().reference().child("sessions").child(code)
                self.sess = Session(id: code, name: code, owner: uid, members: [:], queue: [])
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
            
            var queue: [QueuedTrack] = []
            
            if let queueDict = dict["queue"] as? [String:AnyObject] {
                if let approvedDict = queueDict["approved"] as? [String:AnyObject] {
                    queue = self.parseQueue(dict: approvedDict)
                }
            }
            
            let members = dict["members"] as? [String:[String:AnyObject]] ?? [String:[String:AnyObject]]()
            
            let name = dict["name"] as? String ?? code
            
            self.sessRef = Database.database().reference().child("sessions").child(code)
            self.sess = Session(id: code, name: name, owner: owner, members: members, queue: queue)
            
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
        guard let uid = UserDefaults.standard.string(forKey: "uid") else {
            print("No uid found")
            return
        }
        
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
    
    func checkForCollision(_ name: String, comp: @escaping (Bool) -> Void) {
        dbRef.child("session_names").observeSingleEvent(of: .value, with: { snap in
            guard let val = snap.value as? [String:String] else {
                comp(false)
                return
            }
            comp(val.values.contains(name))
        })
    }
    
    func updateId(with name: String) {
        guard let sess = SessionStore.session else { return }
        dbRef.child("session_names").child(sess.id).setValue(name)
        sessRef?.child("name").setValue(name)
    }
    
}
