//
//  ScanQRViewController.swift
//  grouplay
//
//  Created by Sam Lerner on 7/19/18.
//  Copyright © 2018 Sam Lerner. All rights reserved.
//

import UIKit
import CoreImage
import AVFoundation

class ScanQRViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    var session = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        DispatchQueue.main.async {
            self.authorizeCamera()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning { session.startRunning() }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }
    
    func authorizeCamera() {
        guard AVCaptureDevice.authorizationStatus(for: AVMediaType.video) == .authorized else {
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { granted in
                guard granted else {
                    print("camera access not granted")
                    self.dismiss(animated: true, completion: nil)
                    return
                }
                self.configureCamera()
            })
            return
        }
        self.configureCamera()
    }
    
    func configureCamera() {
        let captureDevice = AVCaptureDevice.default(for: .video)
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: captureDevice!)
        } catch let error as NSError {
            print("error w camera: \(error)")
            return
        }
        
        guard session.canAddInput(input) else {
            print("cannot add input")
            return
        }
        session.addInput(input)
        
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            print("cannot add output")
            return
        }
        session.addOutput(output)
        
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        session.startRunning()
    }
    
    func parseQRCode(_ code: String) {
        ((presentingViewController as? UINavigationController)?.viewControllers.first as? LaunchViewController)?.code = code
        dismiss(animated: true, completion: nil)
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        session.stopRunning()
        guard let mdObj = metadataObjects.first as? AVMetadataMachineReadableCodeObject else {
            print("no metadata object")
            return
        }
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
        parseQRCode(mdObj.stringValue!)
    }

}
