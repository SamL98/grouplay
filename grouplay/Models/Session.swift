//
//  Session.swift
//  grouplay
//
//  Created by Sam Lerner on 12/9/17.
//  Copyright © 2017 Sam Lerner. All rights reserved.
//

import Foundation

typealias CurrTrack = (track: Track, timeLeft: Int, timestamp: UInt64, playing: Bool)

class Session {
    
    var id: String
    var name: String
    var owner: String
    var members: [String:[String:AnyObject]]
    var queue: [QueuedTrack]
    
    var current: CurrTrack?
    
    init(id: String, name: String, owner: String, members: [String:[String:AnyObject]], queue: [QueuedTrack]) {
        self.id = id
        self.name = name
        self.owner = owner
        self.members = members
        self.queue = queue
    }

}
