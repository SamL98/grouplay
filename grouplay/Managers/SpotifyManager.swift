import Foundation
import OAuthSwift
import AVFoundation

class SpotifyManager {
    
    // Callback response typealias
    typealias spotify_track_response = ([Track]?, NSError?) -> Void
    typealias curr_response = (Track?, Int?, NSError?) -> Void
    
    // MARK: Constants
    
    private struct Constants {
        struct Keys {
            static let client_id = "3724420a06104264bc1a827d1f9e09ab"
            static let client_secret = "ba68f0819db24b78b62cc525e582c8b8"
        }
        struct Components {
            static let response_type = "code"
            static let content_type = "JSON"
            static let scopes = "user-read-private user-modify-playback-state user-read-currently-playing user-library-read user-library-modify playlist-read-private playlist-read-collaborative playlist-modify-public playlist-modify-private streaming"
            static let state = generateState(withLength: 20) as String
            static let grant_type = "refresh_token"
        }
    }
    
    private struct URLs {
        static let authorize_url = "https://accounts.spotify.com/authorize"
        static let access_token_url = "https://accounts.spotify.com/api/token"
        static let redirect_uri = URL(string: "grouplay-callback://spotify/callback")!
        static let user_url = "https://api.spotify.com/v1/me"
        static let user_library_url = "https://api.spotify.com/v1/me/tracks"
        static let search_url = "https://api.spotify.com/v1/search"
        static let user_playlist_url = "https://api.spotify.com/v1/me/playlists"
        static let playlist_url = "https://api.spotify.com/v1/users/"
        static let recommendation_url = "https://api.spotify.com/v1/recommendations"
        static let current = "https://api.spotify.com/v1/me/player/currently-playing"
        static let play = "htps://api.spotify.com/v1/me/player/play"
    }
    
    // MARK: Properties
    
    static let shared = SpotifyManager()
    let defaults = UserDefaults.standard
    let webView = WebView()
    let oauth = OAuth2Swift(consumerKey: Constants.Keys.client_id, consumerSecret: Constants.Keys.client_secret, authorizeUrl: URLs.authorize_url, accessTokenUrl: URLs.access_token_url, responseType: Constants.Components.response_type, contentType: Constants.Components.content_type)
    
    var session: SPTSession!
    var player: SPTAudioStreamingController!
    
    // MARK: Authentication
    // For information on how authentication is done, look at both OAuthSwift documentation and the Spotify API OAuth guide.
    
    var loginComp: (() -> Void)!
    
    func login(onCompletion: @escaping () -> Void) {
        print("logging in to spotify")

        if !SPTAuth.supportsApplicationAuthentication() {
            UserDefaults.standard.set(false, forKey: "appAuthUsed")
            oauth.authorize(withCallbackURL: URLs.redirect_uri, scope: Constants.Components.scopes, state: Constants.Components.state, success: { (credential, response, parameters) in
                print("login successful")
                self.fetchUserID()
                self.defaults.set(true, forKey: "loggedIn")
                UserDefaults.standard.set(parameters["refresh_token"], forKey: "refreshToken")
                onCompletion()
            }, failure: { (error: Error) in
                print("error while logging into spotify: \(error)")
                onCompletion()
            })
        } else {
            UserDefaults.standard.set(true, forKey: "appAuthUsed")
            
            SPTAuth.defaultInstance().clientID = Constants.Keys.client_id
            SPTAuth.defaultInstance().redirectURL = URLs.redirect_uri
            SPTAuth.defaultInstance().sessionUserDefaultsKey = "spotifySessionKey"
            SPTAuth.defaultInstance().requestedScopes = [SPTAuthStreamingScope, SPTAuthUserLibraryReadScope, SPTAuthUserLibraryModifyScope, SPTAuthPlaylistReadPrivateScope, SPTAuthPlaylistModifyPublicScope, SPTAuthPlaylistReadCollaborativeScope]
            
            var url = SPTAuth.defaultInstance().spotifyAppAuthenticationURL()!
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            var qs = (comps.queryItems)!
            var i = 0
            while i < qs.count {
                if qs[i].name == "response_type" {
                    qs[i].value = "code"
                    break
                }
                i += 1
            }
            comps.queryItems = qs
            url = comps.url!

            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            
            SpotifyManager.shared.loginComp = onCompletion
            NotificationCenter.default.addObserver(self, selector: #selector(SpotifyManager.finishLogin(n:)), name: NSNotification.Name("authURLOpened"), object: nil)
        }
    }
    
    @objc func finishLogin(n: Notification) {
        guard let info = n.userInfo else {
            print("no user info")
            return
        }
        guard let code = info["code"] as? String else {
            print("no code: \(info)")
            return
        }
        _ = oauth.client.post(
        "https://accounts.spotify.com/api/token",
        parameters: [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": URLs.redirect_uri
        ],
        headers: ["Authorization": createRefreshTokenAuthorizationHeader()],
        success: { (response) in
            let data = response.data
            var json: [String:AnyObject]
            do {
                try json = JSONSerialization.jsonObject(with: data, options: []) as! [String:AnyObject]
            } catch let error as NSError {
                print("unable to serialize code json: \(error)")
                return
            }
            guard let accessToken = json["access_token"] as? String else {
                print("no access token: \(json)")
                return
            }
            self.oauth.client.credential.oauthToken = accessToken
            
            guard let refreshToken = json["refresh_token"] as? String else {
                print("no refresh token: \(json)")
                return
            }
            
            print("login successful")
            
            self.fetchUserID()
            UserDefaults.standard.set(refreshToken, forKey: "refreshToken")
            UserDefaults.standard.set(true, forKey: "loggedIn")
            
            SpotifyManager.shared.loginComp()
        }, failure: { error in
            print("error getting auth and refresh token: \(error)")
        })
    }
    
    func refreshAuthToken(onCompletion: @escaping () -> Void) {
        print("refreshing session")
        
        guard let refreshToken = UserDefaults.standard.object(forKey: "refreshToken") else {
            print("unable to retrieve refresh token from defaults")
            return
        }
        
        let _ = oauth.client.post(URLs.access_token_url, parameters: [
            "grant_type":Constants.Components.grant_type,
            "refresh_token":refreshToken
            ], headers: ["Authorization":createRefreshTokenAuthorizationHeader()], success: { (response) in
                
                print("oauth refresh successful")
                let access_token = self.parseJSON(data: response.data)
                self.oauth.client.credential.oauthToken = access_token
                self.fetchUserID()
                onCompletion()
        }, failure: { error in
            print("error while refreshing oauth token: \(error)")
        })
    }
    
    func createRefreshTokenAuthorizationHeader() -> String {
        let str = "\(Constants.Keys.client_id):\(Constants.Keys.client_secret)"
        let utf8String = str.data(using: String.Encoding.utf8)
        
        if let base64Encoded = utf8String?.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0)) {
            return "Basic \(base64Encoded)"
        } else {
            print("unable to refresh token header")
            return ""
        }
    }
    
    func unauthenticateUser() {
        URLCache.shared.removeAllCachedResponses()
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
        
        defaults.set(false, forKey: "loggedIn")
        defaults.synchronize()
        
        oauth.client.credential.oauthToken = ""
        oauth.client.credential.oauthTokenSecret = ""
        oauth.client.credential.oauthRefreshToken = ""
    }
    
    // MARK: Data Fetching
    // Check out the Spotify Web API endpoint reference to see how requests and data are formatted and such.
    
    func fetchUserID() {
        print("fetching user id")
        let _ = oauth.client.get(URLs.user_url, success: { response in
            do {
                guard let json = try response.jsonObject() as? [String:AnyObject] else { return }
                guard let id = json["id"] as? String else { return }
                
                UserDefaults.standard.set(id, forKey: "user_id")
                if let product = json["product"] as? String {
                    UserDefaults.standard.set(product == "premium", forKey: "hasPremium")
                } else {
                    UserDefaults.standard.set(false, forKey: "hasPremium")
                }
                
            } catch let error as NSError {
                print("error while serializing user id: \(error)")
            }
        }, failure: { error in
            print("failure to fetch user id: \(error)")
        })
    }
    
    func fetchLibrary(extraParameters: [String:AnyObject]?, onCompletion: @escaping spotify_track_response) {
        var params = [String:AnyObject]()
        if let extraParams = extraParameters {
            for (key, value) in extraParams {
                params[key] = value
            }
        }
        params["limit"] = 50 as AnyObject
        
        let _ = oauth.client.get(URLs.user_library_url, parameters: params, headers: nil, success: { response in
            self.parseTracks(data: response.data) { tracks, error in
                guard error == nil else {
                    print("error while parsing library: \(error!)")
                    onCompletion(nil, error)
                    return
                }
                onCompletion(tracks, nil)
            }
        }, failure: { error in
            print("error while fetching library: \(error)")
        })
    }
    
    func searchTracks(query: String, offset: Int, onCompletion: @escaping spotify_track_response) {
        var params = [String:AnyObject]()
        params["q"] = query as AnyObject
        params["type"] = "track" as AnyObject
        params["limit"] = 50 as AnyObject
        params["offset"] = (50 * offset) as AnyObject
        
        let _ = oauth.client.get(URLs.search_url, parameters: params, headers: nil, success: { response in
            self.parseSearch(data: response.data) { (tracks, error) in
                guard error == nil else {
                    print("error while parsing library: \(error!)")
                    onCompletion(nil, error)
                    return
                }
                onCompletion(tracks, nil)
            }
        }, failure: { error in
            print("error while fetching searches: \(error)")
        })
    }
    
    func fetchCurrent(completion: @escaping curr_response) {
        //print("fetch current")
        let _ = oauth.client.get(URLs.current, success: { response in
            var json: [String:AnyObject]?
            do {
                json = try JSONSerialization.jsonObject(with: response.data, options: []) as? [String:AnyObject]
            } catch let error as NSError {
                print("could not serialize current json")
                completion(nil, nil, error)
                return
            }
            guard json != nil else {
                print("json is nil from current")
                completion(nil, nil, NSError(domain: "current-fetch", code: 419, userInfo: nil))
                return
            }
            guard let trackObj = (json!)["item"] as? [String:AnyObject] else {
                print("no item in current dict")
                completion(nil, nil, NSError(domain: "current-fetch", code: 420, userInfo: nil))
                return
            }
            if let track = self.parseTrack(trackObj: trackObj) {
                let timestamp = (json!)["timestamp"] as? UInt64
                let progress = (json!)["progress_ms"] as? Int
                
                var timeLeft = 0
                if progress != nil {
                    timeLeft = track.duration - progress!
                }
                
                if timestamp != nil {
                    timeLeft -= Int((Date.now() - timestamp!/1000))
                }
                
                FirebaseManager.shared.setCurrent(track)
                completion(track, timeLeft == 0 ? nil : timeLeft/1000, nil)
            } else {
                completion(nil, nil, NSError(domain: "current-fetch", code: 421, userInfo: nil))
            }
        }, failure: { error in
            print("error fetching current: \(error)")
            completion(nil, nil, NSError(domain: "current-fetch", code: 422, userInfo: nil))
        })
    }
    
    func save(_ track: Track) {
        let _ = oauth.client.put("\(URLs.user_library_url)?ids=\(track.trackID)", success: { response in
            if response.response.statusCode != 200 {
                print("save: \(response.response.statusCode)")
            }
        }, failure: { error in
            print(error)
        })
    }
    
    func unsave(_ track: Track) {
        let _ = oauth.client.delete("\(URLs.user_library_url)?ids=\(track.trackID)", success: { response in
            if response.response.statusCode != 200 {
                print("unsave: \(response.response.statusCode)")
            }
        }, failure: { error in
            print(error)
        })
    }
    
    // MARK: Playback
    
    func initPlayer() {
        do {
            try player.start(withClientId: Constants.Keys.client_id)
        } catch let error as NSError {
            print("error starting player: \(error)")
            return
        }
        player.login(withAccessToken: oauth.client.credential.oauthToken)
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: AVAudioSessionCategoryOptions.mixWithOthers)
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        } catch let error as NSError {
            print(error.localizedDescription)
        }
    }
    
    func reactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: AVAudioSessionCategoryOptions.mixWithOthers)
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        } catch let error as NSError {
            print(error.localizedDescription)
        }
    }
    
    func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch let error as NSError {
            print("deactivate error: \(error)")
        }
    }
    
    // MARK: JSON Parsing
    func parseJSON(data: Data) -> String {
        do {
            let jsonDictionary = try JSONSerialization.jsonObject(with: data, options: []) as! NSDictionary
            let token = jsonDictionary["access_token"] as! String
            return token
        } catch let error as NSError {
            print("error while serializing auth JSON: \(error)")
            return ""
        }
    }
    
    func parseTracks(data: Data, onCompletion: spotify_track_response) {
        //print("parsing tracks")
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as! [String:AnyObject]
            let tracksDict = jsonObject["items"] as! [[String:AnyObject]]

            var tracks = [Track]()
            for item in tracksDict {
                if let trackObj = item["track"] as? [String:AnyObject] {
                    if let track = parseTrack(trackObj: trackObj) {
                        tracks.append(track)
                    }
                }
            }
            onCompletion(tracks, nil)
        } catch {
            print("error while serializing Track JSON")
            onCompletion(nil, NSError(domain: "Spotify", code: 420, userInfo: nil))
        }
    }
    
    func parseTrack(trackObj: [String:AnyObject]) -> Track? {
        let optUrlStr = (((trackObj["album"] as? [String:AnyObject])?["images"] as? [[String:AnyObject]])?.first)?["url"] as? String
        if let title = trackObj["name"] as? String,
            let id = trackObj["id"] as? String,
            let artist = ((trackObj["artists"] as! [[String:AnyObject]])[0])["name"] as? String,
            let urlString = optUrlStr,
            let url = URL(string: urlString) {
            
            return Track(title: title, artist: artist, trackID: id, imageURL: url, image: nil, preview: nil, duration: trackObj["duration_ms"] as? Int ?? 0, timestamp: Date.now())
        }
        return nil
    }
    
    func parseSearch(data: Data, onCompletion: spotify_track_response) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as! [String:AnyObject]
            let tracksDict = (jsonObject["tracks"] as! [String:AnyObject])["items"] as! [[String:AnyObject]]
 
            var tracks = [Track]()
            for item in tracksDict {
                let optUrlStr = (((item["album"] as? [String:AnyObject])?["images"] as? [[String:AnyObject]])?.first)?["url"] as? String
                if let title = item["name"] as? String,
                    let id = item["id"] as? String,
                    let artist = ((item["artists"] as! [[String:AnyObject]])[0])["name"] as? String,
                    let urlStr = optUrlStr,
                    let url = URL(string: urlStr) {
                    
                    //print(title, artist)
                    let track = Track(title: title, artist: artist, trackID: id, imageURL: url, image: nil, preview: nil, duration: item["duration_ms"] as? Int ?? 0, timestamp: Date.now())
                    tracks.append(track)
                }
            }
            onCompletion(tracks, nil)
        } catch let error as NSError {
            print("\(error)")
            onCompletion(nil, error)
        }
    }
    
}
