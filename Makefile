.PHONY: test unit format lint screenshots icon listing

# Build and run all unit and UI tests on an iPad simulator.
test:
	bash scripts/test.sh .

# Unit tests only (fast).
unit:
	bash scripts/test.sh . -only-testing:ShellyCodesTests

format:
	xcrun swift-format format --in-place --recursive --parallel ShellyCodes ShellyCodesTests ShellyCodesUITests scripts

lint:
	xcrun swift-format lint --strict --recursive --parallel ShellyCodes ShellyCodesTests ShellyCodesUITests scripts

# App Store screenshots for the 13-inch iPad, saved to screenshots/.
screenshots:
	bash scripts/screenshots.sh

# Redraw the app icon.
icon:
	swift scripts/make_icon.swift ShellyCodes/Assets.xcassets/AppIcon.appiconset/AppIcon.png

# Check the App Store listing in APP_STORE.md against Apple's limits.
listing:
	python3 scripts/check_listing.py
