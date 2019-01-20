//
//  FirebaseManager+Current.swift
//  grouplay
//
//  Created by Sam Lerner on 8/27/18.
//  Copyright © 2018 Sam Lerner. All rights reserved.
//

import Foundation
import Firebase
import FirebaseDatabase

extension FirebaseManager {
    
    func observeCurrent() {
        let handler: (DataSnapshot) -> Void = { snapshot in
            guard
                let currentJSON = snapshot.value as? [String:AnyObject]
            else
            {
                print("Error: could not parse snapshot value from current observe")
                return
            }
            
            let uuid = snapshot.key
            
            guard
                let current = QueuedTrack.marshal(uuid: uuid, json: currentJSON)
            else
            {
                print("Error: Could not marshal current JSON")
                return
            }
            
            SessionStore.current?.currentSet(current)
        }
        
        sessRef?.child("current").observe(.childAdded,
                                          with: handler)
    }

    func setCurrent(_ track: QueuedTrack) {
        let currentJSON = [
            track.uuid: track.unmarshal() as AnyObject
        ]
        sessRef?.child("current").setValue(currentJSON)
    }
}
