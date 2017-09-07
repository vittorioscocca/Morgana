//
//  DrinksPricesViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 04/04/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit
import WebKit

//WebView of Morgana WebSite 
class DrinksPricesViewController: UIViewController {

    @IBOutlet weak var myTextField_field: UITextField!
    @IBOutlet weak var myProgressView: UIProgressView!
    @IBOutlet weak var myView: UIView!
    
    var webView: WKWebView!
    var urlNavigazione: [String] = []
    var urlPrecedente: Int = 0
    var urlCorrente: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.myTextField_field.frame.size.width = self.view.frame.width
        self.webView = WKWebView(frame: self.view.frame)
        self.myView.addSubview(self.webView)
        self.webView.addObserver(self, forKeyPath: "estimatedProgressPrices", options: .new, context: nil)
        self.loadURL("www.morganazone.it/musiclub/menu/") // invoco la funzione loadURL e richiedo la visualizzazione del sito di partenza
        self.myTextField_field.text = "www.morganazone.it/musiclub/menu/"
        self.urlNavigazione.append("www.morganazone.it/musiclub/menu/")
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        //print("\(navigationAction.request.url?.absoluteString)")
        decisionHandler(.allow)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func aggiornaNavigazione(url:String) {
        self.urlNavigazione.append(url)
        self.urlCorrente += 1
        self.urlPrecedente = urlCorrente - 1
    }
    
    func loadURL(_ fromString: String) {
        var url: URL?
        
        url = URL(string: "http://" + fromString) // creo un URL partendo dalla stringa
        let request = URLRequest(url: url!) // creo la richiesta da far effettuare alla webview
        self.webView.load(request) // performo la richiesta
        self.aggiornaNavigazione(url: fromString)
    }
    
    
    func searchOnGoogle(_ fromString: String) {
        let stringArray = fromString.components(separatedBy: " ") // divido la stringa in un array per ogni parola divisa dallo spazio " "
        let searchString = stringArray.joined(separator: "+") // ricompatto la stringa mettendo il simbolo "+" tra ogni elemento dell'array
        let url = URL(string: "https://www.google.com/search?q=" + searchString)
        let request = URLRequest(url: url!) // creo la richiesta da far effettuare alla webview
        self.webView.load(request) // performo la richiesta
        
    }
    
    //observer control
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if (keyPath == "estimatedProgressPrices") {
            myProgressView.isHidden = webView.estimatedProgress == 1
            myProgressView.setProgress(Float(webView.estimatedProgress), animated: true)
        }
    }
    deinit {
        webView?.removeObserver(self, forKeyPath: "estimatedProgressPrices")
    }
    
    @IBAction func textField_DidEnd(_ sender: UITextField) {
        guard let testo = sender.text else {return}
        
        
        if testo.hasPrefix("www") {
            self.loadURL(testo)
        } else {
            self.searchOnGoogle(testo)
        }
    }
    
    @IBAction func urlPrecedente_pressed(_ sender: UIBarButtonItem) {
        guard  self.webView.canGoBack else{
            return
        }
        self.webView.goBack()
        
    }
    
    @IBAction func urlSuccessiva_pressed(_ sender: UIBarButtonItem) {
        guard self.webView.canGoForward else{
            return
        }
        self.webView.goForward()
    }
}
