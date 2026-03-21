import SwiftUI
import SwiftData

@main
struct KvanteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Session.self, Assignment.self, Submission.self])
    }
}
