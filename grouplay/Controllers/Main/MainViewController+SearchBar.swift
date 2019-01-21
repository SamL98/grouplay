//
//  MainViewController+SearchBar.swift
//  grouplay
//
//  Created by Sam Lerner on 5/10/18.
//  Copyright © 2018 Sam Lerner. All rights reserved.
//

import UIKit


extension MainViewController {
    
    // The way searching and the segmented control works is as follows:
    //
    // a) If the selected index is 0, search through library
    //      i) If the search bar is open and the selected index switched, search through all of Spotify
    
    // MARK: - Searching
    
    func fetchSearches(text: String, completion: @escaping () -> Void) {
        let query = "\"\(text)\""
        
        SpotifyManager.shared.searchTracks(query: query, offset: 0) { (optTracksArr, error) in
            if let err = error
            {
                print(err)
                return
            }
            
            guard
                let tracksArr = optTracksArr
            else
            {
                print("Tracks are nil from search")
                return
            }

            self.searched = tracksArr
            completion()
        }
    }
    
    func search(searchText: String) {
        let onCompletion: () -> Void = {
            DispatchQueue.main.async {
                self.checkForShowNoMatchLabel(trackArray: self.tracks)
                self.tableView.reloadData()
            }
        }
        
        if segControl.selectedSegmentIndex == 0
        {
            lastLibrarySearchText = searchText
            tracks = library
            
            if searchText != ""
            {
                tracks = filterTracks(text: searchText, tracksToFilter: tracks)
            }
        }
        else
        {
            lastGlobalSearchText = searchText
            tracks = searched
            
            if searchText != ""
            {
                fetchSearches(text: searchText) {
                    self.tracks = self.searched
                    onCompletion()
                }
                return
            }
        }
        
        onCompletion()
    }
    
    // MARK: - Filtering
    
    func filterTracks(text: String, tracksToFilter: [SpotifyTrack]) -> [SpotifyTrack] {
        return tracksToFilter.filter{
            $0.title.lowercased().contains(text.lowercased()) || $0.artist.lowercased().contains(text.lowercased())
        }
    }
    
    // MARK: - No Match Label
    
    func checkForShowNoMatchLabel(trackArray: [SpotifyTrack]) {
        hideNoMatchLabel()
        if trackArray.count == 0 {
            showNoMatchLabel()
        }
    }
    
    func showNoMatchLabel() {
        let labelWidth: CGFloat = view.frame.width/3*2
        let label = UILabel(frame: CGRect(x: view.frame.midX-labelWidth/2, y: view.frame.midY-50.0, width: labelWidth, height: 100.0))
        label.text = "No tracks matching search"
        label.tag = 69
        label.textAlignment = .center
        view.addSubview(label)
    }
    
    func hideNoMatchLabel() {
        view.viewWithTag(69)?.removeFromSuperview()
    }
    
    // MARK: - Search Bar Delegate

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        NSObject.cancelPreviousPerformRequests(withTarget: self,
                                               selector: #selector(MainViewController.searchTextUpdated(searchText:)),
                                               object: nil)
        perform(#selector(MainViewController.searchTextUpdated(searchText:)),
                with: searchText,
                afterDelay: 0.5)
    }
    
    @objc func searchTextUpdated(searchText: String) {
        print("Searching for: \(searchText).")
        searchInputText = searchText
        search(searchText: self.searchInputText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchBar.endEditing(true)
    }
    
}
