//
//  TrackTableViewCell.swift
//  grouplay
//
//  Created by Sam Lerner on 12/8/17.
//  Copyright © 2017 Sam Lerner. All rights reserved.
//

import UIKit

class TrackTableViewCell: UITableViewCell {

    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var queueButton: UIButton!
    
    var track: Track!
    
    var dontDownload = false {
        didSet {
            if dontDownload == true {
                NotificationCenter.default.addObserver(self, selector: #selector(stoppedScrolling), name: Notification.Name("stopped-scrolling"), object: nil)
            }
        }
    }
    var imageURL: URL? {
        didSet {
            guard track.image == nil else {
                iconView.image = track.image
                return
            }
            if let url = imageURL, !dontDownload {
                loadImage(from: url)
            }
        }
    }
    var imageDownloadTask: URLSessionDataTask?
    
    var isOwner = false
    var queued = false {
        didSet {
            if queued {
                queueButton.setTitle("", for: .normal)
                queueButton.setImage(UIImage(named: "001-checkmark"), for: .normal)
            } else {
                queueButton.setTitle("Q", for: .normal)
                queueButton.setImage(nil, for: .normal)
            }
        }
    }
    
    @objc func stoppedScrolling() {
        dontDownload = false
        NotificationCenter.default.removeObserver(self, name: Notification.Name("stopped-scrolling"), object: nil)
        if let url = imageURL {
            loadImage(from: url)
        }
    }
    
    func loadImage(from url: URL) {
        imageDownloadTask = URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
            guard error == nil else {
                print(error!)
                return
            }
            guard (response as! HTTPURLResponse).statusCode == 200 else {
                print("URL response is: \((response as! HTTPURLResponse).statusCode)")
                return
            }
            guard data != nil else {
                print("Data for image is nil")
                return
            }
            guard let image = UIImage(data: data!) else {
                print("unable to create image from data")
                return
            }
            
            self.track.image = image
            DispatchQueue.main.async {
                self.iconView.image = image
            }
            self.imageDownloadTask = nil
        })
        imageDownloadTask?.resume()
    }
    
    @IBAction func enqueue(sender: UIButton) {
        if !queued { queued = true }
        
        FirebaseManager.shared.enqueue(track, pending: !self.isOwner)
        if isOwner {
            SessionStore.session!.queue.append(QueuedTrack.from(track))
        }
    }

}
