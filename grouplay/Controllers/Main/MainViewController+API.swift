//
//  MainViewController+API.swift
//  grouplay
//
//  Created by Sam Lerner on 5/10/18.
//  Copyright © 2018 Sam Lerner. All rights reserved.
//

import UIKit

extension MainViewController {
    
    func fetchLibrary() {
        guard offsetCount <= 10 else {
            return
        }
        SpotifyManager.shared.fetchLibrary(extraParameters: ["offset": (50 * offsetCount) as AnyObject], onCompletion: { (optTracksArr, error) in
            guard error == nil else {
                print("\(error!)")
                return
            }
            guard let tracksArr = optTracksArr else {
                return
            }
            self.library.append(contentsOf: tracksArr)
            self.offsetCount += 1
            self.fetchLibrary()
            
            if self.searchBar.text == nil || self.searchBar.text! == "" {
                self.tracks = self.library
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        })
    }
    
    func fetchCurr() {
        guard let uid = UserDefaults.standard.string(forKey: "uid") else {
            print("no uid")
            return
        }
        guard let session = SessionStore.session else {
            print("no session")
            return
        }
        if uid == session.owner {
            SpotifyManager.shared.fetchCurrent { track, time, err in
                self.parseCurr(track: track, time: time, err: err)
            }
        } else {
            FirebaseManager.shared.fetchCurrent { track, time, err in
                self.parseCurr(track: track, time: time, err: err)
            }
        }
    }
    
    func parseCurr(track: Track?, time: Int?, err: NSError?) {
        guard err == nil else {
            print(err!)
            self.currViewDisplayed = true
            self.hideCurrView()
            return
        }
        guard track != nil else {
            self.hideCurrView()
            return
        }
        self.current = track!
        self.timeLeft = time == nil ? track!.duration : time!
        
        DispatchQueue.main.async {
            self.paused = false
            self.showCurrView()
            self.updateCurrDisplay()
            SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + self.current.trackID, startingWith: 0, startingWithPosition: 0.0, callback: {_ in
                //self.queueApproved()
            })
        }
    }
    
}
