//
//  CreeperDataVader.swift
//  Creeper
//
//  Created by Deepti Pandey on 16/04/18.
//  Copyright © 2018 Tapzo. All rights reserved.
//

import UIKit
import CoreData

public class CreeperDataVader: NSObject {
    
    enum EventFlushStatus: String {
        case Todo = "TODO",
        Done = "DONE"
    }
    
    let kEvent: String = "event"
    let kMessageId: String = "messageId"
    let kOriginalTimestamp: String = "original_timestamp"
    let kSentAt: String = "sentAt"
    let kProperties: String = "properties"
    let kNetworkStrength: String = "network_strength"
    let kType: String = "type"
    private static var privateShared : CreeperDataVader?
    
    
    class func sharedInstance() -> CreeperDataVader {
        guard let aSharedInstance = privateShared else {
            privateShared = CreeperDataVader()
            return privateShared!
        }
        
        aSharedInstance.startTimer()
        return aSharedInstance
    }
    deinit {
        CreeperDataVader.sharedInstance().invalidateTimer()
    }
    lazy var applicationDocumentsDirectory: URL = {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1]
    }()
    let creeperBundleIdentifier: String = "com.tapzo.Creeper"
    let resourceName: String = "Creeper"
    let resourceType: String = "momd"
    lazy var flushTimer = Timer()

    lazy var managedObjectModel: NSManagedObjectModel = {
        
        if let bundle = Bundle(identifier: CreeperDataVader.sharedInstance().creeperBundleIdentifier),
            let aPath = bundle.path(forResource: CreeperDataVader.sharedInstance().resourceName, ofType: CreeperDataVader.sharedInstance().resourceType), let path = URL.init(string: aPath){
            print("****CoreData Managed Object Module configure with .momd ****")
            return NSManagedObjectModel(contentsOf: path)!
        } else {
            if let bundle = Bundle(identifier:CreeperDataVader.sharedInstance().creeperBundleIdentifier), let model = NSManagedObjectModel.mergedModel(from: [bundle]){
                print("****CoreData Managed Object Module configure with mergedModel****")
                return model
            }
        }
        print("****Unable to configure CoreData Managed Object Module****")
        abort()
    }()
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        
        var db = "Creeper_v1.sqlite"
        let url = self.applicationDocumentsDirectory.appendingPathComponent(db)
        
        print("DB => \(url)")
        
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
        } catch {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data" as AnyObject?
            dict[NSLocalizedFailureReasonErrorKey] = failureReason as AnyObject?
            
            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "com.tapzo.Creeper", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            abort()
        }
        
        return coordinator
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()
    internal func startTimer(){
        invalidateTimer()
        print("Flush Timer started")
        let timeInt: Double = 1.0 // every 1 sec we are checking whether either buffer full or data too old
        
        flushTimer = Timer.scheduledTimer(timeInterval: timeInt, target: self,
                                     selector: #selector(CreeperDataVader.fetchTopEventAndCheckIfItIsOldEnough), userInfo: nil, repeats: true)
        
    }
    internal func invalidateTimer(){
        flushTimer.invalidate()
        print("Flush Timer stopped")
    }
    
    func track(_ name: String, dict: [String: AnyObject]){
        if let managedContext : NSManagedObjectContext = managedObjectContext{
            let entity =
                NSEntityDescription.entity(forEntityName: "EventEntity",
                                           in: managedContext)!
            let eventEntry: EventEntity = NSManagedObject(entity: entity, insertInto: managedContext) as! EventEntity
            eventEntry.eventName = name
            
            eventEntry.messageId = UUID().uuidString // check this fortime based
            if let value = dict["original_timestamp"] as? Date{
                eventEntry.originalTimestamp = value as NSDate
            }else{
                eventEntry.originalTimestamp = NSDate()
            }
            eventEntry.sentAt = NSDate()
            eventEntry.type = "track"
            eventEntry.status = EventFlushStatus.Todo.rawValue
            eventEntry.properties = dict
            saveContext()
        }
    }
    
    
    @objc func fetchTopEventAndCheckIfItIsOldEnough(){
        let eventsToSend = getEventsToSend()
        var messageIds: [String] = []
        for event in eventsToSend{
            if let messageID = event.messageId{
                messageIds.append(messageID)
            }
        }
        if eventsToSend.count > 0{
            if isLastCallOldEnough() || isBufferFull() {
                Creeper.shared.pushEvents(createDictFromEvents(eventsToSend), messageIDs: messageIds)
            }
        }
    }
    
    func createDictFromEvents(_ events: [EventEntity]) -> [[String: AnyObject]]{
        var dicts: [[String: AnyObject]] = []
        for event in events{
            var dict: [String: AnyObject] = [:]
            dict[kEvent] = event.eventName as AnyObject
            dict[kMessageId] = event.messageId as AnyObject
            if let timeStamp = event.originalTimestamp{
                dict[kOriginalTimestamp] = "\(timeStamp)" as AnyObject
            }
            if let sentat = event.sentAt{
                dict[kSentAt] = "\(sentat)" as AnyObject
            }
            if let propertiesDict = event.properties{
                dict[kProperties] = propertiesDict as AnyObject
            }
            dict[kNetworkStrength] = 1 as AnyObject  // hard coding because this is absolutely required and not optional anymore, just following what android does
            dict[kType] = event.type as AnyObject
            dicts.append(dict)
        }
        return dicts
    }
   
    func isBufferFull() -> Bool{
        var batchSize: Int = 20
        if let configdata = NetworkVader.sharedVader.fetchSavedConfig(){
            batchSize = configdata.batchSize
        }
        let eventCount = getEventsToSend().count
        let returnAns = eventCount >= batchSize
        if returnAns{
            print("\n Buffer full as  buffer count = ", eventCount)
        }
        return returnAns
    }
    func isLastCallOldEnough() -> Bool {
        if let lastPushAttemptDate = Creeper.sharedUserDefaults.object(forKey: Creeper.shared.kLastDatePushAttempted) as? Date, let configdata = NetworkVader.sharedVader.fetchSavedConfig(){
            let timeInterval = configdata.interval
            if Date().timeIntervalSince1970 - lastPushAttemptDate.timeIntervalSince1970 > Double(timeInterval)/1000{
                print("\n Data is old as ")
                print("\n last push api time =", lastPushAttemptDate)
                print("\n last event time =", Date())
                return true
            }else{
                return false
            }
        }else{
            print("\n No last date saved")
            return true
        }
    }
    func getEventsToSend() -> [EventEntity]{
        var eventsToSend: [EventEntity] = []
        let fetchRequest = NSFetchRequest<EventEntity>(entityName: "EventEntity")
        fetchRequest.fetchLimit = 20             // make it batchsize instead of 20
        fetchRequest.predicate = NSPredicate(format: "status == %@", EventFlushStatus.Todo.rawValue)
        let sort = NSSortDescriptor(key: #keyPath(EventEntity.originalTimestamp), ascending: true)
        if let configdata = NetworkVader.sharedVader.fetchSavedConfig(){
            let bsize = configdata.batchSize
            fetchRequest.fetchLimit = bsize
        }
        fetchRequest.sortDescriptors = [sort]
        do {
            let events = try managedObjectContext.fetch(fetchRequest)
            eventsToSend = events
            saveContext()
            
        } catch {
            print("Cannot fetch events")
        }
        return eventsToSend
    }
    
    func updateSentEvents(_ messageIDs: [String]){
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "EventEntity")
        fetchRequest.fetchLimit = 20
        if let configdata = NetworkVader.sharedVader.fetchSavedConfig(){
            let bsize = configdata.batchSize
            fetchRequest.fetchLimit = bsize
        }
        var predicateArray: [NSPredicate] = []
        for messageID in messageIDs{
            let pred = NSPredicate(format: "messageId == %@", messageID)
            predicateArray.append(pred)
        }
        let orPredicate = NSCompoundPredicate(type: NSCompoundPredicate.LogicalType.or, subpredicates: predicateArray)
        fetchRequest.predicate = orPredicate

        do {
            let events = try managedObjectContext.fetch(fetchRequest) as! [EventEntity]
            for event in events{
                event.setValue(EventFlushStatus.Done.rawValue, forKey: "status")
            }
            saveContext()
            
        } catch {
            print("Cannot fetch events")
        }
    }
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                let nserror = error as NSError
                NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
                abort()
            }
        }
    }
}
