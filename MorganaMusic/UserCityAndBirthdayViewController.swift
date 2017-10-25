//
//  UserCityAndBirthdayViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 24/10/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit

class UserCityAndBirthdayViewController: UIViewController, UITextFieldDelegate,UITableViewDelegate, UITableViewDataSource {

    var user: User?
    var cityList = ["Acerra","Acireale","Afragola","Agrigento","Alessandria","Altamura","Ancona","Andria","Anzio","Aprilia","Arezzo","Asti","Avellino","Aversa","Bagheria","Bari","Barletta","Battipaglia","Benevento","Bergamo","Bisceglie","Bitonto","Bologna","Bolzano","Brescia","Brindisi","Busto Arsizio", "Cagliari", "Caltanissetta", "Carpi", "Carrara", "Caserta", "Casoria", "Castellammare di Stabia","Catania","Catanzaro","Cava de' Tirreni", "Cerignola","Cesena","Chieti","Cinisello", "Balsamo", "Civitavecchia", "Como","Cosenza", "Cremona", "Crotone", "Cuneo","Ercolano","Faenza","Fano","Ferrara","Fiumicino","Firenze","Foggia","Foligno","Forlì","Gallarate","Gela","Genoa","Giugliano in Campania","Grosseto","Guidonia", "Montecelio","Imola","La Spezia","Lamezia Terme", "Latina","Lecce","Legnano","Livorno","Lucca","L’Aquila","Manfredonia","Marano di Napoli","Marsala","Massa","Matera","Mazara del Vallo", "Messina",  "Milano", "Modena", "Modica", "Molfetta", "Moncalieri","Montesilvano","Monza","Napoli","Novara","Olbia","Padua","Palermo","Parma","Pavia","Perugia","Pesaro","Pescara","Piacenza","Pisa","Pistoia","Pomezia","Pordenone","Portici","Potenza","Pozzuoli","Prato","Quartu Sant'Elena","Ragusa","Ravenna","Reggio Calabria","Reggio Emilia", "Rho", "Rimini", "Roma", "Rovigo", "Salerno", "San Severo","Sanremo","Sassari","Savona","Scafati","Scandicci","Sesto San Giovanni", "Siena", "Siracuse", "Taranto","Teramo","Terni","Tivoli","Torre del Greco", "Trani", "Trapani", "Trento", "Treviso", "Trieste","Torino","Udine","Varese","Velletri","Venezia","Verona","Viareggio","Vicenza","Vigevano","Viterbo","Vittoria"]
    
    
    var listaFiltrata = [String]()
    
    @IBOutlet var myTable: UITableView!
    
    @IBOutlet var birthday_label: UILabel!
    @IBOutlet var myDatePicker: UIDatePicker!
    @IBOutlet var cityName: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.myTable.delegate = self
        self.myTable.dataSource = self
        self.myDatePicker.datePickerMode = UIDatePickerMode.date
        self.cityName.delegate = TextFieldController.singleton
        self.cityName.tag = 0
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "users/\((self.user?.idApp)!)", onCompletion: { (error,dictionary) in
            if dictionary!["cityOfRecidence"] as? String != nil {
                self.cityName.text = dictionary!["cityOfRecidence"] as? String
            }
            if dictionary!["birthday"] as? String != nil {
                self.birthday_label.text = dictionary!["birthday"] as? String
            }
        })
       
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func textFieldDidChange(_ sender: UITextField) {
        self.contentsFilter(text: (sender.text)!)
    }
    
    
    func contentsFilter(text: String) {
        print("sto filtrando i contenuti")
        self.listaFiltrata.removeAll(keepingCapacity: true)
        for x in self.cityList {
            if x.localizedLowercase.range(of: text.localizedLowercase) != nil {
                print("aggiungo \(x) alla listaFiltrata")
                listaFiltrata.append(x)
            }
        }
        if self.myTable.isHidden {
            self.myTable.isHidden = false
        }
        self.myTable.reloadData()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.listaFiltrata.count
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "searchCell", for: indexPath)
        cell.textLabel?.text = self.listaFiltrata[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let thisCell = tableView.cellForRow(at: indexPath)
        self.cityName.text = thisCell?.textLabel?.text
        tableView.deselectRow(at: indexPath, animated: false)
        self.myTable.isHidden = true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //richiamo la funzione creata nell'extension inserendo come parametro un array di textfield
        //per le quali voglio che sparisca la tastiera quando viene premuto al di fuori di esse
        
        self.closeTextFieldAtTouch(txtFields: [cityName])
    }
    
    @IBAction func selectMyDataPicker(_ sender: UIDatePicker) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"
        let strDate = dateFormatter.string(from: myDatePicker.date)
        self.birthday_label.text = strDate
    }
    
    @IBAction func saveLocalAndOnFirebase(_ sender: UIButton) {
        
        FireBaseAPI.updateNode(node: "users/\((self.user?.idApp)!)", value: ["birthday":self.birthday_label.text! ,"cityOfRecidence":self.cityName.text!], onCompletion: {_ in
            let alert = UIAlertController(title: "", message: "Dati salvati correttamente", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        })
        CoreDataController.sharedIstance.saveCityAndBirthday(idApp: (self.user?.idApp)!, cityOfRecidence: self.cityName.text!, birthday: self.birthday_label.text!)
    }
}
