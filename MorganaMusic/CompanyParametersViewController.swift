//
//  CompanyParametersViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 23/10/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit


class CompanyParametersViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet var myTable: UITableView!
    
    var sectionTitle = ["Parametri","Giorni di interesse"]
    private var days = [String]()
    var companyParameters = CompanyParameters()
    let daysOfWeek = ["Lunedì","Martedì","Mercoledì","Giovedì","Venerdì","Sabato","Domenica"]
    var myIndexPath = [IndexPath]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
       
        self.myTable.dataSource = self
        self.myTable.delegate = self
        self.readDataFromFirebase()
    }

    private func readDataFromFirebase() {
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "merchantPointsParameters/mr001", onCompletion: { (error, dictionary) in
            guard error == nil else {
                print("Errore di connessione")
                return
            }
            guard dictionary != nil else {
                print("Errore di lettura del dell'Ordine richiesto")
                return
            }
            
            self.companyParameters.parameters.append(Parameters(parameterName:"changeCreditToPoint" ,parameterValue: (dictionary?["changeCreditToPoint"] as? Double)!))
            self.companyParameters.parameters.append(Parameters(parameterName:"standardConsumptions" ,parameterValue: (dictionary?["standardConsumptions"] as? Double)!))
            self.companyParameters.parameters.append(Parameters(parameterName:"firstShoppingDiscount" ,parameterValue: (dictionary?["firstShoppingDiscount"] as? Double)!))
            self.companyParameters.parameters.append(Parameters(parameterName:"secondShoppingDiscount" ,parameterValue: (dictionary?["secondShoppingDiscount"] as? Double)!))
            self.companyParameters.parameters.append(Parameters(parameterName:"diversifiedConsumptions" ,parameterValue: (dictionary?["diversifiedConsumptions"] as? Double)!))
            self.companyParameters.parameters.append(Parameters(parameterName:"standardPresenceCoin" ,parameterValue: (dictionary?["standardPresenceCoin"] as? Double)!))
            self.companyParameters.parameters.append(Parameters(parameterName:"diversifiedPresenceCoin" ,parameterValue: (dictionary?["diversifiedPresenceCoin"] as? Double)!))
            self.companyParameters.parameters.append(Parameters(parameterName:"weeklyThreshold" ,parameterValue: (dictionary?["weeklyThreshold"] as? Double)!))
            
             for(_,valore) in (dictionary?["days"] as? NSDictionary)! {
                self.companyParameters.days.append(valore as? String)
             }
            
            self.myTable.reloadData()
        })
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return self.sectionTitle.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.sectionTitle[section]
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return self.companyParameters.parameters.count
        case 1:
            return self.self.daysOfWeek.count
        default:
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: UITableViewCell?
        
        if indexPath.section == 0 {
            cell = tableView.dequeueReusableCell(withIdentifier: "companyParametersCell", for: indexPath)
            let parameter = self.companyParameters.parameters[indexPath.row]
            (cell as! CompanyParametersTableViewCell).parameterName.text = parameter.parameterName
            (cell as! CompanyParametersTableViewCell).parameterValue.text = String(format:"%.2f", parameter.parameterValue!)
            cell?.accessoryType = UITableViewCellAccessoryType.detailButton
           
            //cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            
            (cell as! CompanyDaysParametersTableViewCell).daysOfWeek.text = self.daysOfWeek[indexPath.row]
            self.myIndexPath.append(indexPath)
            let isAnIndicatedDay = self.companyParameters.days.contains(where: { (value)-> Bool in
                value == self.daysOfWeek[indexPath.row]
            })
            if  isAnIndicatedDay {
                (cell as! CompanyDaysParametersTableViewCell).daysSelected.isOn = true
            } else {
              (cell as! CompanyDaysParametersTableViewCell).daysSelected.isOn = false
            }
            (cell as! CompanyDaysParametersTableViewCell).daysSelected.tag = indexPath.row
            (cell as! CompanyDaysParametersTableViewCell).daysSelected.addTarget(self, action: #selector(switchAction(_:)), for: .touchUpInside)
        }
        return cell!
    }
    
    @objc func switchAction( _ sender: UISwitch!) {
        let cell = self.myTable.cellForRow(at: myIndexPath[sender.tag])
        
        if sender.isOn == true {
            self.companyParameters.days.append((cell as! CompanyDaysParametersTableViewCell).daysOfWeek.text)
        } else  if sender.isOn == false{
            for index in 0...self.companyParameters.days.count-1 {
                if self.companyParameters.days[index] == (cell as! CompanyDaysParametersTableViewCell).daysOfWeek.text {
                    self.companyParameters.days.remove(at: index)
                    return
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let thisCell = tableView.cellForRow(at: indexPath)
        
        if  thisCell?.reuseIdentifier == "companyParametersCell" {
            let alert = UIAlertController(title: "Cambia il parametro", message: "Inserisci valore", preferredStyle: .alert)

            alert.addTextField { (textField) in
                textField.text = String(format:"%.2f",self.companyParameters.parameters[indexPath.row].parameterValue!)
                textField.clearButtonMode = .whileEditing
            }
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] (_) in
                let textField = alert?.textFields![0] // Force unwrapping because we know it exists.
                self.companyParameters.parameters[indexPath.row].parameterValue = Double((textField?.text)!)
                self.myTable.reloadData()
            }))
            
            self.present(alert, animated: true, completion: nil)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    @IBAction func saveOnFirebase(_ sender: UIButton) {
        self.updateNewValuesOnFirebase()
    }
    
    func updateNewValuesOnFirebase(){
        var newValuesDictionary = [String:Any]()
        var daysOfWeek = [String:String]()
        
        for parameter in self.companyParameters.parameters {
            newValuesDictionary[parameter.parameterName!] = parameter.parameterValue
        }
        var count = 0
        for day in self.companyParameters.days {
            daysOfWeek["day"+String(count)] = day
            count += 1
        }
        newValuesDictionary["days"] = daysOfWeek
        
        
        FireBaseAPI.updateNode(node: "merchantPointsParameters/mr001", value: newValuesDictionary)
        
    }
    
}
