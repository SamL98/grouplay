//
//  MainViewController+Scroll.swift
//  grouplay
//
//  Created by Sam Lerner on 1/20/19.
//  Copyright © 2019 Sam Lerner. All rights reserved.
//

import UIKit

extension MainViewController {
    
    // This is my attempt at providing a smooth scrolling experience without flickering.
    //
    // 1. When the reusable cell is dequeued, get the album art from the cache.
    //      a. If it needs to be downloaded, start if no scrolling, otherwise, wait until the `scrolling-stopped` notification is posted.
    //
    // 2. When the cell is no longer in view `didEndDisplaying`, cancel the download task if it is still in progress.
    //
    // 3. When dragging starts, post the `scrolling-started` notification to suspend any download tasks.
    //
    // 4. Normally, when 
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        AlbumArtCache.shared.cancelDownload(for: tracks[indexPath.row])
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrolling = true
        NotificationCenter.default.post(name: Notification.Name("scrolling-started"), object: nil)
    }
    
    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        scrolling = false
        NotificationCenter.default.post(name: Notification.Name("scrolling-stopped"), object: nil)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            scrolling = false
            NotificationCenter.default.post(name: Notification.Name("scrolling-stopped"), object: nil)
        }
    }
    
}
