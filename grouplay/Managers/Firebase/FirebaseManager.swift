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
    var sessRef: DatabaseReference?
    
    
    func createSession(completion: @escaping (String?, String?) -> Void) {
        let code = Utility.generateRandomStr(with: 5)
        guard let uid = UserDefaults.standard.string(forKey: "uid") else {
            completion(nil, "No uid in userdefaults")
            return
        }
        
        let session = Session(id: code,
                              name: code,
                              owner: uid,
                              members: MemberSet.empty(),
                              queue: Queue.empty(),
                              current: nil)
        
        dbRef.child("sessions").child(code).setValue(session.unmarshal(),
                                                     withCompletionBlock: { (err, _) in
            if let errStr = err
            {
                completion(nil, "Error creating session in database: \(errStr)")
                return
            }
                                                        
            self.dbRef.child("session_names").child(code).setValue(code)
            
            self.sessRef = Database.database().reference().child("session").child(code)
            SessionStore.current = session 

            completion(code, nil)
        })
    }
    
    func joinSession(code: String, completion: @escaping (String?, String?) -> Void) {
        dbRef.child("sessions").child(code).observeSingleEvent(of: .value, with: { (snapshot) in
            guard
                let dict = snapshot.value as? [String:AnyObject]
                else
            {
                completion(nil, "Unable to parse snapshot value")
                return
            }
            
            guard
                let session = Session.marshal(code: code, json: dict)
                else
            {
                completion(nil, "Unable to marshal session from json")
                return
            }
            
            self.sessRef = Database.database().reference().child("sessions").child(code)
            SessionStore.current = session
            
            completion(code, nil)
        })
    }
    
    func joinSession(name: String, completion: @escaping (String?, String?) -> Void) {
        dbRef.child("session_names").observeSingleEvent(of: .value, with: { snapshot in
            guard
                let dict = snapshot.value as? [String:String]
            else
            {
                completion(nil, "Unable to parse snapshot value for session names")
                return
            }
            
            if !dict.keys.contains(name)
            {
                completion(nil, "Session name: \(name) does not exist")
                return
            }
            
            let code = dict[name]!
            self.joinSession(code: code, completion: completion)
        })
    }
    
    func addMember(_ member: Member) {
        sessRef?.child("members").child(member.uid).setValue(member.unmarshal())
    }
    
    func removeMember(_ member: Member) {
        sessRef?.child("members").child(member.uid).removeValue()
    }
    
    func checkForCollision(_ name: String, comp: @escaping (Bool) -> Void) {
        dbRef.child("session_names").observeSingleEvent(of: .value, with: { snap in
            guard
                let val = snap.value as? [String:String]
            else
            {
                comp(false)
                return
            }
            comp(val.values.contains(name))
        })
    }
    
    func updateId(with name: String) {
        guard
            let sess = SessionStore.current
        else
        {
            print("Could not update session name")
            return
        }
        
        dbRef.child("session_names").child(sess.name).removeValue()
        dbRef.child("session_names").child(name).setValue(sess.id)
        sessRef?.child("name").setValue(name)
        sess.name = name
    }
    
}
