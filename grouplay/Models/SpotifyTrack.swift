import UIKit

class SpotifyTrack {
    
    var title: String
    var artist: String
    var albumImageURL: URL
    var trackID: String
    var duration: Int
    
    init(title: String, artist: String, trackID: String, imageURL: URL, duration: Int) {
        self.title = title
        self.artist = artist
        self.trackID = trackID
        self.albumImageURL = imageURL
        self.duration = duration
    }
    
    class func spotifyTrackFrom(_ q: QueuedTrack) -> SpotifyTrack {
        return SpotifyTrack(title: q.title,
                            artist: q.artist,
                            trackID: q.trackID,
                            imageURL: q.albumImageURL,
                            duration: q.duration)
    }
    
}
