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
        SpotifyManager.shared.fetchLibrary(extraParameters: ["offset": (50 * offsetCount) as AnyObject], onCompletion: { (optTracksArr, error) in
            guard 
                error == nil 
            else 
            {
                print("fetch library \(error!)")
                return
            }

            guard 
                let tracksArr = optTracksArr 
            else 
            {
                print("tracks arr is nil")
                return
            }

            self.library.append(contentsOf: tracksArr)
            
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

}
