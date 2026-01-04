import SwiftUI

/// View displayed when accessibility permissions are not granted.
/// Guides the user through enabling accessibility access.
struct PermissionsView: View {
    @State private var isCheckingPermission = false

    let onPermissionGranted: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "hand.raised.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)

            // Title
            VStack(spacing: 8) {
                Text("Accessibility Permission Required")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("AppMux needs accessibility access to manage windows from other applications.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(number: 1, text: "Click \"Open System Settings\" below")
                InstructionRow(number: 2, text: "Find AppMux in the list")
                InstructionRow(number: 3, text: "Toggle the switch to enable access")
                InstructionRow(number: 4, text: "Return to AppMux")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
            )

            // Buttons
            HStack(spacing: 16) {
                Button("Open System Settings") {
                    AccessibilityService.shared.openAccessibilitySettings()
                }
                .buttonStyle(.borderedProminent)

                Button("Check Again") {
                    checkPermission()
                }
                .buttonStyle(.bordered)
                .disabled(isCheckingPermission)
            }

            // Status indicator
            if isCheckingPermission {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(40)
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            startPermissionPolling()
        }
    }

    private func checkPermission() {
        isCheckingPermission = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isCheckingPermission = false

            if AccessibilityService.shared.isAccessibilityEnabled {
                onPermissionGranted()
            }
        }
    }

    private func startPermissionPolling() {
        // Poll for permission changes every 2 seconds
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            if AccessibilityService.shared.isAccessibilityEnabled {
                timer.invalidate()
                onPermissionGranted()
            }
        }
    }
}

/// A single instruction row with a number badge.
struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(.blue))

            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    PermissionsView(onPermissionGranted: {})
}
