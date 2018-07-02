//
//  NetworkWrapper.swift
//  Creeper
//
//  Created by Deepti Pandey on 10/04/18.
//  Copyright © 2018 Tapzo. All rights reserved.
//

import Foundation

class NetworkWrapper: NSObject{
    
}


enum CreeperNetworkRequestType : String{
    case Config = "events/v1/config"
    case EventsPush = "events/v1/push"
}

enum NetworkConstants : String{
    case EventKey = "X-EVENT-KEY"
    case ContentType = "Content-Type"
    case DockerKey = "chalao-segment"
    case ApplicationJSON = "application/json"
    case BaseUrlDocker = "http://docker04.helpchat.in:12081/"
    case BaseUrlProd = "https://events.tapzo.com/"
    case ProdKey = "mM1wnQJBSQtt4dbvzhzKi2vDto8ECr4Ly1TsTSaNcd8PZ5MgpfwJ6vBkHXIJvdKGqD2TPvHtRqLJgBHhhKwbVwSJqEfXKWpjFu6p"
    case DeviceId = "did"
}


class NetworkRequest: NSObject {
    
    let urlRequest : URLRequest
    init?(_ requestType : CreeperNetworkRequestType, parameter : [String :AnyObject]){
        switch requestType {
            
        case CreeperNetworkRequestType.Config:
            guard let did = parameter[NetworkConstants.DeviceId.rawValue] as? String, let requestUrl = URL.init(string: "\(Creeper.shared.baseUrl)\(CreeperNetworkRequestType.Config.rawValue)?did=\(did)") else{
                return nil
            }
            var request = URLRequest.init(url: requestUrl)
            request.addValue(Creeper.shared.segmentKey, forHTTPHeaderField: NetworkConstants.EventKey.rawValue)
            request.addValue(NetworkConstants.ContentType.rawValue, forHTTPHeaderField: NetworkConstants.ApplicationJSON.rawValue)
            urlRequest = request
        case CreeperNetworkRequestType.EventsPush:
            guard let requestUrl = URL.init(string: Creeper.shared.baseUrl + CreeperNetworkRequestType.EventsPush.rawValue) else{
                return nil
            }
            var request = URLRequest.init(url: requestUrl)
            request.addValue(Creeper.shared.segmentKey, forHTTPHeaderField: NetworkConstants.EventKey.rawValue)
            request.addValue(NetworkConstants.ContentType.rawValue, forHTTPHeaderField: NetworkConstants.ApplicationJSON.rawValue)
            request.httpMethod = "POST"
            guard let httpBody = try? JSONSerialization.data(withJSONObject: parameter, options: []) else {
                return nil
            }
            request.httpBody = httpBody
            urlRequest = request
        }
    }
    
    
}


