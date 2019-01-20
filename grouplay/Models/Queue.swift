//
//  Queue.swift
//  grouplay
//
//  Created by Sam Lerner on 1/13/19.
//  Copyright © 2019 Sam Lerner. All rights reserved.
//

import Foundation

class Queue {
    
    class func marshal(json: [String:AnyObject]) -> Queue? {
        var tracks = [QueuedTrack]()
        for (uuid, val) in json {
            guard
                let trackJSON = val as? [String:AnyObject],
                let track = QueuedTrack.marshal(uuid: uuid, json: trackJSON)
            else {
                continue
            }
            
            tracks.append(track)
        }
        return Queue(tracks: tracks)
    }
    
    func unmarshal() -> [String:AnyObject] {
        var queueJSON = [String:AnyObject]()
        for track in tracks {
            queueJSON[track.uuid] = track.unmarshal() as AnyObject
        }
        return queueJSON
    }
    
    class func empty() -> Queue {
        return Queue(tracks: [])
    }
    
    var tracks: [QueuedTrack]
    
    init(tracks: [QueuedTrack]) {
        self.tracks = tracks
    }

    func prepend(_ track: QueuedTrack) {
        tracks.insert(track, at: 0)
    }
    
    func addTrack(_ track: QueuedTrack) {
        // Propagate the track up the queue if for some reason it's timestamp is earlier than those existing in the queue
        
        if tracks.count == 0 {
            tracks.append(track)
        }
        
        var i = tracks.endIndex-1
        
        while i > 0 && track.timestamp < tracks[i].timestamp {
            i -= 1
        }
        
        tracks.insert(track, at: i)
    }
    
    func removeTrack(_ track: QueuedTrack) {
        var i = 0
        
        while i < tracks.count && tracks[i].uuid != track.uuid {
            i += 1
        }
        
        tracks.remove(at: i)
    }

    func isSpotifyTrackQueued(_ id: String) -> Bool {
        return tracks.contains(where: { $0.trackID == id })
    }
    
}
