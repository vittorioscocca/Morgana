//
//  EventsViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 04/04/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit
import WebKit

//this is a webView of Facebook Page Event
class EventsViewController: UIViewController {
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
        
        self.webView.addObserver(self, forKeyPath: "estimatedProgressEvent", options: .new, context: nil)
        
        self.loadURL("www.facebook.com/pg/morganamusiclub/events/?ref=page_internal") // invoco la funzione loadURL e richiedo la visualizzazione del sito di partenza
        self.myTextField_field.text = "www.facebook.com/pg/morganamusiclub/events/?ref=page_internal"
        self.urlNavigazione.append("www.facebook.com/pg/morganamusiclub/events/?ref=page_internal")
    }
   
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        print("\(navigationAction.request.url!.absoluteString)")
        decisionHandler(.allow)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func aggiornaNavigazione(url:String) {
        self.urlNavigazione.append(url)
        self.urlCorrente += 1
        self.urlPrecedente = urlCorrente - 1
    }
    
    func loadURL(_ fromString: String) {
        var url: URL?
        
        url = URL(string: "https://" + fromString)
        let request = URLRequest(url: url!)
        self.webView.load(request)
        self.aggiornaNavigazione(url: fromString)
    }
    
   
    func searchOnGoogle(_ fromString: String) {
        
        // searching "word1+word2"
        let stringArray = fromString.components(separatedBy: " ")
        let searchString = stringArray.joined(separator: "+")
        let url = URL(string: "https://www.google.com/search?q=" + searchString)
        let request = URLRequest(url: url!) // creo la richiesta da far effettuare alla webview
        self.webView.load(request) // performo la richiesta
        
    }
    
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if (keyPath == "estimatedProgressEvent") {
            myProgressView.isHidden = webView.estimatedProgress == 1
            myProgressView.setProgress(Float(webView.estimatedProgress), animated: true)
        }
    }
    deinit {
         webView?.removeObserver(self, forKeyPath: "estimatedProgressEvent")
    }
    
    @IBAction func textField_DidEnd(_ sender: UITextField) {
        guard let testo = sender.text else {return}
        
        // se l'utente inserisce una stringa che comincia per "www" allora vuole collegarsi ad un sito web
        if testo.hasPrefix("www") {
            self.loadURL(testo)
        } else {
            // altrimenti sta provando a cercare su google
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
