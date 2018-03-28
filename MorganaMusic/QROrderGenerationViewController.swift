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
    var dataScadenza :String?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.fullName_label.text = user?.fullName
        
        self.calculateAge()
        if (user?.gender == "male") {
            self.gender_label.text = "sesso: uomo"
        }else {
            self.gender_label.text = "sesso: donna"
        }
        
        self.readImage()
        self.setCustomImage()
        self.myTable.dataSource = self
        self.myTable.delegate = self
        guard !orderExpirated() else {
            self.expirated_label.isHidden = false
            self.dataScadenza_label.textColor = .red
            return
        }
       
        generateQrCode()
    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    private func calculateAge(){
        guard self.user?.birthday != nil else {
            self.age_label.text = "Età non disponibile"
            return
        }
        let birthday = stringTodateObject(date:(self.user?.birthday)!)
        let now = Date()
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthday!, to: now)
        let age = ageComponents.year!
        
        self.age_label.text = String(age) + " anni"
    }
    private func stringTodateObject(date: String)->Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.amSymbol = "AM"
        dateFormatter.pmSymbol = "PM"
        dateFormatter.dateFormat = "dd-MM-yyyy"
        //let dateString = dateFormatter.string(from: date as Date)
        
        return dateFormatter.date(from: date)
    }
    private func readImage(){
        CacheImage.getImage(url: self.user?.pictureUrl, onCompletion: { (image) in
            guard image != nil else {
                print("Attenzione URL immagine Mittente non presente")
                return
            }
            DispatchQueue.main.async(execute: {
                self.userImage_image.image = image
            })
        })
    }
    
    private func setCustomImage(){
        self.userImage_image.layer.borderWidth = 2.5
        self.userImage_image.layer.borderColor = #colorLiteral(red: 0.7419371009, green: 0.1511851847, blue: 0.20955199, alpha: 1)
        self.userImage_image.layer.masksToBounds = false
        self.userImage_image.layer.cornerRadius = userImage_image.frame.height/2
        self.userImage_image.clipsToBounds = true
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
            
            let information = (self.user?.idApp)! + "//" + (self.offertaRicevuta?.orderAutoId)! + "||*" + (self.offertaRicevuta?.expirationeDate)! + "*" + (self.offertaRicevuta?.company?.companyId)!
            
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
            cell.textLabel?.textColor = #colorLiteral(red: 0.7411764706, green: 0.1529411765, blue: 0.2078431373, alpha: 1)
            
            print(product!.productName!)
            print("costo ",product!.price!)
            print("quantità ",product!.quantity!)
        } else {
            cell.textLabel?.text = "Prodotti: \(self.offertaRicevuta!.prodottiTotali) \t\t Totale: € " +  String(format:"%.2f",offertaRicevuta!.costoTotale)
            cell.textLabel?.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
            cell.textLabel?.font =  UIFont.systemFont(ofSize: 17)
            cell.backgroundColor = #colorLiteral(red: 0.7411764706, green: 0.1529411765, blue: 0.2078431373, alpha: 1)
            
        }
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: UIFont.Weight.light)
        return cell
    }
    
    func unwind(){
        performSegue(withIdentifier: "unwindToMyDrinks", sender: nil)
    }
    
}
