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
    
    var track: Track!
    var imageURL: URL? {
        didSet {
            guard track.image == nil else {
                iconView.image = track.image
                return
            }
            if let url = imageURL {
                loadImage(from: url)
            }
        }
    }
    
    func loadImage(from url: URL) {
        URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
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
        }).resume()
    }

}
