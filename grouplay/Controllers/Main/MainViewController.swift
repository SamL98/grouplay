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
    
    var offsetCount = 0
    var timeLeft = 0 {
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        paused = true
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(MainViewController.decrementTimer), userInfo: nil, repeats: true)
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

}
