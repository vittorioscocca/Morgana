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
    
    var userId: String?
    var orderId: String?
    var expirationDate: String?
    var companyId: String?
    
    //Creating session
    let session = AVCaptureSession()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
       
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
        
        self.video = AVCaptureVideoPreviewLayer(session: session)
        self.video.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.video.frame = self.view.layer.bounds
        self.view.layer.addSublayer(self.video)
        self.view.bringSubview(toFront: square)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if (session.isRunning == false) {
            session.startRunning();
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if (session.isRunning == true) {
            session.stopRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        //var alert = UIAlertController()
        if !metadataObjects.isEmpty && metadataObjects.count != 0 {
            if let object = metadataObjects[0] as? AVMetadataMachineReadableCodeObject{
                if object.type == AVMetadataObject.ObjectType.qr {
                    self.obtainInfo(info: object.stringValue)
                    session.stopRunning()
                    self.performSegue(withIdentifier: "segueToAuthOrder", sender: nil)
                    //alert = UIAlertController(title: "Dettagli ordine", message: object.stringValue, preferredStyle: .alert)
                    
                }
                //present(alert, animated: true, completion: nil)
            }
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    private func obtainInfo(info: String?){
        guard let rightInfo = info else {
            var alert = UIAlertController()
            alert = UIAlertController(title: "Errore Lettura", message: "Il codice non è leggibile", preferredStyle: .alert)
            present(alert, animated: true, completion: nil)
            return
        }
        //Obtain UserId
        var token = rightInfo.components(separatedBy: "//")
        self.userId = String(token[0])
        let orderIdPlusExpirationDay = String(token[1])
        
        //Obtain UserId and Expiration Date
        token = orderIdPlusExpirationDay.components(separatedBy: "||*")
        self.orderId = String(token[0])
        let expirationDatePlusCompanyId = String(token[1])
        
        token = expirationDatePlusCompanyId.components(separatedBy: "*")
        self.expirationDate = String(token[0])
        self.companyId = String(token[1])
        
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        (segue.destination as! AuthOrderViewController).userDestinationID = self.userId
        (segue.destination as! AuthOrderViewController).orderId = self.orderId
        (segue.destination as! AuthOrderViewController).expirationDate = self.expirationDate
        (segue.destination as! AuthOrderViewController).comapanyId = self.companyId
    }
    
    
    
    

}
