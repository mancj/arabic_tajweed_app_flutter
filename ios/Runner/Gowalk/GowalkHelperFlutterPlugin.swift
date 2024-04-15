import Foundation
import Flutter
import GowalkDevHelper
import SwiftUI

class GowalkHelperFlutterPlugin : NSObject, FlutterPlugin {
    private var helper: GowalkDevHelper? { isInitialized ? GowalkDevHelper.shared : nil }
    private var isInitialized = false;
    static var channelName = "com.gowalk.app/channel"
    private var channel: FlutterMethodChannel?
    private var isPrepared = false
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        var channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        let instance = GowalkHelperFlutterPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "ping":
            parse(args: call.arguments, result: result) { (value: String) in
                let pingResult = ping(value)
                result(pingResult)
            }
        case "prepareHelper":
            prepareHelper {
                result(true)
            } onError: { localizedDescription in
                result(FlutterError(code: "ERROR", message: localizedDescription, details: nil))
            }

        case "initGowalkDevHelper":
            parseDict(args: call.arguments, result: result) { dict in
                let appleId = dict!["appleAppID"] as! String
                
                let mixpanelKey = dict!["mixpanelKey"] as? String
                let qonversionKey = dict!["qonversionKey"] as? String
                let shouldShowRatingAfterATTView = dict!["shouldShowRatingAfterATTView"] as? Bool
                let oneSignalApiKey = dict!["oneSignalApiKey"] as? String
                let oneSignalAppGroupId = dict!["oneSignalAppGroupId"] as? String
                
                initGowalkDevHelper(
                    appleAppId: appleId,
                    mixpanelKey: mixpanelKey,
                    qonversionKey: qonversionKey,
                    shouldShowRatingAfterATTView: shouldShowRatingAfterATTView ?? false,
                    oneSignalApiKey: oneSignalApiKey,
                    oneSignalAppGroupId: oneSignalAppGroupId
                ) {
                    result(true)
                }
            }
        case "showAppRatingPopup":
            showAppRatingPopup(result)
        case "showPaidContentOrPaywall":
            parse(args: call.arguments, result: result) { (value: String?) in
                showPaidContentOrPaywall(placementId: value) {
                    result(true)
                } didChangePaywallDownloadStatus: { status in
                    self.channel?.invokeMethod(
                        "didChangePaywallDownloadStatus",
                        arguments: status.description
                    )
                }
            }
        case "showPaywall":
            parse(args: call.arguments, result: result) { (value: String?) in
                showPaywall(placementId: value) { isPurchased in
                    result(isPurchased)
                } didChangePaywallDownloadStatus: { status in
                    self.channel?.invokeMethod(
                        "didChangePaywallDownloadStatus",
                        arguments: status.description
                    )
                }
            }
            
        case "getSubscriptionStatus":
            getSubscriptionStatus { hasActiveSubscriptions in
                result(hasActiveSubscriptions)
            }
        case "setOnboardingPassed":
            parse(args: call.arguments, result: result) { (passed: Bool) in
                setOnboardingPassed(passed)
                result(true)
            }
        case "getRemoteConfigStringValue":
            parse(args: call.arguments, result: result) { key in
                result(getRemoteConfigStringValue(key))
            }
        case "getRemoteConfigBoolValue":
            parse(args: call.arguments, result: result) { key in
                result(getRemoteConfigBoolValue(key))
            }
        case "initializeOnboarding":
            parse(args: call.arguments, result: result) { (forceShowOnboarding: Bool) in
                initializeOnboarding(forceShowOnboarding: forceShowOnboarding, didClose: { (didShowOnbiarding: Bool) in
                    result(didShowOnbiarding)
                })
            }
        default:
            result(FlutterMethodNotImplemented)
        }
      
    }
    
    private func showAppRatingPopup(_ result: FlutterResult) {
        if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
            GowalkDevHelper.showAppRatingPopup(forcePresent: true, parentVC: rootViewController)
            result(true)
        }
    }
    
    private func ping(_ value: String) -> String {
      return "Pong"
    }
    
    private func initGowalkDevHelper(appleAppId: String, mixpanelKey: String?, qonversionKey: String?, shouldShowRatingAfterATTView: Bool = false, oneSignalApiKey: String?, oneSignalAppGroupId: String?, _ onComplete: @escaping () -> Void) {
        if(isInitialized) {
            onComplete()
            return
        }
        isInitialized = true;
        
        var oneSignalConfiguration: GowalkDevHelper.OneSignalConfiguration?
        if (oneSignalApiKey != nil && oneSignalAppGroupId != nil) {
            oneSignalConfiguration = GowalkDevHelper.OneSignalConfiguration(
                apiKey: oneSignalApiKey!,
                appGroupId: oneSignalAppGroupId!
            )
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            GowalkDevHelper.shared.configure(
                appleAppID: appleAppId,
                permissionRequests: [.att, .push()],
                isPrintToConsole: true,
                shouldShowRatingAfterATTView: shouldShowRatingAfterATTView,
                mixpanelKey: mixpanelKey,
                QonversionProjectKey: qonversionKey,
                oneSignalConfiguration: oneSignalConfiguration
            )
            onComplete()
        })
    }
    
    private func prepareHelper(success: @escaping () -> Void, onError: @escaping (String) -> Void) {
        if (isPrepared) {
            success()
            return
        }
        helper?.prepare { result in
            switch result {
            case .success:
                self.isPrepared = true
                success()
            case .failed(let error):
                onError(error.localizedDescription)
            }
        }
    }
    
    private func setOnboardingPassed(_ passed: Bool) {
        print("Native setOnboardingPassed called")
        GowalkDevHelper.shared.setOnboardingPassed(passed)
    }
    
    private func showPaidContentOrPaywall(placementId: String?, completion: @escaping () -> Void, didChangePaywallDownloadStatus: @escaping (SubscriptionService.PaywallDownloadStatus) -> Void) {
        var paywallConfig = placementId != nil
            ? SubscriptionService.PaywallConfiguration(paywallId: placementId!, detailedPaywallId: nil)
            : .common
        
        GowalkServices.subscriptionService.showPaidContentOrPaywall(paywallConfiguration: paywallConfig, presentPaidContent: {
            completion()
        }, didChangePaywallDownloadStatus: {status in
            didChangePaywallDownloadStatus(status)
        })
    }
    
    private func showPaywall(placementId: String?, completion: @escaping (Bool) -> Void, didChangePaywallDownloadStatus: @escaping (SubscriptionService.PaywallDownloadStatus) -> Void) {
        var paywallConfig = placementId != nil
            ? SubscriptionService.PaywallConfiguration(paywallId: placementId!, detailedPaywallId: nil)
            : .common
        
        GowalkServices.subscriptionService.showPaywall(
            configuration: paywallConfig,
            didPurchase: { isPurchased in
                completion(isPurchased)
            },
            didChangePaywallDownloadStatus: { status in
                didChangePaywallDownloadStatus(status)
            }
        )
    }
    
    private func getSubscriptionStatus(completion: @escaping (Bool) -> Void) {
        GowalkServices.subscriptionService.getSubscriptionStatus { hasActiveSubscription in
            completion(hasActiveSubscription)
        }
    }
    
}

extension GowalkHelperFlutterPlugin {
    
    private func parse<T>(args: Any?, result: @escaping FlutterResult, completion: (T)-> Void) {
        if let value = args as? T {
            completion(value)
        } else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected String argument", details: nil))
        }
    }
    
    private func parseDict(args: Any?, result: @escaping FlutterResult, completion: ([String : Any]?) -> Void) {
        guard let dict = args as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
          }
          completion(dict)
    }
    

    
}

extension SubscriptionService.PaywallDownloadStatus: CustomStringConvertible {
    public var description: String {
        switch self {
       
        case .loading:
            return "loading"
        case .error(_):
            return "error"
        case .loaded:
            return "loaded"
        }
    }
}
