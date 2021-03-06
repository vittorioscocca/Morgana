//
//  CartViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 11/05/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit

class CartViewController: UIViewController,UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var myTable: UITableView!
    @IBOutlet weak var confirmOrderButton: UIButton!
    
    var sectionTitle = ["Offerte", "Riepilogo"]
    var controller :UIAlertController?
    
    enum Alert: String {
        case deleteCart_title = "Elimina carrello"
        case deleteCart_msg = "Proseguendo eliminerai gli ordini del carrello"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.myTable.dataSource = self
        self.myTable.delegate = self
        
        confirmOrderButton.layer.cornerRadius = 10
        confirmOrderButton.layer.masksToBounds = true
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.sectionTitle[section]
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if section == 0 {
            return Cart.sharedIstance.cart.count
        }else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if (sectionTitle[indexPath.section] == sectionTitle[0]) {
            return 78.0
        } else {
            return 42.0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell?
        
        //receiver section
        if (sectionTitle[indexPath.section] == sectionTitle[0]) {
            cell = tableView.dequeueReusableCell(withIdentifier: "cartUserCell", for: indexPath)
            
            let url = NSURL(string: (Cart.sharedIstance.cart[indexPath.row].userDestination?.pictureUrl)!)
            let data = NSData(contentsOf: url! as URL)
            
            (cell as! CartUserTableViewCell).friendImageView.image = UIImage(data: data! as Data)
            (cell as! CartUserTableViewCell).nome_label.text = (Cart.sharedIstance.cart[indexPath.row].userDestination?.fullName)!
            (cell as! CartUserTableViewCell).totProdotti_label.text = "Prodotti: " + String(Cart.sharedIstance.cart[indexPath.row].prodottiTotali)
            (cell as! CartUserTableViewCell).costoOfferta_label.text = LocalCurrency.instance.getLocalCurrency(currency: NSNumber(floatLiteral: (Cart.sharedIstance.cart[indexPath.row].costoTotale)))
            cell?.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
        } else {
            //products section
            cell = tableView.dequeueReusableCell(withIdentifier: "cartCell", for: indexPath)
            cell?.textLabel?.text = "Prodotti: \(Cart.sharedIstance.totalProducts) \t\t Punti: \(Cart.sharedIstance.totalPoints) \t\t Tot: \(LocalCurrency.instance.getLocalCurrency(currency: NSNumber(floatLiteral: (Cart.sharedIstance.costoTotale))))" 
            
            cell?.textLabel?.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
            cell?.textLabel?.font =  UIFont.systemFont(ofSize: 17)
            cell?.backgroundColor =  #colorLiteral(red: 0.7411764706, green: 0.1529411765, blue: 0.2078431373, alpha: 1)
        }
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if (sectionTitle[indexPath.section] == sectionTitle[0]){
            return true
        }else {
            return false
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        switch editingStyle {
        case .delete:
            print("premuto il tasto Delete")
            
            let elemento = Cart.sharedIstance.cart[indexPath.row]
            print("elimo l'elemento \((elemento.userDestination?.fullName)!)")

            Cart.sharedIstance.cart.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            if Cart.sharedIstance.cart.isEmpty {
                unwind()
            } else {
                self.myTable.reloadData()
            }
            
            break
        default:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let thisCell = tableView.cellForRow(at: indexPath)
        if (thisCell is CartUserTableViewCell){
            self.performSegue(withIdentifier: "segueToCartOrderDetails", sender: indexPath)
        }
        tableView.deselectRow(at: indexPath, animated: false)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier else {
            return
        }
        switch identifier {
        case "segueToPayement":
            break
        case "segueToCartOrderDetails":
            guard let path = sender else {return}
            let orderSent = Cart.sharedIstance.cart[(path as! IndexPath).row]
            (segue.destination as! CartOrderDetailsViewController).orderSent = orderSent
            break
        default:
            break
        }
    }
    
    private func unwind(){
        self.performSegue(withIdentifier: "unwindToOfferFromCartWithoutData", sender: nil)
        self.dismiss(animated: true) { () -> Void in
            print("VC Dismesso")
        }
    }
    
    @IBAction func unwindToOffer(_ sender: UIBarButtonItem) {
        unwind()
    }
    
    private func generateAlert(title: String, msg: String){
        controller = UIAlertController(title: title,
                                       message: msg,
                                       preferredStyle: .alert)
        let actionProsegui = UIAlertAction(title: "Elimina", style: UIAlertActionStyle.default, handler:
        {(paramAction:UIAlertAction!) in
            Cart.sharedIstance.cart.removeAll()
            self.performSegue(withIdentifier: "unwindToOffer", sender: nil)
            self.dismiss(animated: true) { () -> Void in
                print("VC Dismesso")
            }
        })
        let actionAnnulla = UIAlertAction(title: "Annulla", style: UIAlertActionStyle.default, handler:
        {(paramAction:UIAlertAction!) in
            print("Il messaggio di chiusura è stato premuto")
        })
        
        controller!.addAction(actionAnnulla)
        controller!.addAction(actionProsegui)
        self.present(controller!, animated: true, completion: nil)
    }
    
    @IBAction func deleteCarousel_clicked(_ sender: UIBarButtonItem) {
        self.generateAlert(title: Alert.deleteCart_title.rawValue, msg: Alert.deleteCart_msg.rawValue)
    }
    
    
    @IBAction func confirmOrder(_ sender: UIButton) {
        self.performSegue(withIdentifier: "segueToPayement", sender: nil)
    }
    
}

