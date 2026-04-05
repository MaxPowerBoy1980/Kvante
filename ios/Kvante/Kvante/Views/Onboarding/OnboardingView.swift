import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    let apiClient: APIClient?
    let onComplete: () -> Void

    @State private var name = ""
    @State private var gradeLevel = 4
    @State private var selectedAvatar = "person.crop.circle.fill"
    @State private var step = 1
    @State private var isRegistering = false

    private let avatars = [
        "person.crop.circle.fill",
        "star.circle.fill",
        "heart.circle.fill",
        "bolt.circle.fill",
        "flame.circle.fill",
        "leaf.circle.fill",
        "sparkles",
        "moon.circle.fill",
    ]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo
            VStack(spacing: 8) {
                Text("🧮")
                    .font(.system(size: 64))
                Text("Kvante")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("Din matematik-hjælper")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Step content
            Group {
                switch step {
                case 1: nameStep
                case 2: gradeStep
                case 3: avatarStep
                default: EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            Spacer()

            // Progress dots
            HStack(spacing: 8) {
                ForEach(1...3, id: \.self) { i in
                    Circle()
                        .fill(i <= step ? Color.orange : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Steps

    private var nameStep: some View {
        VStack(spacing: 20) {
            Text("Hvad hedder du?")
                .font(.title2.weight(.semibold))

            TextField("Dit navn", text: $name)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(16)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))

            Button {
                withAnimation { step = 2 }
            } label: {
                Text("Næste")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
    }

    private var gradeStep: some View {
        VStack(spacing: 20) {
            Text("Hvilken klasse går du i?")
                .font(.title2.weight(.semibold))

            HStack(spacing: 12) {
                ForEach(3...6, id: \.self) { grade in
                    Button {
                        gradeLevel = grade
                    } label: {
                        Text("\(grade).")
                            .font(.title.weight(.bold))
                            .frame(width: 70, height: 70)
                            .background(
                                gradeLevel == grade ? Color.orange : Color(.systemGray5),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .foregroundStyle(gradeLevel == grade ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                withAnimation { step = 3 }
            } label: {
                Text("Næste")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
        }
    }

    private var avatarStep: some View {
        VStack(spacing: 20) {
            Text("Vælg dit ikon")
                .font(.title2.weight(.semibold))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                ForEach(avatars, id: \.self) { avatar in
                    Button {
                        selectedAvatar = avatar
                    } label: {
                        Image(systemName: avatar)
                            .font(.system(size: 32))
                            .frame(width: 64, height: 64)
                            .background(
                                selectedAvatar == avatar ? Color.orange : Color(.systemGray5),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .foregroundStyle(selectedAvatar == avatar ? .white : .orange)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                register()
            } label: {
                if isRegistering {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange, in: RoundedRectangle(cornerRadius: 14))
                } else {
                    Text("Start!")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
            }
            .disabled(isRegistering)
        }
    }

    // MARK: - Registration

    private func register() {
        isRegistering = true
        let profile = StudentProfile(
            name: name.trimmingCharacters(in: .whitespaces),
            avatarName: selectedAvatar,
            gradeLevel: gradeLevel
        )

        Task {
            // Register with backend if connected
            if let client = apiClient {
                if let response = try? await client.registerStudent(
                    name: profile.name, gradeLevel: profile.gradeLevel
                ) {
                    profile.backendStudentId = response.studentId
                }
            }

            modelContext.insert(profile)
            try? modelContext.save()
            isRegistering = false
            onComplete()
        }
    }
}
