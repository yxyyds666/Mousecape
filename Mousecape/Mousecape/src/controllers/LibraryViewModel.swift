import Cocoa
import Combine

class LibraryViewModel: NSObject, ObservableObject {
    @Published var capes: [MCCursorLibrary] = []
    @Published var appliedCape: MCCursorLibrary?
    @Published var selectedCape: MCCursorLibrary?
    @Published var clickedCape: MCCursorLibrary?
    let controller: MCLibraryController

    private var capesObservation: NSKeyValueObservation?

    init(controller: MCLibraryController) {
        self.controller = controller
        super.init()

        if let initialCapes = controller.capes as? Set<MCCursorLibrary> {
            self.capes = initialCapes.sorted { $0.name < $1.name }
        }

        self.appliedCape = controller.appliedCape

        capesObservation = controller.observe(\.capes, options: []) { [weak self] _, _ in
            self?.reloadCapes()
        }

        controller.addObserver(self, forKeyPath: "appliedCape", options: .initial, context: nil)
    }

    func reloadCapes() {
        if let capesSet = controller.capes as? Set<MCCursorLibrary> {
            self.capes = capesSet.sorted { $0.name < $1.name }
        }
    }

    func importCape(at url: URL) {
        controller.importCape(at: url)
    }

    func applyCape(_ library: MCCursorLibrary) {
        controller.applyCape(library)
    }

    func selectCape(_ library: MCCursorLibrary?) {
        self.selectedCape = library
    }

    func duplicateCape(_ library: MCCursorLibrary) {
        controller.importCape(library.copy() as! MCCursorLibrary)
    }

    func removeCape(_ library: MCCursorLibrary) {
        controller.removeCape(library)
    }

    func showInFinder(_ library: MCCursorLibrary) {
        NSWorkspace.shared.activateFileViewerSelecting([library.fileURL])
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "appliedCape" {
            self.appliedCape = controller.appliedCape
        }
    }

    deinit {
        controller.removeObserver(self, forKeyPath: "appliedCape")
    }
}
