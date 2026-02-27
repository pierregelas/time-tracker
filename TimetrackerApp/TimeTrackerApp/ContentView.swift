import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ProjectsView()
                .tabItem { Label("Projects", systemImage: "folder") }

            TimesView()
                .tabItem { Label("Times", systemImage: "clock") }

            Text("Statistics (coming soon)")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .tabItem { Label("Statistics", systemImage: "chart.bar") }
        }
        .frame(minWidth: 980, minHeight: 640)
    }
}

#Preview {
    ContentView()
}
