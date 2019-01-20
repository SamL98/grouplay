//
//  MemberSet.swift
//  grouplay
//
//  Created by Sam Lerner on 1/13/19.
//  Copyright © 2019 Sam Lerner. All rights reserved.
//

import Foundation

class MemberSet {
    
    class func marshal(json: [String:AnyObject]) -> MemberSet? {
        var members = [Member]()
        for (uid, val) in json {
            guard
                let memberJSON = val as? [String:AnyObject],
                let member = Member.marshal(uid: uid, json: memberJSON)
            else {
                continue
            }
            
            members.append(member)
        }
        return MemberSet(members: members)
    }
    
    func unmarshal() -> [String:AnyObject] {
        var memberJSON = [String:AnyObject]()
        for member in members {
            memberJSON[member.uid] = member.unmarshal() as AnyObject
        }
        return memberJSON
    }
    
    class func empty() -> MemberSet {
        return MemberSet(members: [])
    }
    
    var members: [Member]
    
    init(members: [Member]) {
        self.members = members
    }
    
    func add(_ member: Member) {
        members.append(member)
    }
    
    func remove(_ member: Member) {
        members = members.filter({ $0.uid != member.uid })
    }
}
