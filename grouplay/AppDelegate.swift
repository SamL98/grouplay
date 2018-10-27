//
//  AppDelegate.swift
//  grouplay
//
//  Created by Sam Lerner on 12/7/17.
//  Copyright © 2017 Sam Lerner. All rights reserved.
//

import UIKit
import CoreData
import OAuthSwift
import Firebase
import KeychainSwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        UserDefaults.standard.set(false, forKey: "stream-logged-in")
        
        //UserDefaults.standard.set(false, forKey: "loggedIn")
        UserDefaults.standard.set(false, forKey: "sessInit")
        UserDefaults.standard.set(false, forKey: "timerStarted")
        
        if UserDefaults.standard.string(forKey: "uid") == nil {
            UserDefaults.standard.set(Utility.generateRandomStr(with: 20), forKey: "uid")
        }
        FirebaseApp.configure()
        SpotifyManager.shared.player = SPTAudioStreamingController.sharedInstance()
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        if !UserDefaults.standard.bool(forKey: "appAuthUsed") {
            if let host = url.host {
                if host == "spotify" {
                    OAuthSwift.handle(url: url)
                }
            }
        } else if let scheme = url.scheme, scheme == "grouplay-callback" {
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            var qs = comps.queryItems!
            var i = 0
            var optCode: String? = nil
            while i < qs.count {
                if qs[i].name == "code" {
                    optCode = qs[i].value
                    break
                }
                i += 1
            }
            guard let code = optCode else {
                print("code not found: \(url)")
                return false
            }
            NotificationCenter.default.post(
                name: NSNotification.Name("authURLOpened"),
                object: nil,
                userInfo: ["code": code])
        }
        return true
    }
    
    func invalidateTimers() {
        if let timer = SessionStore.timer { timer.invalidate() }
        UserDefaults.standard.set(false, forKey: "timerStarted")
    }
    
    func saveState() {
        guard let sess = SessionStore.session else { return }
        UserDefaults.standard.set(sess, forKey: "currSession")
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        saveState()
        invalidateTimers()
        
        SpotifyManager.shared.player.playbackDelegate = nil
        SpotifyManager.shared.deactivateSession()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        
        if let savedSess = UserDefaults.standard.object(forKey: "currSession") as? Session {
            SessionStore.session = savedSess
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        guard SessionStore.session != nil else { return }
        FirebaseManager.shared.enter()
        FirebaseManager.shared.refresh()
        
        SpotifyManager.shared.reactivateSession()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
        
        print("terminating")
        FirebaseManager.shared.setPaused(paused: true)
        FirebaseManager.shared.leave()
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "grouplay")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

}

