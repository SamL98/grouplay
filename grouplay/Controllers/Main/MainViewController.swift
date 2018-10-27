//
//  MainViewController.swift
//  grouplay
//
//  Created by Sam Lerner on 12/8/17.
//  Copyright © 2017 Sam Lerner. All rights reserved.
//

import UIKit

class MainViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, SPTAudioStreamingDelegate, SPTAudioStreamingPlaybackDelegate {

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
    
    var isOwner = false {
        didSet {
            guard isOwner else { return }
            
            if !UserDefaults.standard.bool(forKey: "sessInit") {
                SpotifyManager.shared.initPlayer()
                UserDefaults.standard.set(true, forKey: "sessInit")
            }
        }
    }
    
    // When the current track is set, we want to:
    //
    // 1. update the current view display with the track info (includes saved button)
    // 2. set the track as the current in the database if the current user is the owner
    // 3. show the current view
    var current: Track! {
        didSet {
            guard current != nil else { return }
            
            updateCurrDisplay(with: current)
            setCurrInDB(current)
            showCurrView()
            
            timeLeft = Int(current.duration/1000)
        }
    }
    
    var tracks = [Track]() // the tracks to be displayed in the tableview
    var prev = [Track]() // the previous tracks played so that the owner can go to the previous song indefinitely
    var library = [Track]() // the current user's library
    var searched = [Track]() // the result of the current search if searching
    
    var offsetCount = 0 // offset count for fetching the user's library
    
    // Time left in the current track
    var timeLeft = 0
    
    var firstPlayOccurred = false
    
    // When we update pause, we want to do one thing:
    //
    // 1. Update the title of the toggle pause button
    var paused = true {
        didSet {
            guard isOwner else { return }
            
            let title = paused ? "Play" : "Pause"
            pauseButton.setTitle(title, for: .normal)
        }
    }
    
    var timer: Timer!
    var timerStarted = false
    
    var currViewDisplayed = false
    var playbackDisplayed = false
    
    var swipe: UISwipeGestureRecognizer! // the swipe to display/dismiss the playback view
    var currTopConstr: NSLayoutConstraint! // top constraint of the current view
    var currBottomConstr: NSLayoutConstraint! // bottom constraint of the current view
    
    var isSearching = false {
        didSet {
            if !isSearching && searchBar.isFirstResponder {
                searchBar.resignFirstResponder()
            }
        }
    }
    
    // Whether or not the current selected segment is the library segment
    var isLibSeg = true {
        didSet { updateSegIfNecessary() }
    }
    
    // Whether or not the current track is saved in the user's library
    var saved = false {
        didSet {
            let img = saved ? #imageLiteral(resourceName: "001-checkmark") : UIImage(named: "002-add")
            saveButton.setImage(img!, for: .normal)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.navigationBar.topItem?.title = SessionStore.session?.id ?? ""
        
        paused = true
        
        searchBar.delegate = self
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.keyboardDismissMode = .onDrag
        
        swipe = UISwipeGestureRecognizer(target: self, action: #selector(MainViewController.revealPlayback))
        swipe.direction = .up
        
        initializeCurrView()
        initializePlaybackView()
        
        currView.frame.origin.y = tableView.frame.maxY + 8.0
        playbackView.frame.origin.y = view.bounds.height
        
        let constraints = view.constraints.filter({ $0.identifier != nil })
        currTopConstr = constraints.first(where: { $0.identifier! == "current-top" })
        currBottomConstr = constraints.first(where: { $0.identifier! == "current-bottom" })
        
        // *** Interact with the backend ***
        
        observeQueue()
        fetchLibrary()
        fetchCurr()
        observePaused()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // We only want to start the timer if we are the owner of the session
        if !isOwner { return }
        
        SpotifyManager.shared.player.delegate = self
        SpotifyManager.shared.player.playbackDelegate = self
        
        // If the app is entering the foreground after resigning active, then the timer will have been invalidated
        // therefore, we want to start the timer again in that case.
        if let savedTimerState = UserDefaults.standard.object(forKey: "timerStarted") { timerStarted = savedTimerState as! Bool }

        if !timerStarted {
            timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(MainViewController.decrementTimer), userInfo: nil, repeats: true)
            timerStarted = true
            UserDefaults.standard.set(true, forKey: "timerStarted")
        }
    }
    
    // MARK: Timer Methods
    
    @objc func decrementTimer() {
        if !paused { timeLeft -= 1 }
    }
    
    // MARK: current didSet
    
    func setCurrInDB(_ track: Track) {
        guard isOwner else { return }
        FirebaseManager.shared.setCurrent(track)
    }
    
    func updateCurrDisplay(with track: Track) {
        self.currTitleLabel.text = current.title
        self.currArtistLabel.text = current.artist
        self.saved = library.contains(where: { $0.trackID == track.trackID })
        
        Utility.loadImage(from: current.albumImageURL, completion: { img in
            DispatchQueue.main.async {
                self.currImageView.image = img
            }
        })
    }
    
    func toggleCurrView(hide: Bool) {
        let multiplier: CGFloat = hide ? -1.0 : 1.0
        currBottomConstr.constant += (self.currView.bounds.height + 8.0) * multiplier
        
        UIView.animate(withDuration: 0.35, animations: { self.view.layoutIfNeeded() })
    }
    
    func hideCurrView() {
        if !currViewDisplayed { return }
        currViewDisplayed = false
        
        guard currTopConstr != nil && currBottomConstr != nil else {
            print("could not find constraint")
            return
        }
        toggleCurrView(hide: true)
    }
    
    func showCurrView() {
        if currViewDisplayed { return }
        currViewDisplayed = true

        guard currTopConstr != nil && currBottomConstr != nil else {
            print("could not find constraint")
            return
        }
        toggleCurrView(hide: false)
    }
    
    func initializeCurrView() {
        currView.layer.masksToBounds = false
        currView.layer.shadowColor = UIColor.black.cgColor
        currView.layer.shadowOpacity = 0.65
        currView.layer.shadowRadius = 3.0
        currView.layer.shadowOffset = CGSize(width: 0.0, height: -10.0)
    }
    
    @objc func revealPlayback() {
        playbackDisplayed = !playbackDisplayed
        let multiplier: CGFloat = playbackDisplayed ? 1.0 : -1.0
        
        guard currTopConstr != nil && currBottomConstr != nil else {
            print("could not find constraint")
            return
        }
        
        currTopConstr.constant -= self.playbackView.frame.height * multiplier
        currBottomConstr.constant += self.playbackView.frame.height * multiplier
        
        UIView.animate(withDuration: 0.25, animations: {
            self.view.layoutIfNeeded()
        }, completion: {_ in
            self.swipe.direction = self.playbackDisplayed ? .down : .up
        })
    }
    
    func initializePlaybackView() {
        playbackView.layer.masksToBounds = false
        playbackView.layer.shadowColor = UIColor.black.cgColor
        playbackView.layer.shadowOpacity = 0.65
        playbackView.layer.shadowRadius = 3.0
        playbackView.layer.shadowOffset = CGSize(width: 0.0, height: -10.0)
        
        if isOwner {
            currView.addGestureRecognizer(swipe)
            pauseButton.addTarget(self, action: #selector(togglePause), for: .touchUpInside)
            nextButton.addTarget(self, action: #selector(skip), for: .touchUpInside)
            backButton.addTarget(self, action: #selector(back), for: .touchUpInside)
        } else {
            playbackView.removeFromSuperview()
        }
    }
    
    @IBAction func toggleSave(_ sender: UIButton) {
        guard current != nil else {
            print("no current, stop saving")
            return
        }
        
        if saved {
            guard let idx = self.library.index(where: { $0.trackID == current.trackID }) else { return }
            self.library.remove(at: idx)
            SpotifyManager.shared.unsave(self.current)
        } else {
            self.library.insert(current, at: 0)
            SpotifyManager.shared.save(self.current)
        }
        saved = !saved
    }
    
    @IBAction func goBack(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func segControlSwitch(_ sender: Any) {
        if self.segControl.selectedSegmentIndex == 0 {
            self.tracks = self.library
        } else {
            self.tracks = self.searched
        }
        DispatchQueue.main.async {
            if self.tracks.count == 0 {
                self.tracks = self.searched
                self.showNoMatchLabel()
            } else {
                self.hideNoMatchLabel()
            }
            self.tableView.reloadData()
            print("DATA RELOADED")
        }
        print(self.tracks.count)
    }
}
