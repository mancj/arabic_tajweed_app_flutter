//
//  GowalkHelperFlutterPlugin+Onboarding.swift
//  Runner
//

import UIKit
import SwiftUI
import NXKit
import GowalkOnboardingSDK
import GowalkDevHelper

extension GowalkHelperFlutterPlugin {

    private var navigationController: UIViewController? {
        let windows = UIApplication
            .shared
            .connectedScenes
            .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
            .first { $0.isKeyWindow }
        return windows?.rootViewController
    }
    
    private func navigateToOnboarding() {
        let onboardingHostingVC = UIHostingController(rootView: InitializerClass.getFirstView())
        onboardingHostingVC.modalPresentationStyle = .fullScreen
        onboardingHostingVC.modalTransitionStyle = .crossDissolve
        
        navigationController?.present(onboardingHostingVC, animated: true)
    }
    
    private func navigateToApp() {
        navigationController?.dismiss(animated: true)
    }
    
    func initializeOnboarding(forceShowOnboarding: Bool, didClose: @escaping (_ didShowOnbiarding: Bool) -> Void) {
        if !InitializerClass.isOnboardingCompleted || forceShowOnboarding {
            GowalkDevHelper.shared.initializeOnboarding(showPaywallEndOfTheOnboarding: true, navigateToOnboardingFunction: {
                self.navigateToOnboarding()
            }, navigateToAppFunction: {
                self.navigateToApp()
                didClose(true)
            })
        } else {
            self.navigateToApp()
            didClose(false)
        }
    }
}
