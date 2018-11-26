//
//  FriendActionViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 11/04/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//
import UIKit
import FirebaseDatabase
import FirebaseAuth

//This is the controller for Friend order View. It's possibole choose Morgana products, saved on Firebase
class FriendActionViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource  {
    @IBOutlet weak var imageFriend_Picture: UIImageView!
    @IBOutlet weak var fullNameFrienf_label: UILabel!
    @IBOutlet weak var pickerView: UIPickerView!
    @IBOutlet weak var product1_label: UILabel!
    @IBOutlet weak var price1_label: UILabel!
    @IBOutlet weak var points_label: UILabel!
    @IBOutlet weak var quantity: UILabel!
    @IBOutlet weak var num_quantità: UIStepper!
    @IBOutlet weak var addToOrder: UIButton!
    @IBOutlet weak var total_label: UILabel!
    
    enum ErrorMessages: String {
        case erroreTitle = "Attenzione"
        case enterOneProduct_message = "Inserisci almeno un prodotto"
        case enterQuantity_message = "Inserisci una quantità di prodotto maggiore di 0"
    }
    
    var userId: String?
    
    typealias selectionType = (product:String?, price: Double?)
    var selection: selectionType = ("",0.0)
    var result = [String:String]()
    var productsList = [String]()
    var offersDictionary = [String : Double]()
    
    var fullNameFriend: String?
    var idFBFriend: String?
    var friendURLImage: String?
    
    //alert per comunicazioni
    var controller :UIAlertController?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        fullNameFrienf_label.text = fullNameFriend
        
        //modifying image
        imageFriend_Picture.layer.masksToBounds = false
        imageFriend_Picture.layer.cornerRadius = imageFriend_Picture.frame.height/2
        imageFriend_Picture.clipsToBounds = true
        imageFriend_Picture.layer.borderWidth = 2.5
        imageFriend_Picture.layer.borderColor = #colorLiteral(red: 0.7419371009, green: 0.1511851847, blue: 0.20955199, alpha: 1)
        quantity.text = "1"
        CacheImage.getImage(url: friendURLImage, onCompletion: { (image) in
            guard image != nil else {
                print("immagine utente non reperibile")
                return
            }
            DispatchQueue.main.async(execute: {
                self.imageFriend_Picture.image = image
            })
        })
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(remoteProductsListDidChange),
                                               name: .RemoteProductsListDidChange,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateUserPoints),
                                               name: .ReadingRemoteUserPointDidFinish,
                                               object: nil)
        addToOrder.layer.cornerRadius = 10
        addToOrder.layer.masksToBounds = true
        
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .never
        } else {
            // Fallback on earlier versions
        }
        
        // Connect data:
        self.pickerView.delegate = self
        self.pickerView.dataSource = self
        self.loadOfferte()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func remoteProductsListDidChange(){
        loadOfferte()
    }
    
    @objc func updateUserPoints(){
        guard let userid = userId,
            let price = price1_label.text?.replacingOccurrences(of: " €", with: "", options: .regularExpression),
            let quantity = quantity.text
            else {return}
        
        let totalPrice = Double(price)! * Double(quantity)!
        points_label.text = String(PointsManager.sharedInstance.addPointsForShopping(userId: userid, expense: totalPrice))
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func loadOfferte(){
        if LoadRemoteProducts.instance.isNotNull() && LoadRemoteProducts.instance.isNotEmpty() {
            self.productsList = LoadRemoteProducts.instance.products!
            self.offersDictionary = LoadRemoteProducts.instance.offers!
            self.pickerView.reloadAllComponents()
            
            DispatchQueue.main.async(execute: {
                self.updateLabels(row: 0)
            })
        }
    }
    
    // The number of columns of data
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // The number of rows of data
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        //while self.pickerData.count == 0{}
        return self.productsList.count
    }
    
    // The data to return for the row and component (column) that's being passed in
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return self.productsList[row]
    }
    
    func updateLabels(row: Int){
        let product = self.productsList[row]
        product1_label.text = product
        selection.product = product
        selection.price = self.offersDictionary[product]
        
        let priceString = String(format:"%.2f", selection.price!)
        price1_label.text = priceString + " €"
        points_label.text = String(PointsManager.sharedInstance.addPointsForShopping(userId: userId!,expense: selection.price! * Double(quantity.text!)!))
        total_label.text = String(format:"%.2f", selection.price! * Double(Int(quantity.text!)!))
        
    }
    
    // Catpure the picker view selection
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if LoadRemoteProducts.instance.isNotNull() && LoadRemoteProducts.instance.isNotEmpty() {
            DispatchQueue.main.async(execute: {
                self.updateLabels(row: row)
            })
        }
        
    }
    
    @IBAction func stepperValueChange(_ sender: UIStepper) {
        quantity.text = String(Int(sender.value))
        print("sender touched")
        guard let userid = userId,
            let price = price1_label.text?.replacingOccurrences(of: " €", with: "", options: .regularExpression),
            let quantity = quantity.text
            else {return}
        guard let finalPrice = Double(price), let finalQuantity = Double(quantity) else { return }
        let totalPrice = finalPrice * finalQuantity
        points_label.text = String(PointsManager.sharedInstance.addPointsForShopping(userId: userid, expense: totalPrice))
        total_label.text = String(format:"%.2f",totalPrice)
    }
    
    @IBAction func sendOrder_clicked(_ sender: UIButton) {
        guard selection.product != "" else {
            self.generateAlert(title: ErrorMessages.erroreTitle.rawValue, message: ErrorMessages.enterOneProduct_message.rawValue)
            return
        }
        guard quantity.text != "0" else {
            self.generateAlert(title: ErrorMessages.erroreTitle.rawValue, message: ErrorMessages.enterQuantity_message.rawValue)
            return
        }
        guard let price = selection.price, let points = points_label.text else {
            return
        }
        let prod = Product(productName: selection.product, price: price, quantity: Int(quantity.text!), points: Int(points))
        Order.sharedIstance.addProduct(product: prod, userId: userId!)
        
        performSegue(withIdentifier: "unwindToOffersFromOffriDrink", sender: nil)
    }
    
    
    private func generateAlert(title: String, message: String){
        controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "CHIUDI", style: UIAlertActionStyle.default, handler: {(paramAction:UIAlertAction!) in
            print("Pulsnte CHIUDI cliccato")
        })
        controller!.addAction(action)
        self.present(controller!, animated: true, completion: nil)
    }
    
}
