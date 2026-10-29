import SwiftUI

struct SettingsView: View {
    let env: AppEnvironment

    @State private var isAddingOwner = false
    @State private var replacingOwner: Owner?
    @State private var removingOwner: Owner?
    @State private var storedOwners: Set<String> = []
    @State private var newHiddenRepo = ""
    @State private var hiddenRepoError: String?
    @State private var newOrganization = ""
    @State private var organizationError: String?

    private var sortedHidden: [String] {
        env.settings.hiddenRepos.sorted()
    }

    private var hideableRepos: [Repo] {
        env.model.knownRepos.filter { !env.settings.hiddenRepos.contains($0.id.slug) }
    }

    var body: some View {
        Form {
            Section("Owners") {
                if env.settings.owners.isEmpty {
                    Text("No owners configured yet.")
                        .foregroundStyle(.secondary)
                }

                ForEach(env.settings.owners) { owner in
                    ownerRow(owner)
                }

                Button("Add owner…") {
                    isAddingOwner = true
                }
            }

            Section("Organizations") {
                let organizations = env.model.organizations
                if organizations.isEmpty {
                    Text("No organizations found yet. Organizations with repositories your token can see appear here after a refresh, or add one below.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(organizations) { organization in
                        Toggle(isOn: Binding(
                            get: { env.settings.includesOrg(organization.owner.login) },
                            set: { isIncluded in
                                if isIncluded {
                                    env.settings.includeOrg(organization.owner.login)
                                } else {
                                    env.settings.excludeOrg(organization.owner.login)
                                }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(organization.owner.login)
                                        .fontWeight(.medium)
                                    Badge(text: "Organization")
                                }
                                Text(organization.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                }

                HStack(spacing: 8) {
                    TextField("organization", text: $newOrganization)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addOrganization() }
                    Button("Add") {
                        addOrganization()
                    }
                    .disabled(newOrganization.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if let organizationError {
                    Text(organizationError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Text("Organization repositories are read with the token of the account that belongs to them.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Section("Repositories to hide") {
                if sortedHidden.isEmpty {
                    Text("No repositories hidden.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedHidden, id: \.self) { slug in
                        HStack {
                            Text(slug)
                                .font(.callout)
                            Spacer()
                            Button("Show again") {
                                env.settings.unhide(slug)
                            }
                        }
                    }
                }

                HStack(spacing: 8) {
                    TextField("owner/repo", text: $newHiddenRepo)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addHiddenRepo() }
                    Button("Hide") {
                        addHiddenRepo()
                    }
                    .disabled(RepoID(slug: newHiddenRepo.trimmingCharacters(in: .whitespaces)) == nil)
                }

                if let hiddenRepoError {
                    Text(hiddenRepoError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if !hideableRepos.isEmpty {
                    Menu("Hide a loaded repository…") {
                        ForEach(hideableRepos) { repo in
                            Button(repo.id.slug) {
                                env.settings.hide(repo.id.slug)
                            }
                        }
                    }
                }
            }

            Section("Required token permissions") {
                PermissionsList()
                Link(
                    "Create a fine-grained token on GitHub",
                    destination: URL(string: "https://github.com/settings/personal-access-tokens/new")!
                )
                .font(.callout)
            }

            Section {
                HStack {
                    Text("Oversight \(version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 580, height: 640)
        .sheet(isPresented: $isAddingOwner) {
            AddOwnerSheet(env: env, owner: nil) {
                refreshStoredOwners()
            }
        }
        .sheet(item: $replacingOwner) { owner in
            AddOwnerSheet(env: env, owner: owner) {
                refreshStoredOwners()
            }
        }
        .confirmationDialog(
            "Remove \(removingOwner?.login ?? "owner")?",
            isPresented: Binding(
                get: { removingOwner != nil },
                set: { if !$0 { removingOwner = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove owner", role: .destructive) {
                removeOwner()
            }
        } message: {
            Text("This deletes the token from the Keychain and stops loading this owner's repositories.")
        }
        .onAppear {
            refreshStoredOwners()
        }
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
    }

    private func ownerRow(_ owner: Owner) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(owner.login)
                        .fontWeight(.medium)
                    Badge(text: owner.kind.displayName)
                }
                HStack(spacing: 8) {
                    Label(
                        storedOwners.contains(owner.login) ? "Token in Keychain" : "No token yet",
                        systemImage: storedOwners.contains(owner.login) ? "key.fill" : "key.slash"
                    )
                    .font(.caption)
                    .foregroundStyle(storedOwners.contains(owner.login) ? Color.secondary : Color.orange)

                    if let info = env.model.rateLimits[owner.login] {
                        Text("\(info.remaining.formatted())/\(info.limit.formatted()) remaining")
                            .font(.caption)
                            .foregroundStyle(info.isLow ? Color.orange : Color.secondary)
                    }
                }
            }

            Spacer()

            Button("Replace token…") {
                replacingOwner = owner
            }
            Button("Remove", role: .destructive) {
                removingOwner = owner
            }
        }
    }

    private func addOrganization() {
        let login = newOrganization.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !login.isEmpty, !login.contains("/"), !login.contains(" ") else {
            organizationError = "Use the organization's login, with no slashes or spaces."
            return
        }
        organizationError = nil
        env.settings.includeOrg(login)
        newOrganization = ""
    }

    private func addHiddenRepo() {
        let slug = newHiddenRepo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard RepoID(slug: slug) != nil else {
            hiddenRepoError = "Use the form owner/repo."
            return
        }
        hiddenRepoError = nil
        env.settings.hide(slug)
        newHiddenRepo = ""
    }

    private func removeOwner() {
        guard let owner = removingOwner else { return }
        try? env.tokenStore.delete(for: owner.login)
        env.settings.removeOwner(owner.login)
        removingOwner = nil
        refreshStoredOwners()
        Task { await env.model.settingsDidChange() }
    }

    private func refreshStoredOwners() {
        var stored: Set<String> = []
        for owner in env.settings.owners {
            if let token = (try? env.tokenStore.token(for: owner.login)) ?? nil, !token.isEmpty {
                stored.insert(owner.login)
            }
        }
        storedOwners = stored
    }
}
