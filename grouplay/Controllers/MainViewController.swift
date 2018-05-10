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
    
    var isOwner = false {
        didSet {
            if isOwner {
                SpotifyManager.shared.player.delegate = self
                SpotifyManager.shared.player.playbackDelegate = self
                SpotifyManager.shared.initPlayer()
            }
        }
    }
    
    var current: Track!
    var tracks = [Track]()
    var library = [Track]()
    var searched = [Track]()
    
    private var offsetCount = 0
    private var timeLeft = 0 {
        /*willSet {
            if timeLeft <= 0 {
                if let session = SessionStore.session, session.approved.count > 0 {
                    let nextUp = session.approved.last!
                    FirebaseManager.shared.dequeue(nextUp, pending: false)
                    SpotifyManager.shared.play(nextUp) { success in
                        self.fetchCurr()
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime(uptimeNanoseconds: 1 * 1000 * 1000 * 100), execute: {
                        self.fetchCurr()
                    })
                }
            }
        }*/
        didSet { currTimeLabel.text = Utility.formatSeconds(time: timeLeft) }
    }
    
    var firstPlayOccurred = false
    var paused = true {
        didSet {
            let title = paused ? "Play" : "Pause"
            pauseButton.setTitle(title, for: .normal)
        }
    }
    var timer: Timer!
    
    var currViewDisplayed = true
    var playbackDisplayed = false
    
    var swipe: UISwipeGestureRecognizer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBar.delegate = self
        tableView.dataSource = self
        tableView.delegate = self
        
        currView.layer.masksToBounds = false
        currView.layer.shadowColor = UIColor.black.cgColor
        currView.layer.shadowPath = UIBezierPath(rect: CGRect(x: 0.0, y: currView.frame.origin.y - 7.5, width: view.bounds.width, height: 7.5)).cgPath
        currView.layer.shadowOpacity = 0.75
        currView.layer.shadowOffset = CGSize.zero
        
        fetchLibrary()
        fetchCurr()
        
        swipe = UISwipeGestureRecognizer(target: self, action: #selector(MainViewController.revealPlayback))
        swipe.direction = .up
        currView.addGestureRecognizer(swipe)
        
        pauseButton.addTarget(self, action: #selector(togglePause), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(skip), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(back), for: .touchUpInside)
        
        currView.frame.origin.y = tableView.frame.maxY + 8.0
        playbackView.frame.origin.y = view.bounds.height
    }
    
    func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController!) {
        print("streaming logged in")
        UserDefaults.standard.set(true, forKey: "stream-logged-in")
    }
    
    func queueApproved() {
        for track in SessionStore.session!.approved {
            print("queueing \(track.trackID)")
            SpotifyManager.shared.player.queueSpotifyURI("spotify:track:" + track.trackID, callback: nil)
        }
    }
    
    func audioStreamingDidPopQueue(_ audioStreaming: SPTAudioStreamingController!) {
        print("queue popped")
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didStartPlayingTrack trackUri: String!) {
        guard let nextUp = SessionStore.session!.approved.first(where: { "spotify:track:" + $0.trackID == trackUri }) else {
            print("could not find track in session: \(trackUri!)")
            return
        }
        FirebaseManager.shared.dequeue(nextUp, pending: false)
        SessionStore.session!.approved = SessionStore.session!.approved.filter({ $0.trackID != nextUp.trackID })
        
        showCurrView()
        current = nextUp
        timeLeft = Int(current.duration/1000)
        updateCurrDisplay()
        
        FirebaseManager.shared.setCurrent(current, timeLeft: timeLeft)
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didStopPlayingTrack trackUri: String!) {
        let nextUp = SessionStore.session!.approved[0].trackID
        SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + nextUp, startingWith: 0, startingWithPosition: 0.0, callback: nil)
    }
    
    func audioStreamingDidSkip(toNextTrack audioStreaming: SPTAudioStreamingController!) {
        
    }
    
    func audioStreamingDidSkip(toPreviousTrack audioStreaming: SPTAudioStreamingController!) {
        
    }
    
    @objc func revealPlayback() {
        playbackDisplayed = !playbackDisplayed
        let multiplier: CGFloat = playbackDisplayed ? 1.0 : -1.0
        
        guard let topConstr = view.constraints.filter({ $0.identifier != nil }).first(where: { $0.identifier! == "current-top" }),
            let bottomConstr = view.constraints.filter({ $0.identifier != nil }).first(where: { $0.identifier! == "current-bottom" }) else {
                print("could not find constraint")
                return
        }
        topConstr.constant += self.playbackView.frame.height * multiplier
        bottomConstr.constant += self.playbackView.frame.height * multiplier
        UIView.animate(withDuration: 0.25, animations: {
            //self.currView.frame.origin.y -= self.playbackView.frame.height * multiplier
            //self.playbackView.frame.origin.y -= self.playbackView.frame.height * multiplier
            self.view.layoutIfNeeded()
        }, completion: {_ in
            self.swipe.direction = self.playbackDisplayed ? .down : .up
        })
    }
    
    func hideCurrView() {
        if !currViewDisplayed { return }
        currViewDisplayed = false
        
        guard let topConstr = view.constraints.filter({ $0.identifier != nil }).first(where: { $0.identifier! == "current-top" }),
            let bottomConstr = view.constraints.filter({ $0.identifier != nil }).first(where: { $0.identifier! == "current-bottom" }) else {
            print("could not find constraint")
            return
        }
        topConstr.constant -= self.currView.bounds.height + 8.0
        bottomConstr.constant -= self.currView.bounds.height + 8.0
        UIView.animate(withDuration: 0.35, animations: {
            //self.currView.frame.origin.y += self.currView.bounds.height + 8.0
            self.view.layoutIfNeeded()
            //self.tableView.frame.size.height += self.currView.bounds.height + 8.0
        })
    }
    
    func showCurrView() {
        if currViewDisplayed { return }
        currViewDisplayed = true

        guard let topConstr = view.constraints.filter({ $0.identifier != nil }).first(where: { $0.identifier! == "current-top" }),
            let bottomConstr = view.constraints.filter({ $0.identifier != nil }).first(where: { $0.identifier! == "current-bottom" }) else {
                print("could not find constraint")
                return
        }
        topConstr.constant += self.currView.bounds.height + 8.0
        bottomConstr.constant += self.currView.bounds.height + 8.0
        UIView.animate(withDuration: 0.35, animations: {
            //self.currView.frame.origin.y = self.view.bounds.height - 8.0 - self.currView.frame.size.height
            self.view.layoutIfNeeded()
            //self.tableView.frame.size.height -= 8.0 + self.currView.frame.size.height
        })
    }
    
    @objc func togglePause() {
        //SpotifyManager.shared.togglePause()
        guard current != nil else {
            return
        }
        if !firstPlayOccurred && paused {
            firstPlayOccurred = true
            SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + current!.trackID, startingWith: 0, startingWithPosition: 0.0, callback: nil)
        }
        SpotifyManager.shared.player.setIsPlaying(paused, callback: nil)
        paused = !paused
    }
    
    @objc func skip() {
        //SpotifyManager.shared.nextTrack()
        //SpotifyManager.shared.player.skipNext(nil)
        timeLeft = 0
    }
    
    @objc func back() {
        //SpotifyManager.shared.player.skipPrevious(nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        paused = true
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(MainViewController.decrementTimer), userInfo: nil, repeats: true)
    }
    
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
    
    @objc func decrementTimer() {
        if !paused {
            timeLeft -= 1
        }
    }
    
    func updateCurrDisplay() {
        guard current != nil else {
            return
        }
        self.currTitleLabel.text = current.title
        self.currArtistLabel.text = current.artist
        self.timeLeft = Int(current.duration/1000)
        
        Utility.loadImage(from: current.albumImageURL, completion: { img in
            DispatchQueue.main.async {
                self.currImageView.image = img
            }
        })
    }
    
    func fetchSearches(text: String, completion: @escaping () -> Void) {
        guard let query = text.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
            completion()
            return
        }
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
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tracks.count
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "trackCell")!
        guard let trackCell = cell as? TrackTableViewCell else {
            return cell
        }
        
        let track = tracks[indexPath.row]
        trackCell.titleLabel.text = track.title
        trackCell.artistLabel.text = track.artist
        
        trackCell.track = track
        trackCell.imageURL = track.albumImageURL
        
        return trackCell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isOwner {
            SpotifyManager.shared.player.playSpotifyURI("spotify:track:" + tracks[indexPath.row].trackID, startingWith: 0, startingWithPosition: 0.0, callback: {_ in
                self.paused = false
                self.current = self.tracks[indexPath.row]
                self.showCurrView()
                self.updateCurrDisplay()
                //self.queueApproved()
            })
        }
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let action = UITableViewRowAction(style: .normal, title: "Enqueue", handler: { _, indexPath in
            FirebaseManager.shared.enqueue(self.tracks[indexPath.row], pending: !self.isOwner)
            if self.isOwner {
                //SpotifyManager.shared.player.queueSpotifyURI("spotify:track:" + self.tracks[indexPath.row].trackID, callback: nil)
                SessionStore.session!.approved.append(self.tracks[indexPath.row])
            }
        })
        return [action]
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        view.viewWithTag(69)?.removeFromSuperview()
        
        guard NSString(string: searchText).length >= 2 else {
            if searchText == "" {
                self.tracks = self.library
                DispatchQueue.main.async {
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
    
    func filterTracks(text: String, tracksToFilter: [Track]) {
        tracks = tracksToFilter.filter{ $0.title.lowercased().contains(text.lowercased()) }
    }

}
