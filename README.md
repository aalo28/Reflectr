# Reflectr

A training **reflection** app for iOS. Plan your workouts, let your completed
sessions flow in from Apple Health, and — the whole point — reflect on how each
one actually went so you can improve week over week.

## Idea

After a session you capture:

- **How it felt** — overall feeling, energy, and perceived effort (RPE).
- **What went well** and **what wasn't optimal**.
- **Keep in mind next time** and **what to try next time**.
- Quick **tags** (poor sleep, great flow, sore, …) to spot patterns.

Then, at the end of the week, the **Review** tab shows what changed vs. last
week and carries your "try next time" notes forward.

## Features

- **Calendar** — month grid with a dot per workout (filled = completed, ring =
  planned). Tap a day to see and reflect on its sessions.
- **Plan** — schedule upcoming sessions with a focus; mark them complete, then
  reflect. Also surfaces completed workouts still missing a reflection.
- **Review** — week-over-week stats (sessions, time, avg feeling, avg effort),
  a 6-week feeling trend, follow-ups to carry forward, and recurring themes.
- **Apple Health import** — completed workouts import automatically. Garmin,
  Apple Watch and most trackers write to Apple Health, so their sessions appear
  here too.
- **Prior advice** — before a session, Reflectr shows the "try next time" notes
  from your last few sessions of the same type.
- **iCloud sync** — SwiftData + CloudKit private database, across your devices.

## Tech

- SwiftUI + SwiftData (`@Model`), CloudKit private database.
- HealthKit for workout import (`HealthKitManager`).
- Swift Charts for the feeling trend.
- iOS 26, single app target, Xcode 16 synchronized folder groups.

## Build

Open `Reflectr.xcodeproj` in Xcode and run. On first launch, enable
**Import from Apple Health** in Settings to pull in your workouts.

> The bundle id (`com.aalohan.Reflectr`), iCloud container
> (`iCloud.com.aalohan.Reflectr`) and team are placeholders you can change in
> the target's Signing & Capabilities. Xcode will offer to create the CloudKit
> container on first run.
