//
//  ShowQRViewController.swift
//  grouplay
//
//  Created by Sam Lerner on 7/19/18.
//  Copyright © 2018 Sam Lerner. All rights reserved.
//

import UIKit
import QRCode

class ShowQRViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let imageView = view.viewWithTag(20) as? UIImageView else { return }
        guard let sessName = UserDefaults.standard.string(forKey: "currName") else { return }
        
        var qrCode = QRCode(sessName.data(using: .utf8)!)
        qrCode.size = imageView.frame.size
        imageView.image = qrCode.image
    }
    
    @IBAction func goBack(sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }

}
