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
    var approved: [Track]
    var pending: [Track]
    
    init(owner: String, members: [String], approved: [Track], pending: [Track]) {
        self.owner = owner
        self.members = members
        self.approved = approved
        self.pending = pending
    }

}
