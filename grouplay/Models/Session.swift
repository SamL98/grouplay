//
//  Session.swift
//  grouplay
//
//  Created by Sam Lerner on 12/9/17.
//  Copyright © 2017 Sam Lerner. All rights reserved.
//

import Foundation

// The Session class is the point of access to FirebaseManager.
// Any access to FirebaseManager goes through here.
//
// There is a global instance of Session in SessionStore.current that represents the current session.

class Session {
    
    // MARK: - JSON
    
    private struct keys {
        static let name = "name"
        static let owner = "owner"
        static let queue = "queue"
        static let members = "members"
        static let current = "current"
    }
    
    class func marshal(code: String, json: [String:AnyObject]) -> Session? {
        guard
            let name = json[keys.name] as? String,
            let owner = json[keys.owner] as? String
        else
        {
            print("Unable to marshal session JSON: \(json)")
            return nil
        }
        
        var queue: Queue!
        
        if let queueJSON = json[keys.queue] as? [String:AnyObject] {
            queue = Queue.marshal(json: queueJSON)
            if queue == nil {
                return nil
            }
        } else {
            queue = Queue.empty()
        }
        
        var members: MemberSet!
        
        if let memberJSON = json[keys.members] as? [String:AnyObject] {
            members = MemberSet.marshal(json: memberJSON)
            if members == nil {
                return nil
            }
        } else {
            members = MemberSet.empty()
        }
        
        var current: QueuedTrack?
        
        if let currentJSON = json[keys.current] as? [String:AnyObject] {
            if currentJSON.keys.count > 1 {
                print("Error: more than one current track")
                return nil
            }
            
            if
                let uuid = currentJSON.keys.first,
                let currentTrackJSON = currentJSON[uuid] as? [String:AnyObject]
            {
                current = QueuedTrack.marshal(uuid: uuid, json: currentTrackJSON)
            }
        }
        
        return Session(id: code,
                       name: name,
                       owner: owner,
                       members: members,
                       queue: queue,
                       current: current)
    }
    
    func unmarshal() -> [String:AnyObject] {
        return
            [
                keys.name: name as AnyObject,
                keys.owner: owner as AnyObject,
                keys.queue: queue.unmarshal() as AnyObject,
                keys.members: members.unmarshal() as AnyObject
            ]
    }
    
    // MARK: - Properties
    
    var id: String
    var name: String
    var owner: String
    var members: MemberSet
    var queue: Queue
    var current: QueuedTrack?
    
    // MARK: - Initializer
    
    init(id: String, name: String, owner: String, members: MemberSet, queue: Queue, current: QueuedTrack?) {
        self.id = id
        self.name = name
        self.owner = owner
        self.members = members
        self.queue = queue
        self.current = current
    }
    
    // MARK: - Name
    
    func updateName(_ name: String) {
        self.name = name
        FirebaseManager.shared.updateId(with: name)
    }
    
    // MARK: - Members
    
    func addMember(_ member: Member) {
        members.add(member)
        FirebaseManager.shared.addMember(member)
    }
    
    func removeMember(_ member: Member) {
        members.remove(member)
        FirebaseManager.shared.removeMember(member)
    }
    
    // MARK: - Current
    
    func setCurrent(_ track: QueuedTrack) {
        if
            let oldTrack = current,
            let session = SessionStore.current
        {
            FirebaseManager.shared.removeTrack(oldTrack)
            FirebaseManager.shared.archiveTrack(oldTrack, to: session)
        }

        current = track
        FirebaseManager.shared.setCurrent(track)
    }
    
    func currentSet(_ track: QueuedTrack) {
        self.current = track
        Utility.sendNotification(named: "current-changed")
    }
    
    // MARK: - Tracks

    func prepend(_ track: QueuedTrack) {
        if queue.tracks.count > 0 {
            track.timestamp = queue.tracks.first!.timestamp-1
        }

        queue.prepend(track)
        FirebaseManager.shared.addTrack(track)
    }
    
    func addTrack(_ track: SpotifyTrack) {
        guard
            let queuedTrack = QueuedTrack.queuedTrackFrom(track)
        else
        {
            print("Could not create queued track from Spotify track: \(track.trackID)")
            return
        }
        queue.addTrack(queuedTrack)
        FirebaseManager.shared.addTrack(queuedTrack)
    }
    
    func removeTrack(_ track: QueuedTrack) {
        queue.removeTrack(track)
        FirebaseManager.shared.removeTrack(track)
    }
    
    func trackAdded(_ track: QueuedTrack) {
        queue.addTrack(track)
        Utility.sendNotification(named: "queue-changed")
    }
    
    func trackRemoved(_ track: QueuedTrack) {
        queue.removeTrack(track)
        Utility.sendNotification(named: "queue-changed")
    }

    func isQueued(_ track: SpotifyTrack) -> Bool {
        return queue.isSpotifyTrackQueued(track.trackID)
    }
    
    // MARK: - Sync
    
    func syncQueue() {
        FirebaseManager.shared.observeQueue()
    }
    
    func syncCurrent() {
        FirebaseManager.shared.observeCurrent()
    }

}
