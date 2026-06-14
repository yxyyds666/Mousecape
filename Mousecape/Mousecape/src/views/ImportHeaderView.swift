import SwiftUI

struct ImportHeaderView: View {
    var importCapeAction: () -> Void
    var convertWindowsAction: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(red: 0.05, green: 0.10, blue: 0.19, opacity: 0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color(red: 0.22, green: 0.74, blue: 0.97, opacity: 0.34), lineWidth: 1)
                )
                .shadow(color: Color(red: 0.22, green: 0.74, blue: 0.97, opacity: 0.35), radius: 18)

            VStack(alignment: .leading, spacing: 8) {
                Text("Import Cursors")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(red: 0.90, green: 0.96, blue: 1.0))
                Text("Import .cape files or convert Windows cursor themes")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.56, green: 0.65, blue: 0.78))
            }
            .padding(.leading, 22)

            HStack(spacing: 12) {
                Spacer()
                if #available(macOS 12.0, *) {
                    Button("Convert") { convertWindowsAction() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.22, green: 0.74, blue: 0.97))
                        .controlSize(.large)
                    Button("Import", action: importCapeAction)
                        .controlSize(.large)
                } else {
                    Button("Convert") { convertWindowsAction() }
                    Button("Import", action: importCapeAction)
                }
            }
            .padding(.trailing, 22)
        }
        .frame(height: 122)
    }
}
