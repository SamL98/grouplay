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
        let query = "\"\(text)\""
        
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
    
    func checkForShowNoMatchLabel(trackArray: [Track]) {
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

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(MainViewController.searchTextUpdated(searchText:)), object: nil)
        perform(#selector(MainViewController.searchTextUpdated(searchText:)), with: searchText, afterDelay: 0.75)
    }
    
    @objc func searchTextUpdated(searchText: String) {
        self.segControlSearched = false
        self.searchInputText = searchText
        search(searchText: self.searchInputText)
    }

    func search(searchText: String) {
        //guard searchText.count >= 3 else {
            
            
        if searchText == "" {
            if segControl.selectedSegmentIndex == 0 {
                tracks = library
            }
            
            DispatchQueue.main.async {
                //if self.searched.count == 0 { self.showNoMatchLabel() }
                self.tableView.reloadData()
            }
            if segControl.selectedSegmentIndex == 0 {
                self.filteredLibrary = self.library
            }
            return
        }

        
        if segControl.selectedSegmentIndex == 0 {
            self.filteredLibrary = filterTracks(text: searchText, tracksToFilter: library)
            self.tracks = self.filteredLibrary
            
            DispatchQueue.main.async {
                self.checkForShowNoMatchLabel(trackArray: self.filteredLibrary)
                //if self.searched.count == 0 { self.showNoMatchLabel() }
                self.tableView.reloadData()
            }
        } else {
            fetchSearches(text: searchText) {
                self.tracks = self.searched
                
                DispatchQueue.main.async {
                    self.checkForShowNoMatchLabel(trackArray: self.tracks)
                    //if self.searched.count == 0 { self.showNoMatchLabel() }
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    func updateSegIfNecessary() {
        let text = self.searchBar.text
        if !isSearching || (text != nil && text!.count > 0) { return }
        searchBar(self.searchBar, textDidChange: text!)
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        isSearching = true
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.searchBar.resignFirstResponder()

        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        self.searchBar.resignFirstResponder()
        self.searchBar.endEditing(true)
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func filterTracks(text: String, tracksToFilter: [Track]) -> [Track] {
        return tracksToFilter.filter{
            $0.title.lowercased().contains(text.lowercased()) || $0.artist.lowercased().contains(text.lowercased())
        }
    }
    
}
