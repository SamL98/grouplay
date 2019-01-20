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
    
    var dontDownload = false {
        didSet {
            if dontDownload == true {
                NotificationCenter.default.addObserver(self, selector: #selector(stoppedScrolling), name: Notification.Name("stopped-scrolling"), object: nil)
            }
        }
    }
    
    var imageURL: URL? {
        didSet {
            if let url = imageURL, !dontDownload {
                loadImage(from: url)
            }
        }
    }
    
    var imageDownloadTask: URLSessionDataTask?
    
    @objc func stoppedScrolling() {
        dontDownload = false
        NotificationCenter.default.removeObserver(self, name: Notification.Name("stopped-scrolling"), object: nil)
        if let url = imageURL {
            loadImage(from: url)
        }
    }
    
    func loadImage(from url: URL) {
        if imageDownloadTask != nil {
            imageDownloadTask?.resume()
            return
        }
        
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
            
            DispatchQueue.main.async {
                self.iconView.image = image
            }
            self.imageDownloadTask = nil
        })
        imageDownloadTask?.resume()
    }

}
