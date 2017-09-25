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
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.sectionTitle[section]
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if section == 0 {
            return Cart.sharedIstance.carrello.count
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
            
            let url = NSURL(string: (Cart.sharedIstance.carrello[indexPath.row].userDestination?.pictureUrl)!)
            let data = NSData(contentsOf: url! as URL)
            (cell as! CartUserTableViewCell).friendImageView.image = UIImage(data: data! as Data)
            (cell as! CartUserTableViewCell).nome_label.text = (Cart.sharedIstance.carrello[indexPath.row].userDestination?.fullName)!
            (cell as! CartUserTableViewCell).totProdotti_label.text = "Prodotti: " + String(Cart.sharedIstance.carrello[indexPath.row].prodottiTotali)
            (cell as! CartUserTableViewCell).costoOfferta_label.text = "€ " + String(format:"%.2f", Cart.sharedIstance.carrello[indexPath.row].costoTotale)
            print((Cart.sharedIstance.carrello[indexPath.row].userDestination?.fullName)!,(Cart.sharedIstance.carrello[indexPath.row].userDestination?.idFB)!)
            
        } else {
            //products section
            cell = tableView.dequeueReusableCell(withIdentifier: "cartCell", for: indexPath)
            cell?.textLabel?.text = "Prodotti: \(Cart.sharedIstance.prodottiTotali) \t\t\t Totale: € " +  String(format:"%.2f",Cart.sharedIstance.costoTotale)
            
            cell?.textLabel?.textColor = #colorLiteral(red: 0.7411764706, green: 0.1529411765, blue: 0.2078431373, alpha: 1)
        }
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        
        switch editingStyle {
        case .delete:
            print("premuto il tasto Delete")
            
            let elemento = Cart.sharedIstance.carrello[indexPath.row]
            print("elimo l'elemento \((elemento.userDestination?.fullName)!)")

            Cart.sharedIstance.carrello.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .left)
            self.myTable.reloadData()
            break
        default:
            break
        }
    }
    
    @IBAction func unwindToOffer(_ sender: UIBarButtonItem) {
        self.performSegue(withIdentifier: "unwindToOfferFromCartWithoutData", sender: nil)
        self.dismiss(animated: true) { () -> Void in
            print("VC Dismesso")
        }
    }
    
    private func generateAlert(title: String, msg: String){
        controller = UIAlertController(title: title,
                                       message: msg,
                                       preferredStyle: .alert)
        let actionProsegui = UIAlertAction(title: "Elimina", style: UIAlertActionStyle.default, handler:
        {(paramAction:UIAlertAction!) in
            Cart.sharedIstance.carrello.removeAll()
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
    
    @IBAction func segueToPayment(_ sender: UIBarButtonItem) {
        self.performSegue(withIdentifier: "segueToPayement", sender: nil)
    }
    
    @IBAction func unwindCarousel(_ sender: UIStoryboardSegue) {
        print("Unwind to offer profilo")
    }
    
}

