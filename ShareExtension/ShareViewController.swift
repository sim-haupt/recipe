import SwiftUI
import UIKit

final class ShareViewController: UIViewController {
    private var hostingController: UIHostingController<ShareComposerView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let viewModel = ShareViewModel(extensionItems: extensionItems)
        let rootView = ShareComposerView(
            viewModel: viewModel,
            onCancel: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            },
            onComplete: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        )

        let hostingController = UIHostingController(rootView: rootView)
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
        self.hostingController = hostingController

        Task {
            await viewModel.load()
        }
    }
}
