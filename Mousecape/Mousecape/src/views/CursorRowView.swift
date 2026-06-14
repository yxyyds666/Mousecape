import SwiftUI

struct CursorRowView: View {
    let library: MCCursorLibrary
    let isApplied: Bool

    var body: some View {
        HStack(spacing: 0) {
            Text(library.name ?? "")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(red: 0.90, green: 0.95, blue: 1.0))

            Spacer()

            if isApplied {
                Text("Applied")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(red: 0.22, green: 0.74, blue: 0.97))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.06, green: 0.11, blue: 0.20, opacity: 0.82))
                    .cornerRadius(8)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.08, green: 0.18, blue: 0.32, opacity: 0.55))
        )
    }
}

extension MCCursorLibrary {
    @objc var capeImage: NSImage? {
        guard let cursorsSet = cursors as? Set<AnyHashable>,
              let firstCursor = cursorsSet.first as? MCCursor
        else { return nil }
        return firstCursor.imageWithAllReps()
    }
}
