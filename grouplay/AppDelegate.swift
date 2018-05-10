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
        if UserDefaults.standard.string(forKey: "uid") == nil {
            UserDefaults.standard.set(Utility.generateRandomStr(with: 20), forKey: "uid")
        }
        FirebaseApp.configure()
        
        //SpotifyManager.shared.auth = SPTAuth.defaultInstance()
        //SpotifyManager.shared.auth.tokenRefreshURL = URL(string: "http://localhost:5000/refresh")!
        //SpotifyManager.shared.auth.tokenSwapURL = URL(string: "http://localhost:5000/token_swap")!
        //SpotifyManager.shared.auth.redirectURL = URL(string: "grouplay-callback://spotify/callback")!
        SpotifyManager.shared.player = SPTAudioStreamingController.sharedInstance()
        //SpotifyManager.shared.auth.clientID = "3724420a06104264bc1a827d1f9e09ab"
        //SpotifyManager.shared.auth.sessionUserDefaultsKey = "current session"
        //SpotifyManager.shared.auth.requestedScopes = [SPTAuthStreamingScope, SPTAuthUserLibraryReadScope]
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        /*if SpotifyManager.shared.auth.canHandle(SpotifyManager.shared.auth.redirectURL) {
            SpotifyManager.shared.auth.handleAuthCallback(withTriggeredAuthURL: url, callback: { (err, sess) in
                guard err == nil else {
                    print("error creating authenticated spotify session: \(err!)")
                    return
                }
                guard sess != nil else {
                    print("session is nil")
                    return
                }
                SpotifyManager.shared.session = sess!
                SpotifyManager.shared.oauth.client.credential.oauthToken = sess!.accessToken
                
                let keychain = KeychainSwift()
                keychain.set(sess!.canonicalUsername, forKey: "username")
                keychain.set(sess!.accessToken, forKey: "accessToken")
                keychain.set(sess!.encryptedRefreshToken, forKey: "refreshToken")
                print(sess!.expirationDate)
                
                let formatter = DateFormatter()
                formatter.dateFormat = ""
                keychain.set(formatter.string(from: sess!.expirationDate), forKey: "expireDate")
                
                UserDefaults.standard.set(true, forKey: "spotify-logged-in")
                NotificationCenter.default.post(name: Notification.Name(rawValue: "login-complete"), object: nil)
            })
        }*/
        
        if let host = url.host {
            if host == "spotify" {
                OAuthSwift.handle(url: url)
            }
        }
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        FirebaseManager.shared.leave()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
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

