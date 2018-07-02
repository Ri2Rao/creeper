//
//  NetworkVader.swift
//  Creeper
//
//  Created by Deepti Pandey on 10/04/18.
//  Copyright © 2018 Tapzo. All rights reserved.
//

import UIKit

class NetworkVader: NSObject {
    
    static let sharedVader = NetworkVader()
    fileprivate var eventConfig: EventConfigData?
    
    
    internal func fetchConfigData(_ deviceId: String){
        if let url = URL(string: "\(Creeper.shared.baseUrl)\(CreeperNetworkRequestType.Config.rawValue)?did=\(deviceId)"){
            var request = URLRequest(url: url)
            request.addValue(Creeper.shared.segmentKey, forHTTPHeaderField: NetworkConstants.EventKey.rawValue)
            request.addValue(NetworkConstants.ApplicationJSON.rawValue, forHTTPHeaderField: NetworkConstants.ContentType.rawValue)
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    print("error=\(String(describing: error))")
                    return
                }
                print("\n\nconfig api=", request)
                print("\n config api time =", Date())

                if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {           // check for http errors
                    print("statusCode should be 200, but is \(httpStatus.statusCode)")
                }
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:AnyObject]

                    print("\n\nconfig response JSON: \(json)")
                    self.parseConfigData(json)
                } catch let error as NSError {
                    print(error)
                }
            }
            task.resume()
        }
    }
    internal func sendEventsSync(_ params: [String: AnyObject], messageIDs: [String]) {
        if let url = URL(string: "\(Creeper.shared.baseUrl)\(CreeperNetworkRequestType.EventsPush.rawValue)"){
            var request = URLRequest(url: url)
            request.addValue(Creeper.shared.segmentKey, forHTTPHeaderField: NetworkConstants.EventKey.rawValue)
            request.addValue(NetworkConstants.ApplicationJSON.rawValue, forHTTPHeaderField: NetworkConstants.ContentType.rawValue)
            request.httpMethod = "POST"
            do {
                if JSONSerialization.isValidJSONObject(params) {
                    let body = try JSONSerialization.data(withJSONObject: params, options:[.prettyPrinted])
                    request.httpBody = body
                }
            } catch {
                print("unable to serialise")
                return
            }
            let semaphore = DispatchSemaphore(value: 1)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    print("error=\(String(describing: error))")
                    semaphore.signal()
                    return
                }
                print("\n\n push api=", request)
                Creeper.sharedUserDefaults.setValue(Date(), forKey: Creeper.shared.kLastDatePushAttempted)
                if let events = params["events"] as? [[String: AnyObject]]{
                    print("\n number of items =", events.count)
                }
                if let str = params.prettyPrintedJSON{
                    print("\n push params=\n", str)
                }
                if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {           // check for http errors
                    print("statusCode should be 200, but is \(httpStatus.statusCode)")
                }
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:AnyObject]
                    
                    print("\n\npush JSON response : \(String(describing: json))")
                    self.parseEventsPushData(json, messageIDs: messageIDs)
                } catch let error as NSError {
                    print(error)
                }
                semaphore.signal()
            }
            task.resume()
            _ = semaphore.wait(wallTimeout: DispatchWallTime.distantFuture)
        }
    }
    
    internal func fetchSavedConfig() -> EventConfigData?{
        if let defaultsConfig = Creeper.sharedUserDefaults.object(forKey: "configKey") as? [String: AnyObject] {
            let config = EventConfigData(defaultsConfig, isDataFromAPI: false)
            self.eventConfig = config
            return config
        }else{
            if let deviceId = Creeper.sharedUserDefaults.object(forKey: Creeper.shared.kDeviceId) as? String{
                Creeper.shared.fetchConfigData(deviceId)
            }
        }
        return nil
    }
    
    
    //MARK: - Parsing
    internal func parseConfigData(_ dict: [String: AnyObject]?){
        if let dict = dict{
            self.eventConfig = EventConfigData(dict, isDataFromAPI: true)
        }
    }
    
    internal func parseEventsPushData(_ dict: [String: AnyObject]?, messageIDs: [String]){
        if let dict = dict{
            if let status = dict["status"] as? String{
                if status == "success"{
                    CreeperDataVader.sharedInstance().updateSentEvents(messageIDs)
                }
            }
        }
    }
    
}
internal class EventConfigData: NSObject{
    var timestamp: Date = Date()
    var batchSize: Int = 20
    var exclusionEvents: [EventDescription] = []
    var interval: Int64 = 30000
    var selfAnalytics: Bool = false
    init(_ dict: [String: AnyObject], isDataFromAPI: Bool){
        var dictWithTimeStamp = dict
        
        if isDataFromAPI{
            dictWithTimeStamp["timestamp"] = timestamp as AnyObject
        }else if let timeS = dict["timestamp"] as? Date{
            timestamp = timeS
            if let batchSizeString = dict["batch_size"] as? String, let batchsize = Int(batchSizeString){
                batchSize = batchsize
            }
            if let exclusionEventArray = dict["exclusion_events"] as? [[String: AnyObject]] {
                for exclusionEventDict in exclusionEventArray{
                    if let event = EventDescription(exclusionEventDict){
                        exclusionEvents.append(event)
                    }
                }
            }
            if let intervalString = dict["interval"] as? String, let intrval = Int64(intervalString){
                interval = intrval
            }
            if let selfAn = dict["self_analytics"] as? Bool{
                selfAnalytics = selfAn
            }
        }
        Creeper.sharedUserDefaults.set(dictWithTimeStamp, forKey: "configKey")
    }
}

internal class EventDescription: NSObject{
    var desc: String
    var name: String
    
    init?(_ dict: [String: AnyObject]){
        guard let descripton = dict["event_desc"] as? String, let nam = dict["event_name"] as? String else{
            return nil
        }
        desc = descripton
        name = nam
        return nil
    }
}

extension Dictionary {
    var prettyPrintedJSON: String? {
        do {
            let data: Data = try JSONSerialization.data(withJSONObject: self, options: .prettyPrinted)
            return String(data: data, encoding: .utf8)
        } catch _ {
            return nil
        }
    }
}
