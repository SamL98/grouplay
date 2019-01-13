//
//  QueuedTrack.swift
//  grouplay
//
//  Created by Sam Lerner on 1/9/19.
//  Copyright © 2019 Sam Lerner. All rights reserved.
//

import Foundation

class QueuedTrack: Track {
    
    var queuer: String
    
    init(dbID: String, title: String, artist: String, trackID: String, imageURL: URL, image: UIImage?, preview: URL?, duration: Int, timestamp: UInt64, queuer: String) {
        self.queuer = queuer
        super.init(dbID: dbID,
                   title: title,
                   artist: artist,
                   trackID: trackID,
                   imageURL: imageURL,
                   image: image,
                   preview: preview,
                   duration: duration,
                   timestamp: timestamp)
    }
    
    class func from(_ t: Track) -> QueuedTrack {
        return QueuedTrack(dbID: t.dbID,
                           title: t.title,
                           artist: t.artist,
                           trackID: t.trackID,
                           imageURL: t.albumImageURL,
                           image: t.image,
                           preview: t.previewURL,
                           duration: t.duration,
                           timestamp: t.timestamp,
                           queuer: UserDefaults.standard.string(forKey: "user_id") ?? "username")
    }
    
    override class func dummy() -> QueuedTrack {
        return QueuedTrack.from(Track.dummy())
    }
    
}
