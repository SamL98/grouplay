import UIKit

class Track {
    
    var dbID: String
    var title: String
    var artist: String
    var albumImageURL: URL
    var trackID: String
    var image: UIImage?
    var previewURL: URL?
    var duration: Int
    var timestamp: UInt64
    
    init(dbID: String, title: String, artist: String, trackID: String, imageURL: URL, image: UIImage?, preview: URL?, duration: Int, timestamp: UInt64) {
        self.dbID = dbID
        self.title = title
        self.artist = artist
        self.trackID = trackID
        self.albumImageURL = imageURL
        self.image = image
        self.previewURL = preview
        self.duration = duration
        self.timestamp = timestamp
    }
    
    class func dummy() -> Track {
        return Track(dbID: "",
                     title: "",
                     artist: "",
                     trackID: "",
                     imageURL: URL(string: "http://fake.com")!,
                     image: nil,
                     preview: nil,
                     duration: 0,
                     timestamp: 0)
    }
    
}
