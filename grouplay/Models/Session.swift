//
//  Session.swift
//  grouplay
//
//  Created by Sam Lerner on 12/9/17.
//  Copyright © 2017 Sam Lerner. All rights reserved.
//

import Foundation

class Session {
    
    var owner: String
    var members: [String]
    var queue: [Track]
    
    init(owner: String, members: [String], queue: [Track]) {
        self.owner = owner
        self.members = members
        self.queue = queue
    }

}
