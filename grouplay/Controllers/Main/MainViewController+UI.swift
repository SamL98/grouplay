//
//  MainViewController+UI.swift
//  grouplay
//
//  Created by Sam Lerner on 1/20/19.
//  Copyright © 2019 Sam Lerner. All rights reserved.
//

import UIKit

extension MainViewController {
    
    func initializeSwipe() {
        tableView.keyboardDismissMode = .onDrag
        swipe = UISwipeGestureRecognizer(target: self, action: #selector(MainViewController.revealPlayback))
        swipe.direction = .up
    }
    
    func initializeUI() {
        initializeCurrView()
        initializePlaybackView()
        
        currView.frame.origin.y = tableView.frame.maxY + 8.0
        playbackView.frame.origin.y = view.bounds.height
    }
    
    func getAutoLayoutConstraints() {
        let constraints = view.constraints.filter({ $0.identifier != nil })
        currTopConstr = constraints.first(where: { $0.identifier! == "current-top" })
        currBottomConstr = constraints.first(where: { $0.identifier! == "current-bottom" })
    }
    
    @objc func updateCurrentUI() {
        DispatchQueue.main.async {
            self.updateCurrDisplay()
            self.showCurrView()
        }
    }
    
    func updateCurrDisplay() {
        guard let current = SessionStore.current?.current else { return }
        
        self.currTitleLabel.text = current.title
        self.currArtistLabel.text = current.artist
        self.saved = library.contains(where: { $0.trackID == current.trackID })
        
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
    
    func showEnqueueCompletionView() {
        showQueueActionCompletionView(image: UIImage(named: "checkmark")!)
    }
    
    func showDequeueCompletionView() {
        showQueueActionCompletionView(image: UIImage(named: "close")!)
    }
    
    func showQueueActionCompletionView(image: UIImage) {
        let size: CGFloat = 75.0
        let completionView = UIView(frame: CGRect(x: view.bounds.midX-size/2.0, y: view.bounds.midY-size/2.0, width: size, height: size))
        completionView.backgroundColor = UIColor.lightGray
        completionView.layer.cornerRadius = 5.0
        completionView.alpha = 0.65
        
        let padding: CGFloat = 15.0
        let imgView = UIImageView(frame: CGRect(x: padding, y: padding, width: size - 2*padding, height: size - 2*padding))
        imgView.backgroundColor = UIColor.clear
        imgView.image = image
        
        completionView.addSubview(imgView)
        view.addSubview(completionView)
        
        Timer(fire: Date(timeIntervalSinceNow: 3.0), interval: 0.0, repeats: false, block: { timer in
            UIView.animate(withDuration: 1.5, animations: {
                completionView.alpha = 0.0
            }, completion: { _ in
                completionView.removeFromSuperview()
            })
            
            timer.invalidate()
        }).fire()
    }
    
}
