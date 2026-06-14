import Cocoa
import SwiftUI

@objc class MainSwiftViewController: NSViewController {
    @objc let libraryController: MCLibraryController
    @objc weak var clickedCape: MCCursorLibrary?

    private var viewModel: LibraryViewModel
    private var editWindowController: MCEditWindowController?

    @objc var selectedCape: MCCursorLibrary? {
        get { viewModel.selectedCape }
        set { viewModel.selectedCape = newValue }
    }

    @objc var editingCape: MCCursorLibrary? {
        editWindowController?.cursorLibrary
    }

    @objc init(controller: MCLibraryController) {
        self.libraryController = controller
        let vm = LibraryViewModel(controller: controller)
        self.viewModel = vm
        super.init(nibName: nil, bundle: nil)
    }

    @objc required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let hv = NSHostingView(rootView: MainContentView(viewModel: self.viewModel))
        hv.autoresizingMask = [.width, .height]
        view = hv
    }

    @objc func editCape(_ library: MCCursorLibrary?) {
        guard let library else { return }
        if editWindowController == nil {
            editWindowController = MCEditWindowController(windowNibName: "Edit")
            editWindowController?.loadWindow()
        }
        editWindowController?.cursorLibrary = library
        editWindowController?.showWindow(self)
    }
}
