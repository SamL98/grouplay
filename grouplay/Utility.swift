//
//  Utility.swift
//  grouplay
//
//  Created by Sam Lerner on 12/9/17.
//  Copyright © 2017 Sam Lerner. All rights reserved.
//

import UIKit

class Utility {
    
    static func generateRandomStr(with length: Int) -> String {
        let chars: NSString = "ABCDEFGHIJKLMNOPQRSTUVQXYZ1234567890"
        var result = ""
        for _ in 0..<length {
            var char = chars.character(at: Int(arc4random_uniform(UInt32(chars.length))))
            result += NSString(characters: &char, length: 1) as String
        }
        return result
    }
    
    static func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
            guard error == nil else {
                print(error!)
                completion(nil)
                return
            }
            guard (response as! HTTPURLResponse).statusCode == 200 else {
                print("URL response is: \((response as! HTTPURLResponse).statusCode)")
                completion(nil)
                return
            }
            guard data != nil else {
                print("Data for image is nil")
                completion(nil)
                return
            }
            guard let image = UIImage(data: data!) else {
                print("unable to create image from data")
                completion(nil)
                return
            }
            completion(image)
        }).resume()
    }
    
    static func formatSeconds(time: Int) -> String {
        let minutes = Int(time/60)
        let seconds = time-minutes*60
        
        var secondStr = "\(seconds)"
        if seconds < 10 {
            secondStr = "0\(seconds)"
        }
        return "\(minutes):\(secondStr)"
    }
    
}

extension Date {
    static func now() -> UInt64 {
        return UInt64(floor(Date().timeIntervalSince1970))
    }
}
