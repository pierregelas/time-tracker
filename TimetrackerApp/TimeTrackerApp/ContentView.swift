import SwiftUI

struct ContentView: View {
    @State private var showSettings = false

    var body: some View {
        TabView {
            ProjectsView()
                .tabItem { Label("Projects", systemImage: "folder") }

            TimesView()
                .tabItem { Label("Times", systemImage: "clock") }

            StatisticsView()
                .tabItem { Label("Statistics", systemImage: "chart.bar") }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .frame(minWidth: 980, minHeight: 640)
    }
}

#Preview {
    ContentView()
}
