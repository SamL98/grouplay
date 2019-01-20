//
//  QueuedTrack.swift
//  grouplay
//
//  Created by Sam Lerner on 1/9/19.
//  Copyright © 2019 Sam Lerner. All rights reserved.
//

import Foundation

class QueuedTrack {
    
    private struct keys {
        static let artist = "artist"
        static let duration = "duration"
        static let imgURL = "imageURL"
        static let queuer = "queuer"
        static let ts = "timestamp"
        static let title = "title"
        static let trackID = "trackID"
    }
    
    class func marshal(uuid: String, json: [String:AnyObject]) -> QueuedTrack? {
        guard
            let artist = json[keys.artist] as? String,
            let duration = json[keys.duration] as? Int,
            let imgURLString = json[keys.imgURL] as? String,
            let queuer = json[keys.queuer] as? String,
            let ts = json[keys.ts] as? UInt64,
            let title = json[keys.title] as? String,
            let trackID = json[keys.trackID] as? String
        else {
            print("Unable to marshal QueuedTrack from: \(json)")
            return nil
        }
        
        guard
            let imgURL = URL(string: imgURLString)
        else {
            print("Unable to create URL from: \(imgURLString)")
            return nil
        }
        
        return QueuedTrack(uuid: uuid, title: title, artist: artist, trackID: trackID, imageURL: imgURL, duration: duration, timestamp: ts, queuer: queuer)
    }
    
    func unmarshal() -> [String:AnyObject] {
        return
            [
                keys.title: title as AnyObject,
                keys.artist: artist as AnyObject,
                keys.trackID: trackID as AnyObject,
                keys.imgURL: "\(albumImageURL)" as AnyObject,
                keys.duration: duration as AnyObject,
                keys.ts: timestamp as AnyObject,
                keys.queuer: queuer as AnyObject
            ]
    }
    
    var uuid: String
    var title: String
    var artist: String
    var albumImageURL: URL
    var trackID: String
    var duration: Int
    var timestamp: UInt64
    var queuer: String
    
    init(uuid: String, title: String, artist: String, trackID: String, imageURL: URL, duration: Int, timestamp: UInt64, queuer: String) {
        self.uuid = uuid
        self.title = title
        self.artist = artist
        self.trackID = trackID
        self.albumImageURL = imageURL
        self.duration = duration
        self.timestamp = timestamp
        self.queuer = queuer
    }
    
    class func queuedTrackFrom(_ t: SpotifyTrack) -> QueuedTrack? {
        guard
            let queuer = UserStore.current?.username
        else
        {
            print("Could not obtain current user from user store")
            return nil
        }
        
        let uuid = Utility.generateRandomStr(with: 15)
        let ts = Date.now()
        
        return QueuedTrack(uuid: uuid,
                           title: t.title,
                           artist: t.artist,
                           trackID: t.trackID,
                           imageURL: t.albumImageURL,
                           duration: t.duration,
                           timestamp: ts,
                           queuer: queuer)
    }
    
}
