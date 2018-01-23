import Foundation
import OAuthSwift

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
            static let scopes = "user-read-currently-playing user-library-read user-library-modify playlist-read-private playlist-read-collaborative playlist-modify-public playlist-modify-private"
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
    }
    
    // MARK: Properties
    static let shared = SpotifyManager()
    let defaults = UserDefaults.standard
    let webView = WebView()
    let auth = OAuth2Swift(consumerKey: Constants.Keys.client_id, consumerSecret: Constants.Keys.client_secret, authorizeUrl: URLs.authorize_url, accessTokenUrl: URLs.access_token_url, responseType: Constants.Components.response_type, contentType: Constants.Components.content_type)
    
    // MARK: Authentication
    func login(onCompletion: @escaping () -> Void) {
        print("logging in to spotify")
        //auth.authorizeURLHandler = webView
        auth.authorize(withCallbackURL: URLs.redirect_uri, scope: Constants.Components.scopes, state: Constants.Components.state, success: { (credential, response, parameters) in
            print("login successful")
            self.fetchUserID()
            self.defaults.set(true, forKey: "loggedIn")
            UserDefaults.standard.set(parameters["refresh_token"], forKey: "refreshToken")
            onCompletion()
        }, failure: { (error: Error) in
            print("error while logging into spotify: \(error)")
        })
    }
    
    func refreshAuthToken(onCompletion: @escaping () -> Void) {
        print("refreshing oauth token")
        guard let refreshToken = UserDefaults.standard.object(forKey: "refreshToken") else {
            print("unable to retrieve refresh token from defaults")
            return
        }
        
        let _ = auth.client.post(URLs.access_token_url, parameters: [
            "grant_type":Constants.Components.grant_type,
            "refresh_token":refreshToken
            ], headers: ["Authorization":createRefreshTokenAuthorizationHeader()], success: { (response) in
                print("oauth refresh successful")
                let access_token = self.parseJSON(data: response.data)
                self.auth.client.credential.oauthToken = access_token
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
        
        auth.client.credential.oauthToken = ""
        auth.client.credential.oauthTokenSecret = ""
        auth.client.credential.oauthRefreshToken = ""
    }
    
    // MARK: Data Fetching
    func fetchUserID() {
        print("fetching user id")
        let _ = auth.client.get(URLs.user_url, success: { response in
            do {
                let json = try response.jsonObject() as! [String:AnyObject]
                let id = json["id"] as! String
                UserDefaults.standard.set(id, forKey: "user_id")
            } catch let error as NSError {
                print("error while serializing user id: \(error)")
            }
        }, failure: { error in
            print("failure to fetch user id: \(error)")
        })
    }
    
    func fetchLibrary(extraParameters: [String:AnyObject]?, onCompletion: @escaping spotify_track_response) {
        print("fetching library")
        var params = [String:AnyObject]()
        if let extraParams = extraParameters {
            for (key, value) in extraParams {
                params[key] = value
            }
        }
        params["limit"] = 50 as AnyObject
        
        let _ = auth.client.get(URLs.user_library_url, parameters: params, headers: nil, success: { response in
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
        
        let _ = auth.client.get(URLs.search_url, parameters: params, headers: nil, success: { response in
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
    
    func fetchRecommendations(track: Track, extraParameters: [String:AnyObject]?, onCompletion: @escaping spotify_track_response) {
        print("fetching recommendations")
        var params = [String:AnyObject]()
        if let extraParams = extraParameters {
            for (key, value) in extraParams {
                params[key] = value
            }
        }
        params["seed_tracks"] = track.trackID as AnyObject
        params["limit"] = 50 as AnyObject
        
        let _ = auth.client.get(URLs.recommendation_url, parameters: params, headers: nil, success: { response in
            self.parseRecs(data: response.data) { Tracks, error in
                guard error == nil else {
                    print("error while parsing recommendations: \(error!)")
                    onCompletion(nil, error)
                    return
                }
                onCompletion(Tracks, nil)
            }
        }, failure: { error in
            print("error while fetching recommendations: \(error)")
        })
    }
    
    func fetchCurrent(completion: @escaping curr_response) {
        print("fetching current")
        let _ = auth.client.get(URLs.current, success: { response in
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
                
                completion(track, timeLeft == 0 ? nil : timeLeft/1000, nil)
            } else {
                completion(nil, nil, NSError(domain: "current-fetch", code: 421, userInfo: nil))
            }
        }, failure: { error in
            print("error fetching current: \(error)")
            completion(nil, nil, NSError(domain: "current-fetch", code: 422, userInfo: nil))
        })
    }
    
    // Data Posting/Deleting
    func saveTrack(track: Track, onCompletion: @escaping () -> Void) {
        print("saving track")
        let url = NSURLComponents(string: URLs.user_library_url)
        url?.queryItems = [NSURLQueryItem(name: "ids", value: track.trackID) as URLQueryItem]
        var request = URLRequest(url: (url?.url)!)
        
        request.httpMethod = "PUT"
        request.addValue("Bearer \(auth.client.credential.oauthToken)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard error == nil else {
                print("error while saving track: \(error!)")
                return
            }
            
            guard (response as! HTTPURLResponse).statusCode == 200 else {
                print("save failed. http status code: \((response as! HTTPURLResponse).statusCode))")
                return
            }
            
            print("successfully saved track")
            onCompletion()
        }
        task.resume()
    }
    
    // MARK: JSON Parsing
    func parseJSON(data: Data) -> String {
        print("parsing JSON")
        do {
            let jsonDictionary = try JSONSerialization.jsonObject(with: data, options: []) as! NSDictionary
            let token = jsonDictionary["access_token"] as! String
            return token
        } catch let error as NSError {
            print("error while serializing auth JSON: \(error)")
            return ""
        }
    }
    
    func parseRecs(data: Data, onCompletion: spotify_track_response) {
        print("parsings recommendations")
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as! NSDictionary
            let tracksDict = jsonObject["tracks"] as! [[String:AnyObject]]
            
            var tracks = [Track]()
            for trackObj in tracksDict {
                if let title = trackObj["name"] as? String,
                    let id = trackObj["id"] as? String,
                    let artist = ((trackObj["artists"] as! [[String:AnyObject]])[0])["name"] as? String,
                    let urlString = (((trackObj["album"] as! [String:AnyObject])["images"] as! [[String:AnyObject]])[0])["url"] as? String,
                    let url = URL(string: urlString),
                    let previewString = trackObj["preview_url"] as? String,
                    let previewURL = URL(string: previewString),
                    let duration = trackObj["duration"] as? Int {
                    
                    let track = Track(title: title, artist: artist, trackID: id, imageURL: url, image: nil, preview: previewURL, duration: duration)
                    tracks.append(track)
                }
            }
            onCompletion(tracks, nil)
            
        } catch let error as NSError {
            print("error while serializing recommendation JSON")
            onCompletion(nil, error)
        }
    }
    
    func parseTracks(data: Data, onCompletion: spotify_track_response) {
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
        if let title = trackObj["name"] as? String,
            let id = trackObj["id"] as? String,
            let artist = ((trackObj["artists"] as! [[String:AnyObject]])[0])["name"] as? String,
            let urlString = (((trackObj["album"] as! [String:AnyObject])["images"] as! [[String:AnyObject]])[0])["url"] as? String,
            let url = URL(string: urlString) {
            
            return Track(title: title, artist: artist, trackID: id, imageURL: url, image: nil, preview: nil, duration: trackObj["duration_ms"] as? Int ?? 0)
        }
        return nil
    }
    
    func parseSearch(data: Data, onCompletion: spotify_track_response) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as! [String:AnyObject]
            let tracksDict = (jsonObject["tracks"] as! [String:AnyObject])["items"] as! [[String:AnyObject]]
 
            var tracks = [Track]()
            for item in tracksDict {
                if let title = item["name"] as? String,
                    let id = item["id"] as? String,
                    let artist = ((item["artists"] as! [[String:AnyObject]])[0])["name"] as? String,
                    let urlString = (((item["album"] as! [String:AnyObject])["images"] as! [[String:AnyObject]])[0])["url"] as? String,
                    let url = URL(string: urlString) {
                    
                    let track = Track(title: title, artist: artist, trackID: id, imageURL: url, image: nil, preview: nil, duration: item["duration_ms"] as? Int ?? 0)
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
