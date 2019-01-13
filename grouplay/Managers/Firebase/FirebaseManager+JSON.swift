//
//  FirebaseManager+JSON.swift
//  grouplay
//
//  Created by Sam Lerner on 8/27/18.
//  Copyright © 2018 Sam Lerner. All rights reserved.
//

import Foundation
import Firebase
import FirebaseDatabase

extension FirebaseManager {
    
    // Parse a dictionary into a Track object.
    func parseTrack(dbID: String, trackDict: [String:AnyObject]) -> QueuedTrack {
        guard let title = trackDict["title"] as? String
            , let artist = trackDict["artist"] as? String
            , let imageUrl = trackDict["imageURL"] as? String
            , let duration = trackDict["duration"] as? Int
            , let id = trackDict["trackID"] as? String else {
                
                return QueuedTrack.dummy()
        }
        let track = QueuedTrack(dbID: dbID,
                                title: title,
                                artist: artist,
                                trackID: id,
                                imageURL: URL(string: imageUrl)!,
                                image: nil,
                                preview: nil,
                                duration: duration,
                                timestamp: trackDict["timestamp"] as? UInt64 ?? Date.now(),
                                queuer: trackDict["queuer"] as? String ?? "username")
        return track
    }
    
    // Parse a queue from the database into an array of Track objects.
    func parseQueue(dict: [String:AnyObject]) -> [QueuedTrack] {
        let queue = dict.map { (subDict) -> QueuedTrack in
            guard let trackDict = subDict.value as? [String:AnyObject] else {
                return QueuedTrack.dummy()
            }
            return parseTrack(dbID: subDict.key, trackDict: trackDict)
        }
        return queue.filter{ $0.title != "" }.sorted(by: { $0.timestamp < $1.timestamp })
    }
    
}
