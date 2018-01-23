import UIKit

class Track {
    
    var title: String
    var artist: String
    var albumImageURL: URL
    var trackID: String
    var image: UIImage?
    var previewURL: URL?
    var duration: Int
    
    init(title: String, artist: String, trackID: String, imageURL: URL, image: UIImage?, preview: URL?, duration: Int) {
        self.title = title
        self.artist = artist
        self.trackID = trackID
        self.albumImageURL = imageURL
        self.image = image
        self.previewURL = preview
        self.duration = duration
    }
    
}
