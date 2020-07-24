//
//  AppDelegate.swift
//  
//
//  Created  on 24/07/2020.
//  Copyright © 2020 . All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    private let logger = ConcreteLogger(subsystem: "App", category: "AppDelegate")
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        logger.debug("application:didFinishLaunchingWithOptions")
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        logger.debug("applicationDidBecomeActive")
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        logger.debug("applicationWillResignActive")
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        logger.debug("applicationWillEnterForeground")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        logger.debug("applicationDidEnterBackground")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        logger.debug("applicationWillTerminate")
    }
}

