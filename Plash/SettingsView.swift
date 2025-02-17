import SwiftUI
import LaunchAtLogin
import Defaults
import KeyboardShortcuts

private struct HideMenuBarIconSetting: View {
	@State private var isShowingAlert = false

	var body: some View {
		Defaults.Toggle("Hide menu bar icon", key: .hideMenuBarIcon)
			.onChange {
				isShowingAlert = $0
			}
			.alert(isPresented: $isShowingAlert) {
				Alert(
					title: Text("If you need to access the Plash menu, launch the app again to reveal the menu bar icon for 5 seconds.")
				)
			}
	}
}

private struct ShowOnAllSpacesSetting: View {
	var body: some View {
		Defaults.Toggle(
			"Show on all spaces",
			key: .showOnAllSpaces
		)
			.help2("When disabled, the website will be shown on the space that was active when Plash launched.")
	}
}

private struct BringBrowsingModeToFrontSetting: View {
	var body: some View {
		// TODO: Find a better title for this.
		Defaults.Toggle(
			"Bring “Browsing Mode” to the front",
			key: .bringBrowsingModeToFront
		)
			.help2("Keep the website above all other windows while “Browsing Mode” is active.")
	}
}

private struct OpenExternalLinksInBrowserSetting: View {
	var body: some View {
		Defaults.Toggle(
			"Open external links in default browser",
			key: .openExternalLinksInBrowser
		)
			.help2("If a website requires login, you should disable this setting while logging in as the website might require you to navigate to a different page, and you don't want that to open in a browser instead of Plash.")
	}
}

private struct OpacitySetting: View {
	@Default(.opacity) private var opacity

	var body: some View {
		Slider(
			value: $opacity,
			in: 0.1...1,
			step: 0.1
		) {
			Text("Opacity:")
		}
	}
}

private struct ReloadIntervalSetting: View {
	private static let defaultReloadInterval = 60.0
	private static let minimumReloadInterval = 0.1

	private static let reloadIntervalFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.formattingContext = .standalone
		formatter.locale = Locale.autoupdatingCurrent
		formatter.numberStyle = .decimal
		formatter.minimum = NSNumber(value: minimumReloadInterval)
		formatter.minimumFractionDigits = 1
		formatter.maximumFractionDigits = 1
		formatter.isLenient = true
		return formatter
	}()

	@Default(.reloadInterval) private var reloadInterval

	private var reloadIntervalInMinutes: Binding<Double> {
		$reloadInterval.withDefaultValue(Self.defaultReloadInterval).secondsToMinutes
	}

	private var hasInterval: Binding<Bool> {
		$reloadInterval.isNotNil(trueSetValue: Self.defaultReloadInterval)
	}

	// TODO: Improve VoiceOver accessibility for this control.
	var body: some View {
		HStack(alignment: OS.isMacOSBigSurOrLater ? .firstTextBaseline : .center) {
			Text("Reload Interval:")
			Toggle(isOn: hasInterval) {
				Stepper(
					value: reloadIntervalInMinutes,
					in: Self.minimumReloadInterval...(.greatestFiniteMagnitude),
					step: 1
				) {
					TextField(
						"",
						value: reloadIntervalInMinutes,
						formatter: Self.reloadIntervalFormatter
					)
						.frame(width: 70)
						.labelsHidden()
				}
					.disabled(!hasInterval.wrappedValue)
				Text("minutes")
					.padding(.leading, 4)
			}
				// TODO: Use `.accessibilityLabel` when targeting macOS 11.
				.accessibility(label: Text("Reload interval in minutes"))
		}
	}
}

private struct DisplaySetting: View {
	@ObservedObject private var displayWrapper = Display.observable
	@Default(.display) private var chosenDisplay

	var body: some View {
		Picker(
			"Show On Display:",
			selection: $chosenDisplay.getMap(\.withFallbackToMain)
		) {
			ForEach(displayWrapper.wrappedValue.all, id: \.self) { display in
				Text(display.localizedName)
					.tag(display)
			}
		}
	}
}

private struct KeyboardShortcutsSection: View {
	private let maxWidth: CGFloat = 160

	var body: some View {
		VStack {
			HStack(alignment: .firstTextBaseline) {
				Text("Toggle “Browsing Mode”:")
					.frame(width: maxWidth, alignment: .trailing)
				KeyboardShortcuts.Recorder(for: .toggleBrowsingMode)
			}
				.accessibilityElement()
			HStack(alignment: .firstTextBaseline) {
				Text("Reload:")
					.frame(width: maxWidth, alignment: .trailing)
				KeyboardShortcuts.Recorder(for: .reload)
			}
			HStack(alignment: .firstTextBaseline) {
				Text("Next Website:")
					.frame(width: maxWidth, alignment: .trailing)
				KeyboardShortcuts.Recorder(for: .nextWebsite)
			}
			HStack(alignment: .firstTextBaseline) {
				Text("Previous Website:")
					.frame(width: maxWidth, alignment: .trailing)
				KeyboardShortcuts.Recorder(for: .previousWebsite)
			}
		}
	}
}

private struct ClearWebsiteDataSetting: View {
	@State private var hasCleared = false

	var body: some View {
		Button("Clear All Website Data") {
			hasCleared = true
			AppDelegate.shared.webViewController.webView.clearWebsiteData(completion: nil)
			WebsitesController.shared.thumbnailCache.removeAllImages()
		}
			.disabled(hasCleared)
			.help2("Clears all cookies, local storage, caches, etc.")
			// TODO: Mark it as destructive when SwiftUI supports that.
	}
}

struct SettingsView: View {
	var body: some View {
		Form {
			VStack {
				Section {
					VStack(alignment: .leading) {
						LaunchAtLogin.Toggle()
						HideMenuBarIconSetting()
						Defaults.Toggle("Deactivate while on battery", key: .deactivateOnBattery)
						ShowOnAllSpacesSetting()
						BringBrowsingModeToFrontSetting()
						OpenExternalLinksInBrowserSetting()
					}
				}
				Divider()
					.padding(.vertical)
				Section {
					OpacitySetting()
				}
				Divider()
					.padding(.vertical)
				Section {
					ReloadIntervalSetting()
				}
				Divider()
					.padding(.vertical)
				Section {
					DisplaySetting()
					Divider()
						.padding(.vertical)
					KeyboardShortcutsSection()
					Divider()
						.padding(.vertical)
					ClearWebsiteDataSetting()
				}
			}
				.frame(width: 380)
				.padding()
				.padding()
		}
	}
}

struct SettingsView_Previews: PreviewProvider {
	static var previews: some View {
		SettingsView()
	}
}
