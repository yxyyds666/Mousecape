import SwiftUI

struct MainContentView: View {
    @StateObject var viewModel: LibraryViewModel

    var body: some View {
        VStack(spacing: 0) {
            ImportHeaderView(
                importCapeAction: {
                    NSApp.sendAction(NSSelectorFromString("openDocument:"), to: nil, from: nil)
                },
                convertWindowsAction: {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.canCreateDirectories = false
                    panel.title = NSLocalizedString("Convert Windows Cursor Theme", comment: "Panel title for importing Windows cursor themes")
                    panel.message = NSLocalizedString("Choose a folder with .inf file for Windows cursor theme", comment: "Panel message for selecting cursor theme folder")
                    guard let window = (NSApp.delegate as? MCAppDelegate)?.libraryWindowController.window else { return }
                    panel.beginSheetModal(for: window) { result in
                        if result != .OK { return }
                        do {
                            let importResult = try MCWindowsCursorImporter.importCursor(at: panel.url)
                            guard let lib = importResult.cursorLibrary else {
                                let alert = NSAlert()
                                alert.messageText = NSLocalizedString("Import Failed", comment: "Alert title when cursor library object is nil")
                                alert.informativeText = NSLocalizedString("Cursor library object is empty", comment: "Alert message when cursor library object is nil")
                                alert.addButton(withTitle: "OK")
                                DispatchQueue.main.async {
                                    alert.beginSheetModal(for: window, completionHandler: nil)
                                }
                                return
                            }
                            if let controller = (NSApp.delegate as? MCAppDelegate)?.libraryWindowController.libraryController {
                                controller.importCape(lib)
                            }
                            let fmt: String
                            if importResult.errors.count > 0 {
                                fmt = NSLocalizedString("Imported %@. %ld warnings, %ld skipped roles, %ld errors: %@", comment: "Import result with errors")
                                let detailText = String(format: fmt, lib.name ?? "", importResult.warnings.count, importResult.skippedRoles.count, importResult.errors.count, importResult.errors.map { $0.localizedDescription }.joined(separator: "; "))
                                let alert = NSAlert()
                                alert.messageText = NSLocalizedString("Import Complete", comment: "Alert title when import succeeds")
                                alert.informativeText = detailText
                                alert.addButton(withTitle: "OK")
                                DispatchQueue.main.async {
                                    alert.beginSheetModal(for: window, completionHandler: nil)
                                }
                            } else {
                                fmt = NSLocalizedString("Imported %@. %ld warnings, %ld skipped roles.", comment: "Import result summary")
                                let detailText = String(format: fmt, lib.name ?? "", importResult.warnings.count, importResult.skippedRoles.count)
                                let alert = NSAlert()
                                alert.messageText = NSLocalizedString("Import Complete", comment: "Alert title when import succeeds")
                                alert.informativeText = detailText
                                alert.addButton(withTitle: "OK")
                                DispatchQueue.main.async {
                                    alert.beginSheetModal(for: window, completionHandler: nil)
                                }
                            }
                        } catch {
                            let alert = NSAlert()
                            alert.messageText = NSLocalizedString("Import Failed", comment: "Alert title when import fails")
                            alert.informativeText = String(format: NSLocalizedString("Error: %@", comment: "Import error detail"), error.localizedDescription)
                            alert.addButton(withTitle: "OK")
                            DispatchQueue.main.async {
                                alert.beginSheetModal(for: window, completionHandler: nil)
                            }
                        }
                    }
                }
            )
            .padding(.horizontal, 20)
            .padding(.top, 18)

            Text("Imported Cursor Sets")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(red: 0.70, green: 0.86, blue: 1.0))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 24)
                .padding(.top, 18)
                .padding(.bottom, 10)

            List(viewModel.capes, id: \.identifier) { library in
                CursorRowView(
                    library: library,
                    isApplied: library.identifier == viewModel.appliedCape?.identifier
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .onTapGesture(count: 2) {
                    viewModel.applyCape(library)
                }
                .onTapGesture {
                    viewModel.selectCape(library)
                }
                .contextMenu {
                    Button("Apply") {
                        viewModel.clickedCape = library
                        viewModel.applyCape(library)
                    }
                    Button("Edit...") {
                        viewModel.clickedCape = library
                        if let wc = (NSApp.keyWindow?.windowController as? MCLibraryWindowController) {
                            wc.mainViewController.editCape(library)
                        }
                    }
                    Button("Duplicate") {
                        viewModel.clickedCape = library
                        viewModel.duplicateCape(library)
                    }
                    Button("Delete") {
                        viewModel.clickedCape = library
                        viewModel.removeCape(library)
                    }
                    Divider()
                    Button("Show in Finder") {
                        viewModel.clickedCape = library
                        viewModel.showInFinder(library)
                    }
                }
            }
            .listStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.03, green: 0.07, blue: 0.13))
    }
}
