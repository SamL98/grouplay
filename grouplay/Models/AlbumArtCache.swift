//
//  AlbumArtCache.swift
//  grouplay
//
//  Created by Sam Lerner on 1/20/19.
//  Copyright © 2019 Sam Lerner. All rights reserved.
//

import UIKit

var scrolling = false

class AlbumArtCache {
    
    // MARK: - Downloader
    
    private class Downloader {
        
        var dataTask: URLSessionDataTask
        
        init(dataTask: URLSessionDataTask) {
            self.dataTask = dataTask
            
            if scrolling
            {
                waitForScrolling()
            } else
            {
                suspendIfScrolling()
                self.dataTask.resume()
            }
        }
        
        @objc private func resume() {
            self.dataTask.resume()
            
            NotificationCenter.default.removeObserver(self, name: Notification.Name("scrolling-stopped"), object: nil)
            suspendIfScrolling()
        }
        
        @objc private func suspend() {
            self.dataTask.suspend()
            
            NotificationCenter.default.removeObserver(self, name: Notification.Name("scrolling-started"), object: nil)
            waitForScrolling()
        }
        
        func cancel() {
            self.dataTask.cancel()
        }
        
        func waitForScrolling() {
            NotificationCenter.default.addObserver(self, selector: #selector(resume), name: Notification.Name("scrolling-stopped"), object: nil)
        }
        
        func suspendIfScrolling() {
            NotificationCenter.default.addObserver(self, selector: #selector(suspend), name: Notification.Name("scrolling-started"), object: nil)
        }
        
    }
    
    // MARK: - Properties
    
    static let shared = AlbumArtCache()
    
    private var cache: NSCache<NSString, UIImage>
    private var downloads = [NSString:Downloader]()
    
    // MARK: - Initializer
    
    init() {
        self.cache = NSCache<NSString, UIImage>()
        self.cache.countLimit = 20
    }
    
    // MARK: - Loading
    
    private func loadImage(_ trackID: NSString, from url: URL, completion: @escaping (UIImage) -> Void) {
        if let img = cache.object(forKey: trackID)
        {
            completion(img)
            return
        }

        let dataTask = URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
            guard error == nil else {
                if (error! as NSError).code != -999
                {
                    print(error!)
                }
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
            
            self.cache.setObject(image, forKey: trackID)
            self.downloads.removeValue(forKey: trackID)
            
            completion(image)
        })
        
        downloads[trackID] = Downloader(dataTask: dataTask)
    }
    
    func loadImage(for track: QueuedTrack, completion: @escaping (UIImage) -> Void) {
        let trackID = NSString(string: track.trackID)
        loadImage(trackID, from: track.albumImageURL, completion: completion)
    }
    
    func loadImage(for track: SpotifyTrack, completion: @escaping (UIImage) -> Void) {
        let trackID = NSString(string: track.trackID)
        loadImage(trackID, from: track.albumImageURL, completion: completion)
    }
    
    // MARK - Cancelling
    
    func cancelDownload(for track: SpotifyTrack) {
        let trackID = NSString(string: track.trackID)
        
        guard
            let download = downloads[trackID]
            else
        {
            return
        }
        
        download.cancel()
        downloads.removeValue(forKey: trackID)
    }
    
    func cancelAllDownloads() {
        for (_, download) in downloads {
            download.cancel()
        }
        downloads = [NSString:Downloader]()
    }
    
}
