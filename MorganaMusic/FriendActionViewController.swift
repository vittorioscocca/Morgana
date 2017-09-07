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
    @IBOutlet weak var quantità: UILabel!
    @IBOutlet weak var num_quantità: UIStepper!
   
    enum ErrorMessages: String {
        case erroreTitle = "Attenzione"
        case enterOneProduct_message = "Inserisci almeno un prodotto"
        case enterQuantity_message = "Inserisci una quantità di prodottommaggiore di 0"
    }
    
    var productCount = 0
    var userId: String?
    
    typealias selectionType = (product:String?, price: Double?)
    var selection: selectionType = ("",0.0)
    var result = [String:String]()
    let defaults = UserDefaults.standard
    
    var productsList = [String]()
    var offersDctionary = [String : Double]()
    
    
    var imageFriend: UIImage!
    var fullNameFriend: String?
    var idFBFriend: String?
    
    
    //alert per comunicazioni
    var controller :UIAlertController?
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        self.imageFriend_Picture.image = self.imageFriend
        self.fullNameFrienf_label.text = fullNameFriend
        
        //modifying image
        self.imageFriend_Picture.layer.masksToBounds = false
        self.imageFriend_Picture.layer.cornerRadius = imageFriend_Picture.frame.height/2
        self.imageFriend_Picture.clipsToBounds = true
        
        // Connect data:
        self.pickerView.delegate = self
        self.pickerView.dataSource = self
        guard !self.productsList.isEmpty else {
            return
        }
        let product = self.productsList[0]
        self.selection.product = product
        self.product1_label.text = product
        self.selection.price = self.offersDctionary[product]
        let priceString = String(format:"%.2f", self.selection.price!)
        self.price1_label.text = priceString + " €"
        
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
    
    // Catpure the picker view selection
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let product = self.productsList[row]
        //self.storeSelection(self.productsList[row])
        self.product1_label.text = product
        self.selection.product = product
        self.selection.price = self.offersDctionary[product]
        let priceString = String(format:"%.2f", self.selection.price!)
        self.price1_label.text = priceString + " €"
    }
    
    @IBAction func newRequest(_ sender: UIButton) {
        if self.selection.product != "" {
            self.product1_label.text = self.selection.product
            let priceString = String(format:"%.2f", self.selection.price!)
            self.price1_label.text = priceString + " €"
            //self.memorizza(self.scelta.product!)
            
        }
    }
    
    @IBAction func stepperValueChange(_ sender: UIStepper) {
        self.quantità.text = String(Int(sender.value))
    }
    
    @IBAction func sendOrder_clicked(_ sender: UIButton) {
        guard self.selection.product != "" else {
            self.generateAlert(title: ErrorMessages.erroreTitle.rawValue, message: ErrorMessages.enterOneProduct_message.rawValue)
            return
        }
        guard self.quantità.text != "0" else {
            self.generateAlert(title: ErrorMessages.erroreTitle.rawValue, message: ErrorMessages.enterQuantity_message.rawValue)
            return
        }
        let prod = Product(productName: self.selection.product, price: self.selection.price!, quantity: Int(self.quantità.text!))
        Order.sharedIstance.addProduct(product: prod)
        
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
