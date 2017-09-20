//
//  QROrderGenerationViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 16/06/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit

class QROrderGenerationViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var fullName_label: UILabel!
    @IBOutlet weak var age_label: UILabel!
    @IBOutlet weak var gender_label: UILabel!
    @IBOutlet weak var imgQRCode: UIImageView!
    @IBOutlet weak var userImage_image: UIImageView!
    @IBOutlet weak var myTable: UITableView!
    @IBOutlet weak var expirated_label: UILabel!
    @IBOutlet weak var dataScadenza_label: UILabel!
    
    
    
    var offertaRicevuta: Order?
    var user: User?
    var qrcodeImage: CIImage!
    var sectionTitle = ["Dettaglio ordine", "Riepilogo"]
    var imageCache = [String:UIImage]()
    var dataScadenza :String?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.fullName_label.text = user?.fullName
        
        self.age_label.text = "anni 18"
        if (user?.gender == "male") {
            self.gender_label.text = "sesso: uomo"
        }else {
            self.gender_label.text = "sesso: donna"
        }
        
        let url = NSURL(string: (user?.pictureUrl)!)
        let data = NSData(contentsOf: url! as URL)
        userImage_image.image = UIImage(data: data! as Data)

        self.myTable.dataSource = self
        self.myTable.delegate = self
        guard !orderExpirated() else {
            self.expirated_label.isHidden = false
            return
        }
        generateQrCode()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func orderExpirated()->Bool{
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
        dateFormatter.locale = Locale.init(identifier: "it_IT")
        guard self.dataScadenza != nil else {
            print("la data di scadenza non è disponibile in questa view")
            return false
        }
        self.dataScadenza_label.text = "Scade il: " + stringTodate(dateString: self.dataScadenza! )
        let currentDate = Date()
        let expirationDay = dateFormatter.date(from: self.dataScadenza!)
        return currentDate >= expirationDay!
        
    }
    
    private func stringTodate(dateString: String) ->String {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
        dateFormatter.locale = Locale.init(identifier: "it_IT")
        
        let dateObj = dateFormatter.date(from: dateString)
        
        dateFormatter.dateFormat = "dd/MM/yyyy"
        return dateFormatter.string(from: dateObj!)
    }
    
    private func generateQrCode(){
        if qrcodeImage == nil {
            
            let information = (self.user?.idApp)! + " - " + (self.offertaRicevuta?.idOfferta)!
            let data = information.data(using: String.Encoding.isoLatin2, allowLossyConversion: false)
            let filter = CIFilter(name: "CIQRCodeGenerator")
            
            filter?.setValue(data, forKey: "inputMessage")
            filter!.setValue("Q", forKey: "inputCorrectionLevel")
            qrcodeImage = filter!.outputImage
            displayQRCodeImage()
        }
        else {
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
    
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 2
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        return self.sectionTitle[section]
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return (self.offertaRicevuta?.prodotti?.count)!
        }else {
            return 1
        }
        
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "orderCell", for: indexPath)
        
        if (sectionTitle[indexPath.section] == sectionTitle[0]) {
            let product = self.offertaRicevuta?.prodotti?[indexPath.row]
            
             cell.textLabel?.text = "(\(product!.quantity!))  " + (product?.productName)! + " € " + String(format:"%.2f", product!.price!)
            
            
            print(product!.productName!)
            print("costo ",product!.price!)
            print("quantità ",product!.quantity!)
        } else {
            cell.textLabel?.text = "Prodotti: \(self.offertaRicevuta!.prodottiTotali) \t\t Totale: € " +  String(format:"%.2f",offertaRicevuta!.costoTotale)
            
            cell.backgroundColor = UIColor(red: 48/255, green: 248/255, blue: 52/255, alpha: 1)
        }
        return cell
    }
    
}
