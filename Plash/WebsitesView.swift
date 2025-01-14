import SwiftUI
import LinkPresentation
import Defaults

@available(macOS 11, *)
private struct IconView: View {
	@State private var iconFetcher: WebsiteIconFetcher?
	@State private var icon: Image?

	let website: Website

	var body: some View {
		Group {
			if let icon = icon {
				icon
					.resizable()
					.aspectRatio(contentMode: .fit)
			} else {
				Color.primary.opacity(0.1)
			}
		}
			.frame(width: 32, height: 32)
			.clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
			.onAppear {
				fetchIcons()
			}
	}

	private func fetchIcons() {
		let cache = WebsitesController.shared.thumbnailCache

		if let image = cache[website.thumbnailCacheKey] {
			icon = Image(nsImage: image)
			return
		}

		LPMetadataProvider().startFetchingMetadata(for: website.url) { metadata, error in
			if error != nil {
				return
			}

			guard
				let iconProvider = metadata?.iconProvider,
				iconProvider.hasItemConformingToTypeIdentifier("public.image")
			else {
				DispatchQueue.main.async {
					iconFetcher = WebsiteIconFetcher()
					iconFetcher?.fetch(for: website.url) {
						guard let image = $0 else {
							return
						}

						cache[website.thumbnailCacheKey] = image
						icon = Image(nsImage: image)
					}
				}

				return
			}

			iconProvider.getImage {
				guard let image = $0 else {
					return
				}

				cache[website.thumbnailCacheKey] = image
				icon = Image(nsImage: image)
			}
		}
	}
}

private struct RowView: View {
	@State private var isShowingEditSheet = false

	@Binding var website: Website

	var body: some View {
		HStack {
			if #available(macOS 11, *) {
				IconView(website: website)
					.padding(.trailing, 7)
					.id(website.url)
			}
			// TODO: This should use something like `.lineBreakMode = .byCharWrapping` if SwiftUI ever supports that.
			VStack(alignment: .leading) {
				Text(website.title)
					.font(.headline)
					.lineLimit(1)
				Text(website.subtitle)
					.font(.subheadline)
					.foregroundColor(.secondary)
					.lineLimit(1)
			}
			Spacer()
			if website.isCurrent {
				if #available(macOS 11, *) {
					Image(systemName: "checkmark.circle.fill")
						.renderingMode(.original)
						.font(.title2)
				} else {
					Text("Current")
						.font(.subheadline)
				}
			}
		}
			.padding(.horizontal)
			// TODO: Use `.listRowInsets` instead when targeting macOS 11.
			.frame(height: OS.isMacOSBigSurOrLater ? 64 : 44)
			// TODO: This makes `onMove` not work when clicking the text.
			// https://github.com/feedback-assistant/reports/issues/46
			// Still an issue on macOS 11.2.3.
//			.onTapGesture(count: 2) {
//				edit()
//			}
			.help2(website.tooltip)
			.sheet(isPresented: $isShowingEditSheet) {
				AddWebsiteView(
					isEditing: true,
					website: $website
				)
			}
			.contextMenu {
				// TODO: Any better label for this?
				Button("Make Current") {
					website.makeCurrent()
				}
					.disabled(website.isCurrent)
				Divider()
				Button("Edit…") {
					edit()
				}
				Divider()
				Button("Delete") {
					website.remove()
				}
			}
	}

	private func edit() {
		website.makeCurrent()
		isShowingEditSheet = true
	}
}

struct WebsitesView: View {
	@Default(.websites) private var websites
	@State private var isShowingAddSheet = false

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Spacer()
				CocoaButton("Add…", keyEquivalent: .return) {
					isShowingAddSheet = true
				}
			}
				.padding()
			List {
				ForEach($websites) { index, website in
					RowView(website: website)

					// Workaround for bug where new entries have almost no height. (macOS 11.3)
					if index == websites.count - 1 {
						Color.clear
							.frame(height: 1)
							.overlay(
								Color(NSColor.alternatingContentBackgroundColors[0])
									.frame(maxWidth: .infinity, maxHeight: .infinity)
									.padding(-6)
							)
					}
				}
					.onMove(perform: move)
					.onDelete(perform: delete)
					.listRowBackground(
						OS.isMacOSBigSurOrLater
							? Color.primary
								.opacity(0.04)
								.border(.primary.opacity(0.07), width: 1, cornerRadius: 6, cornerStyle: .continuous)
								.padding(.vertical, 6)
							: nil
					)
			}
				.overlay(
					websites.isEmpty
						? Text("No Websites").emptyStateTextStyle()
						: nil,
					alignment: .center
				)
				.overlay(Divider(), alignment: .top)
			if !websites.isEmpty {
				// TODO: Use proper vibrancy material and list inset when supported in SwiftUI.
				Text("Right-click to edit. Drag and drop to reorder.")
					.font(.system(size: 10))
					.frame(maxWidth: .infinity)
					.frame(height: 32)
					.background(Color.primary.opacity(0.02))
					.foregroundColor(.secondary)
					.overlay(Divider(), alignment: .top)
			}
		}
			.frame(
				width: 420,
				height: 520
			)
			.sheet2(isPresented: $isShowingAddSheet) {
				AddWebsiteView(
					isEditing: false,
					website: nil
				)
			}
			.onNotification(.showAddWebsiteDialog) { _ in
				isShowingAddSheet = true
			}
			// TODO: When targeting macOS 11 and using `App` protocol.
//			.toolbar {
//				ToolbarItem(placement: .confirmationAction) {
//					Button {
//						isShowingAddSheet = true
//					} label: {
//						Image(systemName: "plus")
//					}
//						.keyboardShortcut(.defaultAction)
//				}
//			}
	}

	private func move(from source: IndexSet, to destination: Int) {
		websites = websites.moving(fromOffsets: source, toOffset: destination)
	}

	private func delete(at offsets: IndexSet) {
		websites = websites.removing(atOffsets: offsets)
	}
}

struct ManageWebsitesView_Previews: PreviewProvider {
    static var previews: some View {
		WebsitesView()
    }
}
