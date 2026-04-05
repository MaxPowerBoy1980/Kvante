import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.createdAt, order: .reverse) private var sessions: [Session]

    let serverDiscovery: ServerDiscovery
    let onScanPage: () -> Void

    @State private var showConnectionInfo = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Kvante")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Din matematik-hjælper")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                // Connection status
                Button {
                    showConnectionInfo = true
                } label: {
                    Image(systemName: serverDiscovery.serverURL != nil
                        ? "wifi.circle.fill" : "wifi.slash")
                        .font(.title2)
                        .foregroundStyle(serverDiscovery.serverURL != nil ? .green : .red)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)

            Spacer()

            // Big scan button
            Button(action: onScanPage) {
                VStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 72))
                    Text("Scan din side")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .frame(width: 320, height: 240)
                .background(.orange, in: RoundedRectangle(cornerRadius: 24))
                .shadow(color: .orange.opacity(0.4), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(serverDiscovery.serverURL == nil)
            .opacity(serverDiscovery.serverURL == nil ? 0.5 : 1)

            if serverDiscovery.serverURL == nil {
                Text(serverDiscovery.isSearching
                    ? "Kvante leder efter din server..."
                    : "Ingen server fundet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)

                if !serverDiscovery.isSearching {
                    Button("Prøv igen") {
                        serverDiscovery.startSearching()
                    }
                    .font(.callout)
                    .padding(.top, 4)
                }
            }

            Spacer()

            // Recent sessions
            if !sessions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Seneste sessioner")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(sessions.prefix(5)) { session in
                                SessionCard(session: session)
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showConnectionInfo) {
            ConnectionInfoSheet(discovery: serverDiscovery)
        }
    }
}

struct SessionCard: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.pageContext.isEmpty ? "Session" : session.pageContext)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            Text(session.createdAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 160, height: 80, alignment: .topLeading)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ConnectionInfoSheet: View {
    let discovery: ServerDiscovery
    @Environment(\.dismiss) private var dismiss
    @State private var manualIP = "http://192.168.1.60:8000"

    var body: some View {
        NavigationStack {
            Form {
                Section("Server status") {
                    if let url = discovery.serverURL {
                        Label("Forbundet: \(url.absoluteString)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Ikke forbundet", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section("Manuel forbindelse") {
                    TextField("http://192.168.1.60:8000", text: $manualIP)
                        .keyboardType(.URL)
                    Button("Forbind") {
                        discovery.setManualURL(manualIP)
                        dismiss()
                    }
                    .disabled(manualIP.isEmpty)
                }
            }
            .navigationTitle("Forbindelse")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Luk") { dismiss() }
                }
            }
        }
    }
}
