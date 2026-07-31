import SwiftUI
import SwiftData
import LocalAuthentication
import LedgerCore

struct SettingsView: View {
    @Query(sort: \Transaction.occurredAt, order: .reverse) private var allTransactions: [Transaction]
    @Query private var customCategories: [CustomCategory]

    @State private var settings = AppSettings.shared
    @State private var biometricUnavailableMessage: String?
    @State private var exportedCSV: LedgerCSV?
    @State private var isManagingCategories = false

    private var catalog: CategoryCatalog { CategoryCatalog(customs: customCategories) }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return "v\(version)"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "설정")

            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                    ledgerCard
                    appearanceGroup
                    notificationGroup
                    categoryGroup
                    dataGroup
                    infoGroup
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .alert(
            "생체 인증을 사용할 수 없습니다",
            isPresented: .init(
                get: { biometricUnavailableMessage != nil },
                set: { if !$0 { biometricUnavailableMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(biometricUnavailableMessage ?? "")
        }
    }

    /// The design puts an account card here. This app has no accounts, so the slot shows what the
    /// ledger actually holds rather than inventing a signed-in user.
    private var ledgerCard: some View {
        SurfaceCard {
            HStack(spacing: 14) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 48, height: 48)
                    .background(Palette.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 3) {
                    Text("다비드 가계부")
                        .font(.rowTitle)
                        .foregroundStyle(Palette.textPrimary)
                    Text("기록된 내역 \(allTransactions.count)건")
                        .font(.captionSmall)
                        .foregroundStyle(Palette.textTertiary)
                }
                Spacer()
            }
        }
    }

    private var appearanceGroup: some View {
        SettingsGroup(title: "화면") {
            settingsCard {
                Text("화면 모드")
                    .font(.rowTitle)
                    .foregroundStyle(Palette.textPrimary)

                HStack(spacing: 0) {
                    ForEach(Appearance.allCases) { option in
                        let selected = option == settings.appearance
                        Button {
                            settings.appearance = option
                        } label: {
                            Text(option.label)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(selected ? Palette.textPrimary : Palette.textTertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(selected ? Palette.background : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
                    }
                }
                .padding(3)
                .background(Palette.border.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 11))
            }

            settingsCard {
                Text("강조 색")
                    .font(.rowTitle)
                    .foregroundStyle(Palette.textPrimary)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                    spacing: 12
                ) {
                    ForEach(Palette.accentOptions, id: \.self) { hex in
                        let selected = Int(hex) == settings.accentColorValue
                        Button {
                            settings.accentColorValue = Int(hex)
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Palette.textPrimary, lineWidth: selected ? 2 : 0)
                                        .padding(-3)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(format: "#%06X", hex))
                        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    /// The bordered card the settings rows sit in, shared by the two panels above that hold a
    /// control rather than a single labelled row.
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border, lineWidth: 1))
    }

    private var notificationGroup: some View {
        SettingsGroup(title: "알림 및 보안") {
            SettingsToggleRow(title: "매일 저녁 소비 알림", isOn: $settings.dailyReminderEnabled)
                .onChange(of: settings.dailyReminderEnabled) { _, enabled in
                    Task { await NotificationScheduler.setDailyReminder(enabled: enabled) }
                }

            SettingsToggleRow(title: "예산 90% 초과시 알림", isOn: $settings.budgetAlertEnabled)
                .onChange(of: settings.budgetAlertEnabled) { _, enabled in
                    guard enabled else { return }
                    Task { await NotificationScheduler.requestAuthorization() }
                }

            SettingsToggleRow(title: "생체 인증 사용", isOn: $settings.biometricLockEnabled)
                .onChange(of: settings.biometricLockEnabled) { _, enabled in
                    guard enabled else { return }
                    var error: NSError?
                    let context = LAContext()
                    // Turning the lock on without a usable sensor would lock the user out, so the
                    // toggle refuses rather than trusting the preference blindly.
                    if !context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                        settings.biometricLockEnabled = false
                        biometricUnavailableMessage = error?.localizedDescription
                            ?? "이 기기에서 Face ID 또는 암호를 사용할 수 없습니다."
                    }
                }
        }
    }

    private var categoryGroup: some View {
        SettingsGroup(title: "카테고리") {
            Button {
                isManagingCategories = true
            } label: {
                SettingsRowLabel(
                    title: "카테고리 관리",
                    value: "내 카테고리 \(catalog.activeCustoms.count)개"
                )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $isManagingCategories) {
                CategoryManagerView()
            }
        }
    }

    private var dataGroup: some View {
        SettingsGroup(title: "데이터") {
            // Built on demand rather than in `body`: eagerly joining the whole ledger into a
            // string on every view update would cost the same whether or not the user ever shares.
            Button {
                exportedCSV = LedgerCSV(transactions: allTransactions, catalog: catalog)
            } label: {
                SettingsRowLabel(title: "소비 데이터 내보내기", value: "CSV")
            }
            .buttonStyle(.plain)
            .disabled(allTransactions.isEmpty)
            .sheet(item: $exportedCSV) { csv in
                ShareSheet(csv: csv)
            }
        }
    }

    private var infoGroup: some View {
        SettingsGroup(title: "앱 정보") {
            SettingsRowLabel(title: "버전 정보", value: appVersion, showsChevron: false)

            Text("기록한 내역은 이 기기 안에만 저장됩니다. 외부로 전송되지 않으며, 앱을 삭제하면 함께 지워집니다.")
                .font(.captionSmall)
                .foregroundStyle(Palette.textTertiary)
                .padding(.top, 4)
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.captionSmall)
                .foregroundStyle(Palette.textTertiary)
            VStack(spacing: 10) { content }
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.rowTitle)
                .foregroundStyle(Palette.textPrimary)
        }
        .tint(Palette.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border, lineWidth: 1))
    }
}

private struct SettingsRowLabel: View {
    let title: String
    var value: String?
    var showsChevron = true

    var body: some View {
        HStack {
            Text(title)
                .font(.rowTitle)
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            if let value {
                Text(value)
                    .font(.captionSmall)
                    .foregroundStyle(Palette.textTertiary)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border, lineWidth: 1))
    }
}
