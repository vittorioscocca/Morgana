//
//  UserCityAndBirthdayViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 24/10/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit
import UserNotifications

class UserCityAndBirthdayViewController: UIViewController, UITextFieldDelegate,UITableViewDelegate, UITableViewDataSource {

    var user: User?
    var cityList = ["Acerra","Acireale","Afragola","Agrigento","Alessandria","Altamura","Ancona","Andria","Anzio","Aprilia","Arezzo","Asti","Avellino","Aversa","Bagheria","Bari","Barletta","Battipaglia","Benevento","Bergamo","Bisceglie","Bitonto","Bologna","Bolzano","Brescia","Brindisi","Busto Arsizio", "Cagliari", "Caltanissetta", "Carpi", "Carrara", "Caserta", "Casoria", "Castellammare di Stabia","Catania","Catanzaro","Cava de' Tirreni", "Cerignola","Cesena","Chieti","Cinisello", "Balsamo", "Civitavecchia", "Como","Cosenza", "Cremona", "Crotone", "Cuneo","Ercolano","Faenza","Fano","Ferrara","Fiumicino","Firenze","Foggia","Foligno","Forlì","Gallarate","Gela","Genoa","Giugliano in Campania","Grosseto","Guidonia", "Montecelio","Imola","La Spezia","Lamezia Terme", "Latina","Lecce","Legnano","Livorno","Lucca","L’Aquila","Manfredonia","Marano di Napoli","Marsala","Massa","Matera","Mazara del Vallo", "Messina",  "Milano", "Modena", "Modica", "Molfetta", "Moncalieri","Montesilvano","Monza","Napoli","Novara","Olbia","Padua","Palermo","Parma","Pavia","Perugia","Pesaro","Pescara","Piacenza","Pisa","Pistoia","Pomezia","Pordenone","Portici","Potenza","Pozzuoli","Prato","Quartu Sant'Elena","Ragusa","Ravenna","Reggio Calabria","Reggio Emilia", "Rho", "Rimini", "Roma", "Rovigo", "Salerno", "San Severo","Sanremo","Sassari","Savona","Scafati","Scandicci","Sesto San Giovanni", "Siena", "Siracuse", "Taranto","Teramo","Terni","Tivoli","Torre del Greco", "Trani", "Trapani", "Trento", "Treviso", "Trieste","Torino","Udine","Varese","Velletri","Venezia","Verona","Viareggio","Vicenza","Vigevano","Viterbo","Vittoria"]
    
    var previousModifiedBirthday: String?
    var previuosModifiedCityOfrecidence: String?
    var listaFiltrata = [String]()
   
    
    @IBOutlet var myTable: UITableView!
    @IBOutlet weak var scheduledBirthdayNotification: UILabel!
    
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
                self.previuosModifiedCityOfrecidence = dictionary!["cityOfRecidence"] as? String
            }
            if dictionary!["birthday"] as? String != nil {
                self.birthday_label.text = dictionary!["birthday"] as? String
                self.previousModifiedBirthday = dictionary!["birthday"] as? String
                
                //initilize data picker with readed date on Firebase
                if (dictionary!["birthday"] as? String)! != "" {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat =  "dd-MM-yyyy"
                    let date = dateFormatter.date(from: (dictionary!["birthday"] as? String)!)
                    self.myDatePicker.date = date!
                }
            }
        })
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "merchantOrder/mr001/\((self.user?.idApp)!)/birthday", onCompletion: { (error,dictionary) in
            if dictionary != nil {
                let notificationIdentifier = dictionary?.keys
                let dataDictionary = dictionary![(notificationIdentifier!.first)!] as? NSDictionary
                self.scheduledBirthdayNotification.text = "Ti offriremo una consumazone il \((dataDictionary!["birthdayScheduledNotification"] as? String)!)"
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
    
    private func callAlert(msg: String){
        let alert = UIAlertController(title: "", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func saveOnFirebase(_ sender: UIButton) {
        
        if previousModifiedBirthday != self.birthday_label.text {
            FireBaseAPI.updateNode(node: "users/\((self.user?.idApp)!)", value: ["birthday":self.birthday_label.text!], onCompletion: {_ in
                self.callAlert(msg: "Il giorno del tuo compleanno il Morgana ti offrirà una consumazione")
            })
            //read on Firebase previous identifierNotification and kill it
            FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "merchantOrder/mr001/\((self.user?.idApp)!)/birthday", onCompletion: { (error,dictionary) in
                if dictionary != nil {
                    let notificationIdentifier = dictionary?.keys
                    let dataDictionary = dictionary![(notificationIdentifier!.first)!] as? NSDictionary
    
                    let center = UNUserNotificationCenter.current()
                    center.removePendingNotificationRequests(withIdentifiers: [(notificationIdentifier!.first)!])
                    print("scheduled notification killed")
                    
                    FireBaseAPI.removeNode(node: "merchantOrder/mr001/\((self.user?.idApp)!)/birthday")
                    let newNotificationIdentifier = FireBaseAPI.setId(node: "merchantOrder/mr001/\((self.user?.idApp)!)/birthday")
                    self.birthdayCompanyOrder(birthdayDate: self.birthday_label.text!, comparationDate: dataDictionary!["birthdayScheduledNotification"] as? String,schedulationType: dataDictionary!["schedulationType"] as? String, notificationIdentifier: newNotificationIdentifier)
                } else {
                    FireBaseAPI.removeNode(node: "merchantOrder/mr001/\((self.user?.idApp)!)/birthday")
                    let newNotificationIdentifier = FireBaseAPI.setId(node: "merchantOrder/mr001/\((self.user?.idApp)!)/birthday")
                    self.birthdayCompanyOrder(birthdayDate: self.birthday_label.text!,comparationDate: nil,schedulationType: nil,  notificationIdentifier: newNotificationIdentifier)
                }
            })
            CoreDataController.sharedIstance.saveCityAndBirthday(idApp: (self.user?.idApp)!, cityOfRecidence: nil, birthday: self.birthday_label.text!)
            self.previousModifiedBirthday = self.birthday_label.text
            return
        }
        
        if (self.previuosModifiedCityOfrecidence != self.cityName.text) && (self.cityName.text != "") {
            FireBaseAPI.updateNode(node: "users/\((self.user?.idApp)!)", value: ["cityOfRecidence":self.cityName.text!], onCompletion: {_ in
                self.callAlert(msg: "Dati salvati correttamente")
            })
            CoreDataController.sharedIstance.saveCityAndBirthday(idApp: (self.user?.idApp)!, cityOfRecidence: self.cityName.text!, birthday: nil)
            self.previuosModifiedCityOfrecidence = self.cityName.text
            return
        }
        self.callAlert(msg: "Nessun nuovo dato inserito")
        self.previousModifiedBirthday = self.birthday_label.text
    }
    
    private func stringTodateObject(date: String)->Date? {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"
        
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT+0:00")
        dateFormatter.locale = Locale(identifier: "it_IT")
        return dateFormatter.date(from: date)
    }
    
    private func birthdayCompanyOrder(birthdayDate: String, comparationDate: String?, schedulationType: String?, notificationIdentifier: String){
       
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "merchantPointsParameters/mr001", onCompletion: { (error, dictionary) in
            let notificationDate = self.calculateNotificationDate(date: birthdayDate, comparationDate: comparationDate, schedulationType: schedulationType)
            
            FireBaseAPI.saveNodeOnFirebase(node: "merchantOrder/mr001/\((self.user?.idApp)!)/birthday/\(notificationIdentifier)", dictionaryToSave: ["birthdayScheduledNotification":notificationDate,"schedulationType":"schedulationSettings"], onCompletion:{_ in
                self.scheduledBirthdayNotification.text = "Ti offriremo una consumazione il: \(notificationDate)"
                NotificationsCenter.scheduledBirthdayOrder(title: "Buon compleanno", userIdApp: (self.user?.idApp)! ,credits : (dictionary?["birthdayCredits"] as? Double)!, body: "Eccoti \((dictionary?["birthdayCredits"] as? Double)!) crediti per acquistare quello che vuoi al Morgana! Salute!", identifier: notificationIdentifier, scheduledNotification: self.stringTodateObject(date: notificationDate)!)
                //accept: schedule new notification and save new date
                print("Eccoti \((dictionary?["birthdayCredits"] as? Double)!) euro per acquistare quello che vuoi al Morgana! Salute!")
            })
        })
    }
    
    private func formattedDate(date: Date)->Date{
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT+0:00")
        dateFormatter.locale = Locale(identifier: "it_IT")
        let stringDate = dateFormatter.string(from: date as Date)
        return dateFormatter.date(from: stringDate)!
    }
    
    private func calculateNotificationDate(date: String, comparationDate: String?,schedulationType: String?)->String{
        //if data è di quest'anno crea notifica quest'anno a meno che next year sia true: notifica anno prossimo
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"
        var birthdayDate = self.stringTodateObject(date: date)
        
        let calendar = Calendar.current
        
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(abbreviation: "GMT+0:00")!
        var components = gregorian.dateComponents([.year, .month, .day], from: birthdayDate!)
        let now = self.formattedDate(date:Date())
        var currentDate: Date
        
        if comparationDate != nil && schedulationType != nil {
            if schedulationType != "schedulationSettings" {
                currentDate = self.stringTodateObject(date: comparationDate!)!
            } else {
                currentDate = now
            }
        } else {
            currentDate = now
        }
        
        let year = calendar.component(.year, from: currentDate)
        components.year = year
        birthdayDate = gregorian.date(from: components)!
        if (birthdayDate! < currentDate) && (birthdayDate! < now) {
            components.year = year + 1
        } else {
            components.year = year
        }
        birthdayDate = gregorian.date(from: components)!
        
        return  dateFormatter.string(from: birthdayDate!)
    }
}
