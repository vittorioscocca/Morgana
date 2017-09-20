//
//  QrReaderViewControllerViewController.swift
//  CameraProject
//
//  Created by Vittorio Scocca on 09/09/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit
import AVFoundation

class QrReaderViewControllerViewController: UIViewController,AVCaptureMetadataOutputObjectsDelegate {
    @IBOutlet weak var square: UIImageView!
    

    var merchantCode: String?
    var video = AVCaptureVideoPreviewLayer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Creating session
        let session = AVCaptureSession()
        
        //Define capture device
        let captureDevice = AVCaptureDevice.default(for: AVMediaType.video)
        
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice!)
            session.addInput(input)
        }
        catch {
            print("ERROR")
            return
        }
        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        
        video = AVCaptureVideoPreviewLayer(session: session)
        video.videoGravity = AVLayerVideoGravity.resizeAspectFill
        video.frame = view.layer.bounds
        view.layer.addSublayer(video)
        self.view.bringSubview(toFront: square)
        
        session.startRunning()
    }
    
    func metadataOutput(captureOutput: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        var alert = UIAlertController()
        if !metadataObjects.isEmpty && metadataObjects.count != 0 {
            if let object = metadataObjects[0] as? AVMetadataMachineReadableCodeObject{
                if object.type == AVMetadataObject.ObjectType.qr {
                    alert = UIAlertController(title: "Dettagli ordine", message: object.stringValue, preferredStyle: .alert)
                }
                present(alert, animated: true, completion: nil)
                
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    

}
