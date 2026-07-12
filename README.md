# Travel Timeline iOS

An iOS SwiftUI starter app for a private Google Maps Timeline-style travel journal.

## What it does

- Requests location permission and can track in the background when the user grants Always permission.
- Saves visited places locally on the device.
- Groups nearby location updates into a single visit using a 150 meter radius.
- Shows saved places on a map and in a timeline list.
- Lets you rename each place and add notes.
- Lets you attach up to four photos per place.

## How to run

1. Open `TravelTimeline.xcodeproj` in Xcode.
2. Select the `TravelTimeline` target.
3. In **Signing & Capabilities**, choose your Apple Developer Team.
4. Run on a physical iPhone for realistic background location behavior.

The iOS Simulator can test the UI and simulated locations, but background movement tracking is best verified on a device.

## Privacy and App Store notes

Because this app records background location, the permission copy and App Store privacy details must be very clear. Keep the timeline local unless you add explicit sync/export controls later.
