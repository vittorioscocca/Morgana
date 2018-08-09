//
//  PointsManager.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 04/09/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation

public extension NSNotification.Name {
    static let ReadingRemoteUserPointDidFinish = NSNotification.Name("ReadingRemoteUserPointDidFinish")
    
}

class PointsManager {
    static let sharedInstance = PointsManager()
    
    //usersPointsStats
    private var lastDateShopping: TimeInterval?//time of last weekly shopping
    private var personalDiscount: Double?
    private var totalCurrentPoints: Int?  //punteggio corrente, si azzera dopo la conversione in crediti
    private var totalDiversifiedConsumptions: Int?  //totale delle consumazioni differenziate
    private var totalShopping: Double?  // storico, totale € consumati
    private var totalExtraDiscountShopping: Double?  // totale spesa in extra sconto
    private var totalFreeMoney: Double?  // corrispndenza in € rispetto ai punti totali
    private var currentFreeMoney: Double? //corrispndenza in € rispetto ai punti correnti
    private var totalPoints: Int?  //storico di tutto il punteggio cumulato da un utente
    private var totalPresence: Int? // numero di volte che ci si è registrati
    private var totalStandardShopping: Double?  // total spesa in sconto standard, la somma di queste due variabili genera totalExpense
    private var totalStandardConsumptions: Int? // totale delle consumazioni standard
    private var weeklyShopping: Double?
    
    //merchant Points Parameters
    private var changeCreditToPoint: Double? //cambio da Crediti a Punti, attualmente 1P = 0,02€
    private var standardConsumptions: Double? //gettone per le consumazioni standard, attualmente 0.02€ 1 Punto
    private var firstShoppingDiscount: Double?  //prima percentuale di sconto sugli acquisti, attualmente 0,1€ = 5 Punti
    private var secondShoppingDiscount: Double?  //seconda percentuale di sconto sugli acquisti, attualmente 0,2€ = 10 Punti
    private var diversifiedConsumptions: Double? // gettone per le consumazioni diversificate, attualmente 0.04€ = 2 Punti
    private var standardPresenceCoin: Double?  //
    private var diversifiedPresenceCoin: Double?
    private var weeklyThreshold: Double? //soglia di consumo settimanale superato il quale si passa alla seconda percentuale di sconto
    
    //gestione dei giorni della settimana
    private var days: [Int?]
    private let daysOfWeek: [String:Int] = [
         "Domenica" :  1,
         "Lunedì"   :  2,
         "Martedì"  :  3,
         "Mercoledì":  4,
         "Giovedì"  :  5,
         "Venerdì"  :  6,
         "Sabato"   :  0
    ]
    
    var balanceCurrentPoints: Int {
        get {
            return self.totalCurrentPoints!
        }
        set(newValue) {
            if newValue < 0 {
                print("stai provando ad inserire un valore negativo")
                return
            }
            self.totalCurrentPoints = newValue
        }
    }
    
   
    private var fireBaseToken = UserDefaults.standard
    
    
    //Metodi
    private init(){
        self.days = [Int]()
        let uid = fireBaseToken.object(forKey: "FireBaseToken") as? String
        
        readUserPointsStatsOnFirebase(userId: (CoreDataController.sharedIstance.findUserForIdApp(uid)?.idApp)!) { (error) in
            if error != nil {
                print("\(String(describing: error?.description))")
            }
            NotificationCenter.default.post(name: .ReadingRemoteUserPointDidFinish, object: self)
        }
    }
    
    func readUserPointsStatsOnFirebase (userId: String,onCompletion: @escaping (String?)->()) {
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "usersPointsStats/"+userId, onCompletion: { (error,dictionary) in
            guard error == nil else {
                print(error!)
                onCompletion(error)
                return
            }
            guard dictionary != nil else {return}
            
            self.personalDiscount = dictionary?["personalDiscount"] as? Double
            self.totalCurrentPoints = dictionary?["totalCurrentPoints"] as? Int
            self.totalExtraDiscountShopping = dictionary?["totalExtraDiscountShopping"] as? Double
            self.totalFreeMoney = dictionary?["totalFreeMoney"] as? Double
            self.currentFreeMoney = dictionary?["currentFreeMoney"] as? Double
            self.totalStandardShopping = dictionary?["totalStandardShopping"] as? Double
            self.weeklyShopping = dictionary?["weeklyShopping"] as? Double
            self.totalShopping = dictionary?["totalShopping"] as? Double
            self.totalPresence = dictionary?["totalPresence"] as? Int
            self.totalStandardConsumptions = dictionary?["totalStandardConsumptions"] as? Int
            self.totalDiversifiedConsumptions = dictionary?["totalDiversifiedConsumptions"] as? Int
            self.lastDateShopping = dictionary?["lastDateShopping"] as? TimeInterval
            self.totalPoints = dictionary?["totalPoints"] as? Int

            self.readMerchantParameters {
                onCompletion(error)
            }
        })
    }
    
    private func readMerchantParameters(onCompletion: @escaping ()->()) {
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "merchantPointsParameters/mr001", onCompletion: { (error,dictionary) in
            guard error == nil else {
                print(error!)
                return
            }
            guard dictionary != nil else {return}
            
            self.standardConsumptions = dictionary?["standardConsumptions"] as? Double
            self.firstShoppingDiscount = dictionary?["firstShoppingDiscount"] as? Double
            self.secondShoppingDiscount = dictionary?["secondShoppingDiscount"] as? Double
            self.diversifiedConsumptions = dictionary?["diversifiedConsumptions"] as? Double
            self.standardPresenceCoin = dictionary?["standardPresenceCoin"] as? Double
            self.diversifiedPresenceCoin = dictionary?["diversifiedPresenceCoin"] as? Double
            self.weeklyThreshold = dictionary?["weeklyThreshold"] as? Double
            self.changeCreditToPoint = dictionary?["changeCreditToPoint"] as? Double
            
            for(_,valore) in (dictionary?["days"] as? NSDictionary)! {
                self.days.append(self.daysOfWeek[(valore as? String)!])
            }
            onCompletion()
    })

    }
    
    func addPointsForShopping(userId: String,expense: Double)->Int{
        if personalDiscount == 0 {
            personalDiscount = firstShoppingDiscount
        }
        
        guard let discount = personalDiscount,
            let weekThreshold = weeklyThreshold,
            let weekShopping = weeklyShopping
        else { return 0 }
        let newPoints = Int(expense * discount / changeCreditToPoint!)
        
        currentFreeMoney! += (expense * discount)
        balanceCurrentPoints += newPoints
        totalPoints! += newPoints
        
        if weekShopping > weekThreshold {
            totalExtraDiscountShopping! += expense
        }else {
            totalStandardShopping! += expense
        }
        self.totalShopping! += expense
        
        if isAWeeklyShopping(userId: userId) {
            weeklyShopping = weekShopping + expense
        }else {
            weeklyShopping = expense
        }
        if weekShopping > weekThreshold {
            personalDiscount = secondShoppingDiscount
        }
        return newPoints
    }
    
    func addPointsForRegistrations(){
        
    }
    
    private func addPointsForStandardConsumption(_ numberOfProducts: Int) {
        totalStandardConsumptions! += 1
        balanceCurrentPoints += Int(Double(numberOfProducts)*standardConsumptions!/changeCreditToPoint!)
    }
    
    private func addPointsForDiversifiedConsumption(_ numberOfProducts: Int){
        totalDiversifiedConsumptions! =   1
        balanceCurrentPoints = Int(Double(numberOfProducts)*diversifiedConsumptions!/changeCreditToPoint!)
    }
    
    func addPointsForConsumption(date: Date, numberOfProducts: Int)->Int {
        
        let weekday = Calendar.current.component(.weekday, from: date)
        
        let isAnIndicatedDay = days.contains(where: { (value)-> Bool in
            value == weekday
        })
        
        if isAnIndicatedDay {
            addPointsForDiversifiedConsumption(numberOfProducts)
        }else {
            addPointsForStandardConsumption(numberOfProducts)
        }
        return balanceCurrentPoints
    }
    
    
    func totalUsersPoints()->Int {
        return balanceCurrentPoints
    }
    
    func updateNewValuesOnFirebase(actualUserId: String, onCompletion: @escaping ()->()){
        
        let newValuesDictionary: [String: Any] = [
            "personalDiscount": self.personalDiscount!,
            "currentFreeMoney": self.currentFreeMoney!,
            "totalCurrentPoints": self.totalCurrentPoints!,
            "totalExtraDiscountShopping": self.totalExtraDiscountShopping!,
            "totalFreeMoney": self.totalFreeMoney!,
            "totalStandardShopping": self.totalStandardShopping!,
            "weeklyShopping": self.weeklyShopping!,
            "totalShopping": self.totalShopping!,
            "totalPresence": self.totalPresence!,
            "totalStandardConsumptions": self.totalStandardConsumptions!,
            "totalDiversifiedConsumptions": self.totalDiversifiedConsumptions!,
            "totalPoints": self.totalPoints!
        ]
        
        FireBaseAPI.updateNode(node: "usersPointsStats/"+actualUserId, value: newValuesDictionary)
        onCompletion()
    }
    
    //control if the current shopping fifferencies from last shopping of 1 week
    private func isAWeeklyShopping(userId: String)->Bool {
        
        //Ultima data valida
        let date = NSDate(timeIntervalSince1970: self.lastDateShopping!/1000)
        let dateFormatter = DateFormatter()
        dateFormatter.amSymbol = "AM"
        dateFormatter.pmSymbol = "PM"
        dateFormatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
        let dateString = dateFormatter.string(from: date as Date)
        let finalDate = dateFormatter.date(from: dateString)

        let diffTime = (finalDate?.timeIntervalSinceNow)! * -1
        
        // se la differenza tra la data corrente e l'ultima data su Firebase è maggiore di una settimana si sostituisce l'ultima data 
        //604800: settimana in secondi
        if diffTime < 604800 {
            return true
        }else {
            FireBaseAPI.returnFirebaseTimeStamp(onCompletion: { (FIRTimestamp) in
                guard FIRTimestamp != nil else {
                    print("errore nel recupero del Firtimestamp")
                    return
                }
                let dictionaryToUpload :[String:TimeInterval] = ["lastDateShopping":FIRTimestamp!, "personalDiscount":self.firstShoppingDiscount!,"weeklyShopping":0]
                FireBaseAPI.updateNode(node: "usersPointsStats/"+userId, value: dictionaryToUpload)
            })
            return false
        }
    }
    
    
    func releaseCredits(){
        
    }
    
}
