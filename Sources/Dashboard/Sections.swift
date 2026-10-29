import SwiftUI

/// One column of the overview. The header stays put and the rows scroll, so a
/// busy section never pushes the others off screen.
struct DashboardCard<Content: View>: View {
    let title: String
    let count: Int?
    let subtitle: String?
    private let content: Content

    init(
        title: String,
        count: Int? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.count = count
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.headline)
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.8), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ActionsSection: View {
    let env: AppEnvironment
    let now: Date

    private var rows: [ActionRow] {
        env.model.actionRows
    }

    var body: some View {
        DashboardCard(title: "GitHub Actions", count: rows.count, subtitle: "latest 25") {
            if rows.isEmpty {
                EmptyStateRow(text: "No workflow runs yet", systemImage: "bolt.horizontal.circle")
            } else {
                ForEach(rows) { row in
                    ActionRowView(
                        row: row,
                        now: now,
                        warning: env.model.repoWarning(for: row.repo)
                    )
                    if row.id != rows.last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
        }
    }
}

struct PullRequestsSection: View {
    let env: AppEnvironment
    let now: Date

    private var rows: [PullRequestRow] {
        env.model.latestPullRequests
    }

    private var total: Int {
        env.model.pullRequestRows.count
    }

    var body: some View {
        DashboardCard(
            title: "Pull requests",
            count: total,
            subtitle: total > rows.count ? "latest 25" : nil
        ) {
            if rows.isEmpty {
                EmptyStateRow(text: "No open pull requests", systemImage: "arrow.triangle.branch")
            } else {
                ForEach(rows) { row in
                    PullRequestRowView(
                        row: row,
                        ci: env.model.ciStatus(for: row),
                        now: now
                    )
                    if row.id != rows.last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
        }
    }
}

struct IssuesSection: View {
    let env: AppEnvironment
    let now: Date

    private var rows: [IssueRow] {
        env.model.issueRows
    }

    var body: some View {
        DashboardCard(title: "Issues", count: rows.count) {
            if rows.isEmpty {
                EmptyStateRow(text: "No open issues", systemImage: "checkmark.circle")
            } else {
                ForEach(rows) { row in
                    IssueRowView(row: row, now: now)
                    if row.id != rows.last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
        }
    }
}
