//
//  MainViewController+API.swift
//  grouplay
//
//  Created by Sam Lerner on 5/10/18.
//  Copyright © 2018 Sam Lerner. All rights reserved.
//

import UIKit

extension MainViewController {
    
    func synchronizeWithBackend() {
        UserStore.current?.joinCurrentSession()
        SessionStore.current?.syncQueue()
        
        if !(UserStore.current?.isOwner() ?? false)
        {
            SessionStore.current?.syncCurrent()
        }
        else
        {
            updateCurrentUI()
        }
        
        observeDatabase()
    }
    
    func observeDatabase() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateCurrentUI),
                                               name: Notification.Name("current-changed"),
                                               object: nil)
    }
    
    func fetchLibrary() {
        SpotifyManager.shared.fetchLibrary(extraParameters: ["offset": (50 * offsetCount) as AnyObject], onCompletion: { (optTracksArr, error) in
            guard 
                error == nil 
            else 
            {
                print("Fetch library \(error!)")
                return
            }

            guard 
                let tracksArr = optTracksArr 
            else 
            {
                print("Tracks arr is nil")
                return
            }

            self.library.append(contentsOf: tracksArr)
            self.offsetCount += 1
            
            if !self.isSearching && self.searchInputText == ""
            {
                self.tracks = self.library
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
            
            if tracksArr.count == 50
            {
                self.fetchLibrary()
            }
        })
    }

}
