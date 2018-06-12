//
//  UserQrCodeViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 24/10/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit

class UserQrCodeViewController: UIViewController {

    @IBOutlet var imgQRCode: UIImageView!
    
    var user: User?
    var qrcodeImage: CIImage!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        generateQrCode()
    }

    
    private func generateQrCode(){
        if qrcodeImage == nil {
            let data = self.user?.idApp?.data(using: String.Encoding.isoLatin2, allowLossyConversion: false)
            if let filter = CIFilter(name: "CIQRCodeGenerator"){
                filter.setValue(data, forKey: "inputMessage")
                filter.setValue("Q", forKey: "inputCorrectionLevel")
                qrcodeImage = filter.outputImage
                displayQRCodeImage()
            } else {
                imgQRCode.image = nil
                qrcodeImage = nil
            }
        } else {
            imgQRCode.image = nil
            qrcodeImage = nil
        }
    }
    
    private func displayQRCodeImage() {
        let scaleX = imgQRCode.frame.size.width / qrcodeImage.extent.size.width
        let scaleY = imgQRCode.frame.size.height / qrcodeImage.extent.size.height
        
        let transformedImage = qrcodeImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(transformedImage, from: transformedImage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        
        imgQRCode.image = image
    }
    


}
