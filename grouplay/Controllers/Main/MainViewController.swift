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
    @IBOutlet weak var currTimeLabel: UILabel!
    
    @IBOutlet weak var playbackView: UIView!
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    
    var isOwner = false {
        didSet {
            if isOwner {
                SpotifyManager.shared.player.delegate = self
                SpotifyManager.shared.player.playbackDelegate = self
                
                if !UserDefaults.standard.bool(forKey: "sessInit") {
                    SpotifyManager.shared.initPlayer()
                    UserDefaults.standard.set(true, forKey: "sessInit")
                }
            }
        }
    }
    
    var current: Track! {
        didSet {
            guard current != nil else { return }
            self.saved = self.library.contains(where: { $0.trackID == current.trackID })
        }
    }
    var tracks = [Track]()
    var prev = [Track]()
    var library = [Track]()
    var searched = [Track]()
    
    var offsetCount = 0
    var timeLeft = 0 {
        didSet { currTimeLabel.text = Utility.formatSeconds(time: timeLeft) }
    }
    
    var firstPlayOccurred = false
    var paused = true {
        didSet {
            if isOwner {
                let title = paused ? "Play" : "Pause"
                pauseButton.setTitle(title, for: .normal)
                FirebaseManager.shared.updatePause(paused)
            }
        }
    }
    var timer: Timer!
    var timerStarted = false
    
    var currViewDisplayed = false
    var playbackDisplayed = false
    
    var swipe: UISwipeGestureRecognizer!
    var currTopConstr: NSLayoutConstraint!
    var currBottomConstr: NSLayoutConstraint!
    
    var arcLayer: ArcLayer!
    
    var isSearching = false
    var lastKeystroke: UInt64 = 0
    var searchInProgress = false
    
    var isLibSeg = true {
        didSet { updateSegIfNecessary() }
    }
    
    var saved = false {
        didSet {
            let img = saved ? #imageLiteral(resourceName: "001-checkmark") : UIImage(named: "002-add")
            saveButton.setImage(img!, for: .normal)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBar.delegate = self
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.keyboardDismissMode = .onDrag
        segControl.addTarget(self, action: #selector(MainViewController.updateSeg), for: .valueChanged)

        arcLayer = ArcLayer(frame: view.viewWithTag(421)!.frame)
        view.viewWithTag(421)?.layer.addSublayer(arcLayer)
        view.viewWithTag(421)?.clipsToBounds = false
        
        observeQueue()
        fetchLibrary()
        fetchCurr()
        
        paused = true
        
        currView.layer.masksToBounds = false
        currView.layer.shadowColor = UIColor.black.cgColor
        currView.layer.shadowOpacity = 0.65
        currView.layer.shadowRadius = 3.0
        currView.layer.shadowOffset = CGSize(width: 0.0, height: -10.0)
        
        playbackView.layer.masksToBounds = false
        playbackView.layer.shadowColor = UIColor.black.cgColor
        playbackView.layer.shadowOpacity = 0.65
        playbackView.layer.shadowRadius = 3.0
        playbackView.layer.shadowOffset = CGSize(width: 0.0, height: -10.0)
        
        swipe = UISwipeGestureRecognizer(target: self, action: #selector(MainViewController.revealPlayback))
        swipe.direction = .up
        if isOwner {
            currView.addGestureRecognizer(swipe)
            pauseButton.addTarget(self, action: #selector(togglePause), for: .touchUpInside)
            nextButton.addTarget(self, action: #selector(skip), for: .touchUpInside)
            backButton.addTarget(self, action: #selector(back), for: .touchUpInside)
        } else {
            playbackView.removeFromSuperview()
        }
        
        currView.frame.origin.y = tableView.frame.maxY + 8.0
        playbackView.frame.origin.y = view.bounds.height
        
        let constraints = view.constraints.filter({ $0.identifier != nil })
        currTopConstr = constraints.first(where: { $0.identifier! == "current-top" })
        currBottomConstr = constraints.first(where: { $0.identifier! == "current-bottom" })
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateTime), name: Notification.Name(rawValue: "update-time"), object: nil)
        if !isOwner {
            NotificationCenter.default.addObserver(self, selector: #selector(pausedChanged), name: Notification.Name(rawValue: "paused-changed"), object: nil)
        }
    }
    
    @objc func updateSeg() {
        isLibSeg = !isLibSeg
        if isSearching { isSearching = !isSearching }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let savedTimerState = UserDefaults.standard.object(forKey: "timerStarted") { timerStarted = savedTimerState as! Bool }

        if !timerStarted {
            timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(MainViewController.decrementTimer), userInfo: nil, repeats: true)
            timerStarted = true
            UserDefaults.standard.set(true, forKey: "timerStarted")
        }
    }
    
    @objc func decrementTimer() {
        if !paused {
            timeLeft -= 1
            if isOwner { updateTime() }
            arcLayer.animateArc()
        }
    }
    
    @objc func updateTime() {
        FirebaseManager.shared.setTimeLeft(timeLeft)
    }
    
    // MARK: Toolbar UI Methods
    
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
    
    func toggleCurrView(hide: Bool) {
        let multiplier: CGFloat = hide ? -1.0 : 1.0
        //currTopConstr.constant += (self.currView.bounds.height + 8.0) * multiplier
        currBottomConstr.constant += (self.currView.bounds.height + 8.0) * multiplier
        
        /*if currBottomConstr.constant == currTopConstr.constant {
            currBottomConstr.constant = 0
        }*/
        
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
    
    func updateCurrDisplay() {
        guard current != nil else {
            return
        }
        self.currTitleLabel.text = current.title
        self.currArtistLabel.text = current.artist
        //self.timeLeft = Int(current.duration/1000)
        
        Utility.loadImage(from: current.albumImageURL, completion: { img in
            DispatchQueue.main.async {
                self.currImageView.image = img
            }
        })
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
}
