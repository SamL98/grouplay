//
//  MainViewController.swift
//  grouplay
//
//  Created by Sam Lerner on 12/8/17.
//  Copyright © 2017 Sam Lerner. All rights reserved.
//

import UIKit

class MainViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var segControl: UISegmentedControl!
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var currView: UIView!
    @IBOutlet weak var currImageView: UIImageView!
    @IBOutlet weak var currTitleLabel: UILabel!
    @IBOutlet weak var currArtistLabel: UILabel!
    @IBOutlet weak var currTimeLabel: UILabel!
    
    var session: Session!
    
    var current: Track!
    var tracks = [Track]()
    var library = [Track]()
    var searched = [Track]()
    
    private var offsetCount = 0
    private var timeLeft = 0 {
        willSet {
            if timeLeft <= 0 {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime(uptimeNanoseconds: 1 * 1000 * 1000 * 1000), execute: {
                    self.fetchCurr()
                })
            }
        }
        didSet {
            currTimeLabel.text = "\(timeLeft)"
        }
    }
    var timer: Timer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBar.delegate = self
        tableView.dataSource = self
        
        fetchLibrary()
        fetchCurr()
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
            
            if let text = self.searchBar.text {
                if text == "" {
                    self.tracks = self.library
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                }
            } else {
                self.tracks = self.library
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        })
    }
    
    func fetchCurr() {
        SpotifyManager.shared.fetchCurrent { track, time, err in
            guard err == nil else {
                print(err!)
                self.currView.isHidden = true
                return
            }
            guard track != nil else {
                self.currView.isHidden = true
                return
            }
            self.currView.isHidden = false
            self.current = track!
            self.timeLeft = time == nil ? track!.duration : time!
            self.timer = Timer(timeInterval: 1.0, repeats: true, block: { _ in
                self.timeLeft -= 1
            })
            self.timer.fire()
            DispatchQueue.main.async {
                self.updateCurrDisplay()
            }
        }
    }
    
    func updateCurrDisplay() {
        guard current != nil else {
            return
        }
        self.currTitleLabel.text = current.title
        self.currArtistLabel.text = current.artist
        
        print(current.albumImageURL)
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
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        view.viewWithTag(69)?.removeFromSuperview()
        
        guard NSString(string: searchText).length >= 2 else {
            return
        }
        
        if segControl.selectedSegmentIndex == 0 {
            filterTracks(text: searchText, tracksToFilter: library)
            tableView.reloadData()
        } else {
            fetchSearches(text: searchText) {
                _ = self.searched.map { print($0.title) }
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
        }
    }
    
    func filterTracks(text: String, tracksToFilter: [Track]) {
        tracks = tracksToFilter.filter{ $0.title.lowercased().contains(text.lowercased()) }
    }

}
