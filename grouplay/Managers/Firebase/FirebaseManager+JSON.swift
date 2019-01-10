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
    func parseTrack(id: String, trackDict: [String:AnyObject]) -> QueuedTrack {
        guard let title = trackDict["title"] as? String
            , let artist = trackDict["artist"] as? String
            , let imageUrl = trackDict["imageURL"] as? String
            , let duration = trackDict["duration"] as? Int else {
                return QueuedTrack(title: "", artist: "", trackID: "", imageURL: URL(string: "https://fake.com")!, image: nil, preview: nil, duration: 0, timestamp: 0, queuer: "username")
        }
        let track = QueuedTrack(title: title, artist: artist, trackID: id, imageURL: URL(string: imageUrl)!, image: nil, preview: nil, duration: duration, timestamp: trackDict["timestamp"] as? UInt64 ?? Date.now(), queuer: "username")
        if let queuer = trackDict["queuer"] as? String {
            track.queuer = queuer
        }
        return track
    }
    
    // Parse a queue from the database into an array of Track objects.
    func parseQueue(dict: [String:AnyObject]) -> [QueuedTrack] {
        let queue = dict.map { (subDict) -> QueuedTrack in
            guard let trackDict = subDict.value as? [String:AnyObject] else {
                return QueuedTrack(title: "", artist: "", trackID: "", imageURL: URL(string: "")!, image: nil, preview: nil, duration: 0, timestamp: 0, queuer: "username")
            }
            return parseTrack(id: subDict.key, trackDict: trackDict)
        }
        for t in queue {
            print("\(t.title) \(t.queuer)")
        }
        return queue.filter{ $0.title != "" }.sorted(by: { $0.timestamp < $1.timestamp })
    }
    
}
