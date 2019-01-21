//
//  MainViewController.swift
//  grouplay
//
//  Created by Sam Lerner on 12/8/17.
//  Copyright © 2017 Sam Lerner. All rights reserved.
//

import UIKit
import MediaPlayer

class MainViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, SPTAudioStreamingDelegate, SPTAudioStreamingPlaybackDelegate {
    
    // MARK: - Outlets

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var segControl: UISegmentedControl!
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var currView: UIView!
    @IBOutlet weak var currImageView: UIImageView!
    @IBOutlet weak var currTitleLabel: UILabel!
    @IBOutlet weak var currArtistLabel: UILabel!
    
    @IBOutlet weak var playbackView: UIView!
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    
    // MARK: - Properties
    
    var isOwner = false {
        didSet {
            if isOwner && !UserDefaults.standard.bool(forKey: "sessInit")
            {
                SpotifyManager.shared.initPlayer()
                UserDefaults.standard.set(true, forKey: "sessInit")
            }
        }
    }
    
    var offsetCount = 0 // offset count for fetching the user's library
    
    // MARK: - Track Arrays
    
    var tracks = [SpotifyTrack]() // the tracks to be displayed in the tableview
    var prev = [QueuedTrack]() // the previous tracks played so that the owner can go to the previous song indefinitely
    var library = [SpotifyTrack]() // the current user's library
    var searched = [SpotifyTrack]() // the result of the current search if searching
    var filteredLibrary = [SpotifyTrack]()
    
    var isSearching = false
    var lastLibrarySearchText = ""
    var lastGlobalSearchText = ""
    var searchInputText = ""
    
    // MARK: - Playback Properties
    
    var firstPlayOccurred = false    
    var paused = true {
        didSet {
            guard isOwner else { return }
            
            MPNowPlayingInfoCenter.default().playbackState = paused ? .paused : .playing
            pauseButton.setTitle(paused ? "Play" : "Pause", for: .normal)
        }
    }
    
    // MARK: - Current / Playback View Properties
    
    var currViewDisplayed = false
    var playbackDisplayed = false
    
    var swipe: UISwipeGestureRecognizer! // the swipe to display/dismiss the playback view
    var currTopConstr: NSLayoutConstraint! // top constraint of the current view
    var currBottomConstr: NSLayoutConstraint! // bottom constraint of the current view
    
    var saved = false {
        didSet {
            saveButton.setImage(saved ? #imageLiteral(resourceName: "001-checkmark") : UIImage(named: "002-add")!, for: .normal)
        }
    }
    
    // MARK: - MediaPlayer Properties
    
    var nowPlayingInfo = [String:Any]()
    let albumName = ""
    let albumArtist = ""
    let playbackRate = 1.0
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBar.delegate = self
        tableView.dataSource = self
        tableView.delegate = self
        
        initializeSwipe()
        initializeUI()
        getAutoLayoutConstraints()
        
        synchronizeWithBackend()
        fetchLibrary()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.topItem?.title = SessionStore.current?.name ?? ""
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !isOwner { return }
        
        SpotifyManager.shared.player.delegate = self
        SpotifyManager.shared.player.playbackDelegate = self
    }
    
    // MARK: - Outlet Actions
    
    @IBAction func toggleSave(_ sender: UIButton) {
        guard let current = SessionStore.current?.current else { return }
        let spCurrent = SpotifyTrack.spotifyTrackFrom(current)
        
        if saved {
            guard let idx = self.library.index(where: { $0.trackID == current.trackID }) else { return }
            self.library.remove(at: idx)
            SpotifyManager.shared.unsave(spCurrent)
        } else {
            self.library.insert(spCurrent, at: 0)
            SpotifyManager.shared.save(spCurrent)
        }

        saved = !saved
    }
    
    @IBAction func goBack(_ sender: UIBarButtonItem) {
        UserStore.current?.leaveCurrentSession()
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func segControlSwitch(_ sender: Any) {
        // searchControlSearched is a flag that specifies whether or not the latest search bar edit has been searched.
        // Therefore, if the control is switched, and the latest search hasn't been executed, then search.
        // Otherwise, just set tracks and reload the table view as one would expect.
        
        AlbumArtCache.shared.cancelAllDownloads()
        
        let latestInput = segControl.selectedSegmentIndex == 0 ? lastLibrarySearchText : lastGlobalSearchText
        
        isSearching = segControl.selectedSegmentIndex == 1
        
        if
            latestInput != searchInputText &&
            (!isSearching || searchInputText != "")
        {
            search(searchText: self.searchInputText)
        }
        else
        {
            DispatchQueue.main.async {
                if self.segControl.selectedSegmentIndex == 0
                {
                    self.tracks = self.filteredLibrary
                }
                else
                {
                    self.tracks = self.searched
                }
                
                self.checkForShowNoMatchLabel(trackArray: self.tracks)
                self.tableView.reloadData()
            }
        }
    }
}
