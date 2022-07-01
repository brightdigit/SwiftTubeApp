//
//  ContentView.swift
//  SwiftTubeApp
//
//  Created by Leo Dion on 6/29/22.
//
import SwiftUI

struct ContentView: View {
    @StateObject var signinModel = SubscriptionsModel()
    var body: some View {
        if let subscriptions = try? signinModel.subscriptionsResult?.get().items {
            ForEach(subscriptions, id: \.id) { subscription in
                Text(subscription.snippet?.channelTitle ?? "No Title")
            }
        } else {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundColor(.accentColor)
                Text("Hello, world!")
                Button {
                    self.signinModel.signIn()
                } label: {
                    Text("Authorize")
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
