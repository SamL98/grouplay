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
    func parseTrack(id: String, trackDict: [String:AnyObject]) -> Track {
        guard let title = trackDict["title"] as? String
            , let artist = trackDict["artist"] as? String
            , let imageUrl = trackDict["imageURL"] as? String
            , let duration = trackDict["duration"] as? Int else {
                return Track(title: "", artist: "", trackID: "", imageURL: URL(string: "https://fake.com")!, image: nil, preview: nil, duration: 0, timestamp: 0)
        }
        return Track(title: title, artist: artist, trackID: id, imageURL: URL(string: imageUrl)!, image: nil, preview: nil, duration: duration, timestamp: trackDict["timestamp"] as? UInt64 ?? Date.now())
    }
    
    // Parse a queue from the database into an array of Track objects.
    func parseQueue(dict: [String:AnyObject]) -> [Track] {
        let queue = dict.map { (subDict) -> Track in
            guard let trackDict = subDict.value as? [String:AnyObject] else {
                return Track(title: "", artist: "", trackID: "", imageURL: URL(string: "")!, image: nil, preview: nil, duration: 0, timestamp: 0)
            }
            return parseTrack(id: subDict.key, trackDict: trackDict)
        }
        return queue.filter{ $0.title != "" }.sorted(by: { $0.timestamp < $1.timestamp })
    }
    
}
