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
    var owner: String
    var members: [String:[String:AnyObject]]
    var approved: [Track]
    var pending: [Track]
    
    var current: CurrTrack?
    
    init(id: String, owner: String, members: [String:[String:AnyObject]], approved: [Track], pending: [Track]) {
        self.id = id
        self.owner = owner
        self.members = members
        self.approved = approved
        self.pending = pending
    }

}
