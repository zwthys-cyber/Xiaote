import SwiftUI

@main
struct ExampleApp: App {
    var body: some Scene {
        WindowGroup {
            MainTableView()
                .ignoresSafeArea()
        }
    }
}

struct MainTableView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        let tableVC = MainTableViewController()
        let nav = UINavigationController(rootViewController: tableVC)
        nav.navigationBar.prefersLargeTitles = true
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}
