import SwiftUI

/// Zero-size UIViewController anchor so AdManager always has a presenter.
/// Add one to your root view:
///
///     ZStack {
///         AdPresenter().frame(width: 0, height: 0)
///         // rest of view...
///     }
struct AdPresenter: UIViewControllerRepresentable {
    static weak var holder: UIViewController?

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        Self.holder = vc
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        Self.holder = uiViewController
    }
}
