//
//  MainViewController+SearchBar.swift
//  grouplay
//
//  Created by Sam Lerner on 5/10/18.
//  Copyright © 2018 Sam Lerner. All rights reserved.
//

import UIKit


extension MainViewController {
    
    func fetchSearches(text: String, completion: @escaping () -> Void) {
        let query = text.lowercased().replacingOccurrences(of: " ", with: "+")
        SpotifyManager.shared.searchTracks(query: query, offset: 0) { (optTracksArr, error) in
            guard error == nil else {
                print("\(error!)")
                return
            }
            guard let tracksArr = optTracksArr else {
                print("tracks are nil from search")
                return
            }

            self.searched = tracksArr
            completion()
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        view.viewWithTag(69)?.removeFromSuperview()
        
        guard NSString(string: searchText).length >= 2 else {
            if searchText == "" {
                self.searchBar.resignFirstResponder()
                self.tracks = self.library
                DispatchQueue.main.async {
                    self.segControl.selectedSegmentIndex = 0
                    self.tableView.reloadData()
                }
            }
            return
        }
        
        if segControl.selectedSegmentIndex == 0 {
            filterTracks(text: searchText, tracksToFilter: library)
            tableView.reloadData()
        } else {
            fetchSearches(text: searchText) {
                //_ = self.searched.map { print($0.title) }
                self.tracks = self.searched
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        }
        
        if tracks.count == 0 {
            let labelWidth: CGFloat = view.frame.width/3*2
            let label = UILabel(frame: CGRect(x: view.frame.midX-labelWidth/2, y: view.frame.midY-50.0, width: labelWidth, height: 100.0))
            label.text = "No tracks matching search"
            label.tag = 69
            label.textAlignment = .center
            view.addSubview(label)
        } else {
            view.viewWithTag(69)?.removeFromSuperview()
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        print("canceled")
        self.searchBar.resignFirstResponder()
        self.tracks = self.library
        DispatchQueue.main.async {
            self.segControl.selectedSegmentIndex = 0
            self.tableView.reloadData()
        }
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        print("end editing")
        self.searchBar.resignFirstResponder()
        self.searchBar.endEditing(true)
        self.tracks = self.library
        DispatchQueue.main.async {
            self.segControl.selectedSegmentIndex = 0
            self.tableView.reloadData()
        }
    }
    
    func filterTracks(text: String, tracksToFilter: [Track]) {
        tracks = tracksToFilter.filter{
            $0.title.lowercased().contains(text.lowercased()) || $0.artist.lowercased().contains(text.lowercased())
        }
    }
    
}
