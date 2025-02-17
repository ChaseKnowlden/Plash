import Combine
import WebKit
import Defaults

final class SSWebView: WKWebView {
	private var cancellables = Set<AnyCancellable>()

	private var excludedMenuItems: Set<MenuItemIdentifier> = [
		.downloadImage,
		.downloadLinkedFile,
		.downloadMedia,
		.openLinkInNewWindow,
		.shareMenu,
		.toggleEnhancedFullScreen,
		.toggleFullScreen
	]

	override init(frame: CGRect, configuration: WKWebViewConfiguration) {
		super.init(frame: frame, configuration: configuration)

		Defaults.publisher(.isBrowsingMode)
			.sink { [weak self] _ in
				self?.toggleBrowsingModeClass()
			}
			.store(in: &cancellables)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
		for menuItem in menu.items {
			// Debug menu items
			// print("Menu Item:", menuItem.title, menuItem.identifier?.rawValue ?? "")

			if let identifier = MenuItemIdentifier(menuItem) {
				if
					identifier == .openImageInNewWindow,
					menuItem.title == "Open Image in New Window"
				{
					menuItem.title = "Open Image"
				}

				if
					identifier == .openMediaInNewWindow,
					menuItem.title == "Open Video in New Window"
				{
					menuItem.title = "Open Video"
				}

				if
					identifier == .openFrameInNewWindow,
					menuItem.title == "Open Frame in New Window"
				{
					menuItem.title = "Open Frame"
				}

				if
					identifier == .openLinkInNewWindow,
					menuItem.title == "Open Link in New Window"
				{
					menuItem.title = "Open Link"
				}
			}
		}

		menu.items.removeAll {
			guard let identifier = MenuItemIdentifier($0) else {
				return false
			}

			return excludedMenuItems.contains(identifier)
		}

		menu.addSeparator()

		let zoomLevel: Double
		if #available(macOS 11, *) {
			zoomLevel = Double(pageZoom)
		} else {
			zoomLevel = self.zoomLevel
		}

		menu.addCallbackItem("Actual Size", isEnabled: zoomLevel != 1) { [weak self] _ in
			self?.zoomLevelWrapper = 1
		}

		menu.addCallbackItem("Zoom In") { [weak self] _ in
			self?.zoomLevelWrapper += 0.2
		}

		menu.addCallbackItem("Zoom Out") { [weak self] _ in
			self?.zoomLevelWrapper -= 0.2
		}

		// Move the “Inspect Element” menu item to the end.
		if let menuItem = (menu.items.first { MenuItemIdentifier($0) == .inspectElement }) {
			menu.addSeparator()
			menu.items = menu.items.movingToEnd(menuItem)
		}

		if Defaults[.hideMenuBarIcon] {
			menu.addSeparator()

			menu.addCallbackItem("Show Menu Bar Icon") { _ in
				AppDelegate.shared.handleMenuBarIcon()
			}
		}

		// For the implicit “Services” menu.
		menu.addSeparator()
	}

	func toggleBrowsingModeClass() {
		let method = Defaults[.isBrowsingMode] ? "add" : "remove"
		let code = "document.documentElement.classList.\(method)('plash-is-browsing-mode')"
		self.evaluateJavaScript(code) { _, _ in }
	}
}

extension SSWebView {
	private var zoomLevelDefaultsKey: Defaults.Key<Double?>? {
		guard let url = url?.normalized(removeFragment: true, removeQuery: true) else {
			return nil
		}

		return .init("zoomLevel_\(url)")
	}

	var zoomLevelDefaultsValue: Double? {
		guard
			let zoomLevelDefaultsKey = zoomLevelDefaultsKey,
			let zoomLevel = Defaults[zoomLevelDefaultsKey]
		else {
			return nil
		}

		return zoomLevel
	}

	var zoomLevelWrapper: Double {
		get {
			if #available(macOS 11, *) {
				return zoomLevelDefaultsValue ?? Double(pageZoom)
			} else {
				return zoomLevelDefaultsValue ?? zoomLevel
			}
		}
		set {
			if #available(macOS 11, *) {
				pageZoom = CGFloat(newValue)
			} else {
				zoomLevel = newValue
			}

			if let zoomDefaultsKey = zoomLevelDefaultsKey {
				Defaults[zoomDefaultsKey] = newValue
			}
		}
	}
}
