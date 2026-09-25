import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var browser = BrowserModel()
    @State private var showSettings=false
    @State private var showTraffic=false

    var body: some View {
        NavigationStack {
            VStack(spacing:0) {
                HStack(spacing:8) {
                    Button { browser.goBack() } label: { Image(systemName:"chevron.left") }
                    Button { browser.goForward() } label: { Image(systemName:"chevron.right") }
                    TextField("YouTube URL / 検索", text:$browser.address)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { browser.navigate() }
                    Button("移動") { browser.navigate() }.buttonStyle(.borderedProminent)
                }.padding(8)
                WebView(model:browser, settings:settings).ignoresSafeArea(edges:.bottom)
            }
            .navigationTitle("YouTube Utility LC")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement:.topBarTrailing) {
                    Button { showTraffic=true } label:{ Image(systemName:"chart.bar.xaxis") }
                    Button { showSettings=true } label:{ Image(systemName:"gearshape") }
                }
            }
            .sheet(isPresented:$showSettings) { SettingsView(browser:browser).environmentObject(settings) }
            .sheet(isPresented:$showTraffic) { TrafficView(browser:browser) }
        }
    }
}
