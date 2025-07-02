import SwiftUI

struct MainTabView: View {
    @ObservedObject var appViewModel: AppViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            StudyView(appViewModel: appViewModel)
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "book.fill" : "book")
                    Text("Study")
                }
                .tag(0)
            
            ExploreView(appViewModel: appViewModel)
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "safari.fill" : "safari")
                    Text("Explore")
                }
                .tag(1)
            
            AddSourceView(appViewModel: appViewModel)
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                    Text("Add")
                }
                .tag(2)
            
            ManageView(appViewModel: appViewModel)
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "folder.fill" : "folder")
                    Text("Manage")
                }
                .tag(3)
            
            SettingsView(appViewModel: appViewModel)
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "gearshape.fill" : "gearshape")
                    Text("Settings")
                }
                .tag(4)
        }
        .accentColor(.blue)
    }
}