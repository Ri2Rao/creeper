//
//  Creeper.swift
//  Creeper
//
//  Created by Deepti Pandey on 10/04/18.
//  Copyright © 2018 Tapzo. All rights reserved.
//

import UIKit

protocol CreeperProtocol : Error{
    var localizedTitle: String { get }
    var localizedDescription: String { get }
    var code: Int { get }
}

public struct CreeperError: Error {
    
    public var localizedTitle: String
    public var localizedDescription: String
    public var code: Int
    
    init(localizedTitle: String?, localizedDescription: String, code: Int) {
        self.localizedTitle = localizedTitle ?? "Error"
        self.localizedDescription = localizedDescription
        self.code = code
    }
}
public let ConfigError = CreeperError(localizedTitle: "Config Error", localizedDescription: "Creeper Framework not configured", code: 400)

public class Creeper: NSObject{
    
    let kcreeperTraits: String = "creeper traits"
    let kConfigDone: String = "ConfigDone"
    let kDeviceId: String = "device_id"
    let kLastDatePushAttempted: String = "lastDatePushAttempted"
    let twentyFourHoursInMS: Double = 24*60*60*1000
    var kUserId: String = "userID/deviceID"
    var idfaIdentifier: String?
    var adTrackingEnabled: Bool = false
    var isCreeperInitialized: Bool = false
    var isCreeperIdentified: Bool = false
    var baseUrl: String = NetworkConstants.BaseUrlDocker.rawValue
    var segmentKey: String = NetworkConstants.DockerKey.rawValue
    static let sharedUserDefaults = UserDefaults.init(suiteName: "group.com.tapzo.Creeper") ?? UserDefaults.standard
//    static let sharedUserDefaults = UserDefaults.standard

    public static var shared = Creeper()

    var params: [String: AnyObject] = [:]
    
    // MARK: - Configuration : Compulsory
    @objc public class func configuration(_ configDict: Dictionary<String, AnyObject>) {
        // add things like prod or docker, log, base url , key
        if let apiBaseUrl = configDict["ENV_MODE"] as? String{
            if apiBaseUrl == "production"{
                shared.baseUrl = NetworkConstants.BaseUrlProd.rawValue
                shared.segmentKey = NetworkConstants.ProdKey.rawValue
            }else{   // else it will be "debug" but putting it in else just in case
                shared.baseUrl = NetworkConstants.BaseUrlDocker.rawValue
                shared.segmentKey = NetworkConstants.DockerKey.rawValue
            }
        }
        sharedUserDefaults.set(true, forKey: shared.kConfigDone)
        shared.isCreeperInitialized = true
    }
   
    // MARK: - Identify : User id or channel id

    public func identify(_ channelId: String){
        Creeper.shared.isCreeperIdentified = true
        Creeper.sharedUserDefaults.set(channelId, forKey: kDeviceId)
        fetchConfigData(channelId)
    }
    
    public func identify(_ channelId: String, traits: [String: AnyObject?]){
        // so that real userid isn't stored
//        identify(channelId)
        Creeper.sharedUserDefaults.set(traits, forKey: kcreeperTraits)
    }
    public func alias(_ channelId: String, traits: [String: AnyObject?]){
        // so that real userid isn't stored
//        Creeper.sharedUserDefaults.set(channelId, forKey: kUserId)
        Creeper.sharedUserDefaults.set(traits, forKey: kcreeperTraits)
    }
    public func alias(_ channelId: String){
        Creeper.sharedUserDefaults.set(channelId, forKey: kUserId)
    }
    
    
    // MARK: - Track: Event

    public func track(_ name: String, properties: [String: AnyObject]) throws{
                    
            guard let isConfigDone = Creeper.sharedUserDefaults.value(forKey: kConfigDone) as? Bool, isConfigDone else{
                throw ConfigError
            }
            if let deviceId = Creeper.sharedUserDefaults.object(forKey: kDeviceId) as? String{
                fetchConfigData(deviceId)
            }
            if isEventAllowed(name) {
                CreeperDataVader.sharedInstance().track(name, dict: properties)
            }
       
    }
    
    // MARK: - Push Event

   
    
    internal func pushEvents(_ events: [[String: AnyObject]], messageIDs: [String]){
        
        var params: [String: AnyObject] = [:]
        if let deviceId = Creeper.sharedUserDefaults.object(forKey: kDeviceId) as? String{
            params["anonymous_id"] = deviceId as AnyObject
        }
        if let userId = Creeper.sharedUserDefaults.object(forKey: kUserId) as? String {
            params["user_id"] = userId as AnyObject
        }
        
        var traitsDict: [String: AnyObject] = [:]
        traitsDict["created_at"] = "\(Date())" as AnyObject
        if let traits = Creeper.sharedUserDefaults.dictionary(forKey: kcreeperTraits){
            for (k,v) in traits{
                traitsDict[k] = "\(v)" as AnyObject
            }
        }
        var contextDict = createContextDict(traitsDict)

        if traitsDict.count > 0{
            contextDict["traits"] = traitsDict as AnyObject
        }
        
        params["context"] = contextDict as AnyObject
        params["events"] = events as AnyObject
        NetworkVader.sharedVader.sendEventsSync(params, messageIDs: messageIDs)
    }
    
    // MARK: - Config Data

    internal func fetchConfigData(_ deviceId: String) {
        //if config data not present or config data is older than 24 hours
        if let defaultsConfig = Creeper.sharedUserDefaults.object(forKey: "configKey") as? [String: AnyObject] {
            if let oldConfigDate = defaultsConfig["timestamp"] as? Date, oldConfigDate.timeIntervalSince1970 - Date().timeIntervalSince1970 < twentyFourHoursInMS{
                //use old data otherwise make fetch config data
            }else{
                NetworkVader.sharedVader.fetchConfigData(deviceId)
            }
        }else{
            NetworkVader.sharedVader.fetchConfigData(deviceId)
        }
    }
    private func isEventAllowed(_ eventname: String) -> Bool{
        if let configdata = NetworkVader.sharedVader.fetchSavedConfig(){
            for eventItem in configdata.exclusionEvents{
                if eventname == eventItem.name{
                    return false
                }
            }
        }else{
            return false
        }
        return true
    }
    
    private func createContextDict(_ traits: [String: AnyObject]) -> [String: AnyObject]{ // network dict needs to come here
        //anonymous_id : deviceId
        //userId: userId/channelId, found after user signs up
        
        let info = Bundle.main.infoDictionary
        var contextDict: [String: AnyObject] = [:]
        
        
        if let info = info{
            let appParams: [String: AnyObject] = ["name": (info["CFBundleDisplayName"] ?? "CFBundleDisplayName") as AnyObject, "version": (info["CFBundleShortVersionString"] ?? "CFBundleShortVersionString") as AnyObject, "build": (info["CFBundleVersion"] ?? "build") as AnyObject, "namespace": Bundle.main.bundleIdentifier as AnyObject ]
            contextDict["app"] = appParams as AnyObject
        }
        
        let device = UIDevice.current
        var deviceDict: [String: AnyObject] = [:]
        let adId: String? = adTrackingEnabled ? idfaIdentifier : "adId"
        deviceDict["ad_tracking_enabled"] = "\(adTrackingEnabled)" as AnyObject
        deviceDict["advertising_id"] =  adId as AnyObject
        deviceDict["id"] = device.identifierForVendor?.uuidString as AnyObject
        deviceDict["manufacturer"] = "Apple" as AnyObject
        deviceDict["model"] = device.modelName as AnyObject
        deviceDict["name"] = device.systemName as AnyObject
        deviceDict["type"] = "iOS" as AnyObject
        contextDict["device"] = deviceDict as AnyObject
        contextDict["os"] = ["name": "iOS" as AnyObject,"version": device.systemVersion as AnyObject] as AnyObject
        if let userId = Creeper.sharedUserDefaults.object(forKey: kUserId) as? String {
            contextDict["user_id"] = userId as AnyObject
        }
        if let deviceId = Creeper.sharedUserDefaults.object(forKey: kDeviceId) as? String{
            contextDict["anonymous_id"] = deviceId as AnyObject
        }
        let screenSize = UIScreen.main.bounds.size
        contextDict["screen"] = ["height": screenSize.height as AnyObject, "width": screenSize.width as AnyObject] as AnyObject
        var traitsDict = traits
        if let networkDict = traits["network"] as? [String: AnyObject] {
            contextDict["network"] = networkDict as AnyObject
            traitsDict.removeValue(forKey: "network")
        }
        if let userId = Creeper.sharedUserDefaults.object(forKey: kUserId) as? String {
            traitsDict["user_id"] = userId as AnyObject
        }
        if let deviceId = Creeper.sharedUserDefaults.object(forKey: kDeviceId) as? String{
            traitsDict["anonymous_id"] = deviceId as AnyObject
        }
//        contextDict["traits"] = traitsDict as AnyObject
        return contextDict
    }
}


public extension UIDevice {
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}


