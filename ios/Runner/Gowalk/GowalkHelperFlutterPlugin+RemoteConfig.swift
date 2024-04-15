//
//  GowalkHelperFlutterPlugin+RemoteConfig.swift
//  Runner
//

import Foundation
import GowalkDevHelper

extension GowalkHelperFlutterPlugin {
    
     func getRemoteConfigStringValue(_ key: String) -> String? {
        let value = GowalkServices.remoteConfigService.getConfigValue(key)
        return value.stringValue
    }
    
    func getRemoteConfigBoolValue(_ key: String) -> Bool? {
        let value = GowalkServices.remoteConfigService.getConfigValue(key)
        return value.boolValue
    }
    
}
