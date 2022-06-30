//
//  SwiftTubeAppApp.swift
//  SwiftTubeApp
//
//  Created by Leo Dion on 6/29/22.
//

import SwiftUI

@main
struct SwiftTubeApp: App {
    @UIApplicationDelegateAdaptor var handler : SwiftTubeAppDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class SwiftTubeAppDelegate : NSObject, UIApplicationDelegate {
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print(url)
        return true
    }
}
