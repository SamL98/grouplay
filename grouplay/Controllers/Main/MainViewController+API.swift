//
//  MainViewController+API.swift
//  grouplay
//
//  Created by Sam Lerner on 5/10/18.
//  Copyright © 2018 Sam Lerner. All rights reserved.
//

import UIKit

extension MainViewController {
    
    func observeQueue() {
        guard let sess = SessionStore.session else { return }
        FirebaseManager.shared.observeQueue(sess: sess, eventOccurred: { needsUpdate in
            if needsUpdate { NotificationCenter.default.post(name: Notification.Name(rawValue: "queue-changed"), object: nil) }
        })
    }
    
    func fetchLibrary() {
        //guard offsetCount <= 10 else { return }
        SpotifyManager.shared.fetchLibrary(extraParameters: ["offset": (50 * offsetCount) as AnyObject], onCompletion: { (optTracksArr, error) in
            guard error == nil else {
                print("fetch library \(error!)")
                return
            }
            guard let tracksArr = optTracksArr else {
                print("tracks arr is nil")
                return
            }

            self.library.append(contentsOf: tracksArr)
            
            // Set the current track to itself so that its didSet will be triggered
            // and saved will be updated.
            //
            // This is needed because the save will initially be set when the library array is empty.
            let curr = self.current
            self.current = curr
            
            self.offsetCount += 1
            self.fetchLibrary()
            
            if !self.isSearching && (self.searchBar.text == nil || self.searchBar.text! == "") {
                self.tracks = self.library
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        })
    }
    
    // Fetch curr will call once is isOwner, listen otherwise
    func fetchCurr() {
        FirebaseManager.shared.fetchCurrent(isOwner: isOwner) { track, time, paused, err in
            self.parseCurr(track: track, time: time, paused: paused, err: err)
        }
    }
    
    func parseCurr(track: Track?, time: Int?, paused: Bool?, err: NSError?) {
        guard err == nil else {
            print("parsing curr: \(err!)")
            self.currViewDisplayed = true
            self.hideCurrView()
            return
        }
        
        guard track != nil && paused != nil else {
            self.hideCurrView()
            return
        }
        
        DispatchQueue.main.async {
            self.current = track!
            if time != nil {
                self.timeLeft = time!
            } else if track != nil {
                self.timeLeft = track!.duration
            }
        }
    }
    
}
