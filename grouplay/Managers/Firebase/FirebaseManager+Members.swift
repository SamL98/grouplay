//
//  FirebaseManager+Members.swift
//  grouplay
//
//  Created by Sam Lerner on 1/21/19.
//  Copyright © 2019 Sam Lerner. All rights reserved.
//

import Foundation
import Firebase
import FirebaseDatabase

extension FirebaseManager {
    
    func observeMembers() {
        observeMembersAdded()
        observeMembersRemoved()
    }
    
    private func observeMembersAdded() {
        sessRef?.child("memers").observe(.childAdded, with: { snap in
            let uid = snap.key
            
            if
                let members = SessionStore.current?.members.members,
                members.contains(where: { $0.uid == uid })
            {
                print("Members already contains uid: \(uid)")
                return
            }
            
            guard
                let memberJSON = snap.value as? [String:AnyObject]
                else
            {
                print("Could not cast value added to members as a dictionary")
                return
            }
            
            guard
                let member = Member.marshal(uid: uid, json: memberJSON)
                else
            {
                print("Could not marshal added member: \(memberJSON)")
                return
            }
            
            SessionStore.current?.memberAdded(member)
        })
    }
    
    private func observeMembersRemoved() {
        sessRef?.child("members").observe(.childRemoved, with: { snap in
            guard
                let memberJSON = snap.value as? [String:AnyObject]
                else
            {
                print("Could not cast value added to members as a dictionary")
                return
            }
            
            let uid = snap.key
            
            guard
                let member = Member.marshal(uid: uid, json: memberJSON)
                else
            {
                print("Could not marshal removed member: \(memberJSON)")
                return
            }
            
            SessionStore.current?.memberRemoved(member)
        })
    }
    
}
