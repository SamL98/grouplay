//
//  Member.swift
//  grouplay
//
//  Created by Sam Lerner on 1/13/19.
//  Copyright © 2019 Sam Lerner. All rights reserved.
//

import Foundation

class Member {
    
    private struct keys {
        static let username = "username"
        static let hasPremium = "has_premium"
    }
    
    class func marshal(uid: String, json: [String:AnyObject]) -> Member? {
        guard
            let username = json[keys.username] as? String,
            let hasPremium = json[keys.hasPremium] as? Bool
        else {
            print("Could not marshal member: \(json)")
            return nil
        }
        
        return Member(uid: uid, username: username, hasPremium: hasPremium)
    }
    
    func unmarshal() -> [String:AnyObject] {
        return
            [
                keys.username: username as AnyObject,
                keys.hasPremium: hasPremium as AnyObject
            ]
    }
    
    var uid: String
    var username: String
    var hasPremium: Bool
    
    init(uid: String, username: String, hasPremium: Bool) {
        self.uid = uid
        self.username = username
        self.hasPremium = hasPremium
    }
    
    func joinCurrentSession() {
        SessionStore.current?.addMember(self)
    }
    
    func leaveCurrentSession() {
        SessionStore.current?.removeMember(self)
    }

    func isOwner() -> Bool {
        guard
            let session = SessionStore.current
        else
        {
            return false
        }

        return uid == session.owner
    }
    
}
