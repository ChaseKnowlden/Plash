import SwiftUI
import Combine
import Defaults

final class WebsitesController {
	static let shared = WebsitesController()

	private var cancellables = Set<AnyCancellable>()
	private var _current: Website? { all.first(where: \.isCurrent) }
	private var nextCurrent: Website? { all.elementAfterOrFirst(_current) }
	private var previousCurrent: Website? { all.elementBeforeOrLast(_current) }

	let thumbnailCache = SimpleImageCache<String>(diskCacheName: "websiteThumbnailCache")

	/// The current website.
	var current: Website? {
		get { _current ?? all.first }
		set {
			guard let website = newValue else {
				all = all.modifying {
					$0.isCurrent = false
				}

				return
			}

			makeCurrent(website)
		}
	}

	/// All websites.
	var all: [Website] {
		get { Defaults[.websites] }
		set {
			Defaults[.websites] = newValue
		}
	}

	let allBinding = Defaults.bindingCollection(for: .websites)

	init() {
		setUpEvents()
		thumbnailCache.prewarmCacheFromDisk(for: all.map(\.thumbnailCacheKey))
	}

	private func setUpEvents() {
		Defaults.publisher(.websites)
			.sink { change in
				// Ensures there's always a current website.
				if
					change.newValue.allSatisfy(!\.isCurrent),
					let website = change.newValue.first
				{
					website.makeCurrent()
				}
			}
			.store(in: &cancellables)
	}

	/// Make a website the current one.
	private func makeCurrent(_ website: Website) {
		all = all.modifying {
			$0.isCurrent = $0.id == website.id
		}
	}

	/// Add a website.
	@discardableResult
	func add(_ website: Website) -> Binding<Website> {
		// The order here is important.
		all.append(website)
		current = website

		return allBinding[id: website.id]!
	}

	/// Remove a website.
	func remove(_ website: Website) {
		all = all.removingAll(website)
	}

	/// Makes the next website the current one.
	func makeNextCurrent() {
		guard let website = nextCurrent else {
			return
		}

		makeCurrent(website)
	}

	/// Makes the previous website the current one.
	func makePreviousCurrent() {
		guard let website = previousCurrent else {
			return
		}

		makeCurrent(website)
	}
}
