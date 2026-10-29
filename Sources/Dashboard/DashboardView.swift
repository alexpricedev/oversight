import SwiftUI

struct DashboardView: View {
    @Bindable var env: AppEnvironment

    var body: some View {
        VStack(spacing: 0) {
            if !env.model.ownerBanners.isEmpty {
                OwnerBanners(env: env)
                Divider()
            }

            DashboardContent(env: env)

            Divider()
            FooterBar(env: env)
        }
        .frame(minWidth: 960, minHeight: 620)
        .background(WindowAccessor { visible in
            env.activity.windowVisibilityChanged(visible)
        })
        .onAppear {
            env.model.startPolling()
            Task { await env.model.settingsDidChange() }
        }
        .onDisappear {
            env.model.pausePolling()
        }
        .onChange(of: env.activity.isPaused) { _, paused in
            if paused {
                env.model.pausePolling()
            } else {
                env.model.resumePolling()
            }
        }
        .onChange(of: env.settings.owners) { _, _ in
            Task { await env.model.settingsDidChange() }
        }
        .onChange(of: env.settings.hiddenRepos) { _, _ in
            Task { await env.model.settingsDidChange() }
        }
        .searchable(text: $env.repoFilter, placement: .toolbar, prompt: "Filter repositories")
        .toolbar {
            ToolbarItem {
                OwnerFilterMenu(env: env)
            }
            ToolbarItem {
                Button {
                    Task { await env.model.refreshAll() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh now (⌘R)")
                .disabled(env.model.isRefreshing)
            }
        }
    }
}

private struct DashboardContent: View {
    let env: AppEnvironment

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 14) {
                ActionsSection(env: env, now: context.date)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                PullRequestsSection(env: env, now: context.date)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                IssuesSection(env: env, now: context.date)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(14)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

struct OwnerBanners: View {
    let env: AppEnvironment

    var body: some View {
        let banners = env.model.ownerBanners
        VStack(spacing: 0) {
            ForEach(banners) { banner in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(banner.owner.login)
                            .font(.callout.weight(.semibold))
                        Text(banner.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    SettingsLink {
                        Text("Open Settings")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.10))

                if banner.id != banners.last?.id {
                    Divider()
                }
            }
        }
    }
}

struct OwnerFilterMenu: View {
    @Bindable var env: AppEnvironment

    var body: some View {
        Menu {
            Button {
                env.ownerFilter = nil
            } label: {
                if env.ownerFilter == nil {
                    Label("All owners", systemImage: "checkmark")
                } else {
                    Text("All owners")
                }
            }

            if !env.model.owners.isEmpty {
                Divider()
            }

            ForEach(env.model.owners) { owner in
                Button {
                    env.ownerFilter = owner.login
                } label: {
                    if env.ownerFilter == owner.login {
                        Label(owner.login, systemImage: "checkmark")
                    } else {
                        Text(owner.login)
                    }
                }
            }
        } label: {
            Text(env.ownerFilter ?? "All owners")
                .font(.callout)
        }
        .menuIndicator(.visible)
        .fixedSize()
        .help("Filter by owner")
    }
}

struct FooterBar: View {
    let env: AppEnvironment

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            HStack(spacing: 12) {
                if env.model.isRefreshing {
                    ProgressView()
                        .controlSize(.mini)
                }

                Text(env.model.lastRefreshed.map {
                    "Refreshed \(RelativeTime.ago($0, now: context.date))"
                } ?? "Not refreshed yet")

                if !env.model.isPolling {
                    Label("Paused", systemImage: "pause.circle")
                }

                Spacer(minLength: 8)

                ForEach(env.model.owners) { owner in
                    RateLimitLabel(
                        owner: owner,
                        info: env.model.rateLimits[owner.login],
                        now: context.date
                    )
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
        }
    }
}

struct RateLimitLabel: View {
    let owner: Owner
    let info: RateLimitInfo?
    let now: Date

    var body: some View {
        if let info {
            HStack(spacing: 4) {
                Image(systemName: info.isLow ? "exclamationmark.circle.fill" : "bolt.horizontal.circle")
                Text("\(owner.login) \(info.remaining.formatted())/\(info.limit.formatted())")
                    .monospacedDigit()
            }
            .foregroundStyle(info.isLow ? Color.orange : Color.secondary)
            .help("GitHub API allowance for \(owner.login). Resets at \(info.reset.formatted(date: .omitted, time: .shortened)).")
        } else {
            Text("\(owner.login) —")
                .help("No rate-limit data yet for \(owner.login).")
        }
    }
}
