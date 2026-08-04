import SwiftUI
import LocalAuthentication

/// Covers the ledger until the user authenticates, when 생체 인증 사용 is on.
struct LockScreen: View {
    let onUnlock: () -> Void

    @State private var isAuthenticating = false
    @State private var failed = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 36))
                .foregroundStyle(Palette.accent)

            Text("다비드 가계부")
                .font(.screenTitle)
                .foregroundStyle(Palette.textPrimary)

            Text(failed ? "인증에 실패했습니다. 다시 시도해 주세요." : "잠금을 해제하면 가계부가 열립니다.")
                .font(.captionSmall)
                .foregroundStyle(Palette.textTertiary)

            Button("잠금 해제") { authenticate() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(Palette.accent)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(isAuthenticating)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
        .task { authenticate() }
    }

    private func authenticate() {
        guard !isAuthenticating else { return }

        let context = LAContext()
        context.localizedCancelTitle = "취소"

        // Without this check the lock has no way out. `deviceOwnerAuthentication` needs a device
        // passcode, so a user who turns the passcode off after enabling the lock can no longer
        // satisfy it: every attempt fails the same way, 잠금 해제 is the only control on the screen,
        // and the ledger behind it is unreachable for good. 설정 already refuses to switch the lock
        // on when the policy cannot be evaluated, so it must not stay on once that becomes true.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            AppSettings.shared.biometricLockEnabled = false
            onUnlock()
            return
        }

        isAuthenticating = true
        // deviceOwnerAuthentication rather than biometrics-only, so a passcode still works when
        // Face ID fails or is unavailable.
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "가계부를 열려면 인증이 필요합니다") { success, _ in
            Task { @MainActor in
                isAuthenticating = false
                failed = !success
                if success { onUnlock() }
            }
        }
    }
}
