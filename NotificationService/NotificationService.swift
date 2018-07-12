//
//  NotificationService.swift
//  NotificationoService
//
//  Created by Vittorio Scocca on 21/06/18.
//  Copyright © 2018 Vittorio Scocca. All rights reserved.
//

import UserNotifications


class NotificationService: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        
        guard let bestAttemptContent = bestAttemptContent,
            let apsData = bestAttemptContent.userInfo["aps"] as? [String: Any], // 2. Dig in the payload to get the
            let attachmentURLAsString = apsData["attachment-url"] as? String, // 3. The attachment-url
            let attachmentURL = URL(string: attachmentURLAsString) else { // 4. And parse it to URL
                return
        }
        
        //setCategories()
    
        downloadImageFrom(url: attachmentURL) { (attachment) in
            if attachment != nil {
                bestAttemptContent.attachments = [attachment!]
                contentHandler(bestAttemptContent)
            }
        }
        
    }
    
    private func setCategories(){
        
        let deleteExpirationAction = UNNotificationAction(identifier: "delete.action",title: "Non ricordarlmelo più",options: [])
        let acceptOrderAction = UNNotificationAction(identifier: "acceptOrder.action",title: "eheh",options: [.foreground])
        let refuseOrderAction = UNNotificationAction(identifier: "refuseOrder.action",title: "Rifiuta",options: [])
        let acceptCredits = UNNotificationAction(identifier: "acceptCredits.action",title: "Accetta i crediti",options: [])
        
        let remeberExpirationCategory = UNNotificationCategory(identifier: "RemeberExpiration",actions: [deleteExpirationAction],intentIdentifiers: [],options: [])
        let OrderSentCategory = UNNotificationCategory(identifier: "OrderSent",actions: [acceptOrderAction,refuseOrderAction],intentIdentifiers: [],options: [])
        let birthdayNotificationCategory = UNNotificationCategory(identifier: "birthdayNotification",actions: [acceptCredits],intentIdentifiers: [],options: [])
        UNUserNotificationCenter.current().setNotificationCategories([remeberExpirationCategory,OrderSentCategory,birthdayNotificationCategory])
    }
    
    private func downloadImageFrom(url: URL, with completionHandler: @escaping (UNNotificationAttachment?) -> Void) {
        let task = URLSession.shared.downloadTask(with: url) { (downloadedUrl, response, error) in
            // 1. Test URL and escape if URL not OK
            guard let downloadedUrl = downloadedUrl else {
                completionHandler(nil)
                return
            }
            
            // 2. Get current's user temporary directory path
            var urlPath = URL(fileURLWithPath: NSTemporaryDirectory())
            // 3. Add proper ending to url path, in the case .jpg (The system validates the content of attached files before scheduling the corresponding notification request. If an attached file is corrupted, invalid, or of an unsupported file type, the notification request is not scheduled for delivery. )
            let uniqueURLEnding = ProcessInfo.processInfo.globallyUniqueString + ".png"
            urlPath = urlPath.appendingPathComponent(uniqueURLEnding)
            
            // 4. Move downloadedUrl to newly created urlPath
            try? FileManager.default.moveItem(at: downloadedUrl, to: urlPath)
            
            // 5. Try adding getting the attachment and pass it to the completion handler
            do {
                let attachment = try UNNotificationAttachment(identifier: "picture", url: urlPath, options: nil)
                completionHandler(attachment)
            }
            catch {
                completionHandler(nil)
            }
        }
        task.resume()
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    /*
     private func createAttachment(identifier: String, image: UIImage?, options: [AnyHashable : Any]?) -> UNNotificationAttachment? {
     do {
     if let userImage = image {
     if let roundedImage = maskRoundedImage(image: userImage) {
     if let newImageData =  UIImagePNGRepresentation(roundedImage) {
     let docDir = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
     let imageURL = docDir.appendingPathComponent("\(UUID().uuidString).png")
     try newImageData.write(to: imageURL)
     return try UNNotificationAttachment.init(identifier: identifier, url: imageURL, options: options)
     }
     }
     }
     } catch {
     print("Unable to create image attachment for missed call notification \(error.localizedDescription)")
     }
     return nil
     }
     
     private func maskRoundedImage(image: UIImage) -> UIImage? {
     let imageView: UIImageView = UIImageView(image: image)
     
     imageView.layer.masksToBounds = true
     imageView.layer.cornerRadius = imageView.frame.size.width / 2
     
     UIGraphicsBeginImageContext(imageView.bounds.size)
     
     defer {
     UIGraphicsEndImageContext()
     }
     guard let context = UIGraphicsGetCurrentContext() else {
     return nil
     }
     
     imageView.layer.render(in:context )
     
     guard let roundedImage = UIGraphicsGetImageFromCurrentImageContext() else {
     return nil
     }
     return roundedImage
     }*/
    
}
