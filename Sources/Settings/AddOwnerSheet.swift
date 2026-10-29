import SwiftUI

/// Adds an owner, or replaces an existing owner's token. The token is checked
/// with GitHub before it is written to the Keychain.
struct AddOwnerSheet: View {
    let env: AppEnvironment
    let owner: Owner?
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var login: String
    @State private var token = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    init(env: AppEnvironment, owner: Owner?, onSaved: @escaping () -> Void) {
        self.env = env
        self.owner = owner
        self.onSaved = onSaved
        _login = State(initialValue: owner?.login ?? "")
    }

    private var isReplacing: Bool {
        owner != nil
    }

    private var canSave: Bool {
        !isWorking
            && !token.isEmpty
            && (isReplacing || !login.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isReplacing ? "Replace token for \(owner?.login ?? "")" : "Add owner")
                .font(.title3.weight(.semibold))

            if !isReplacing {
                VStack(alignment: .leading, spacing: 4) {
                    Text("GitHub owner")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("alexpricedev", text: $login)
                        .textFieldStyle(.roundedBorder)
                    Text("A user or an organization. The token must be able to see its repositories.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Fine-grained personal access token")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                SecureField("github_pat_…", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if canSave { Task { await save() } }
                    }
            }

            Link(
                "Create a token on GitHub",
                destination: URL(string: "https://github.com/settings/personal-access-tokens/new")!
            )
            .font(.callout)

            PermissionsList()

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                if isWorking {
                    ProgressView()
                        .controlSize(.small)
                    Text(isReplacing ? "Checking the token…" : "Checking the token and repositories…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(isReplacing ? "Verify and replace" : "Verify and save") {
                    Task { await save() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(22)
        .frame(width: 500)
    }

    private func save() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        let target = owner?.login ?? login.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let verified = try await env.client.verifyOwner(login: target, token: token)
            try env.tokenStore.save(token, for: verified.login)
            env.settings.addOwner(verified)
            onSaved()
            // Close immediately; the first full refresh can take several seconds
            // and shouldn't hold the sheet open.
            dismiss()
            Task { await env.model.settingsDidChange() }
        } catch let error as GitHubError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct PermissionsList: View {
    private struct Permission: Identifiable {
        let name: String
        let access: String
        var id: String {
            name
        }
    }

    private let permissions: [Permission] = [
        Permission(name: "Metadata", access: "Read"),
        Permission(name: "Actions", access: "Read"),
        Permission(name: "Pull requests", access: "Read"),
        Permission(name: "Issues", access: "Read"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Required permissions, all read-only")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(permissions) { permission in
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text(permission.name)
                        .font(.caption)
                    Spacer()
                    Text(permission.access)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("The token also needs access to each repository you want to watch.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }
}
