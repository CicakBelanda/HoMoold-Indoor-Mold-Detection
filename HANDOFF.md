# HoMoold — Project Handoff

iOS app (SwiftUI) that helps someone renting a *kos* (Indonesian boarding house) assess **mold risk before signing a lease**, by scanning a room's *pre-mold* signs — damp stains, cracks, poor ventilation — rather than visible mold (if mold is already visible, the decision is obvious: don't rent it). Persona "Saiful": a student/young worker doing a fast (10–15 min) self-survey with their phone during a room viewing.

Bahasa Indonesia is the in-app copy language throughout (casual/santai tone, no Lorem Ipsum, no overclaiming accuracy).

## Stack & architecture

- SwiftUI, MVVM, **feature-based folders** (not layer-based) under `HoMoold/Features/<Feature>/`.
- Xcode project uses `PBXFileSystemSynchronizedRootGroup` — any file dropped into `HoMoold/` is auto-included in the target, no manual pbxproj editing needed (except Info.plist keys, which live in `project.pbxproj` build settings as `INFOPLIST_KEY_*`, since there's no separate Info.plist file).
- No backend/auth. All data lives in-memory in `AppDataStore` (`@Published var properties: [KosProperty]`), seeded from `DummyDataFactory` on launch. **Data is lost on app relaunch** — this was accepted as a non-goal from the original spec, never revisited.
- Light mode only — `.preferredColorScheme(.light)` forced at the `HoMooldApp` root. No dark mode support exists.
- `HoMoold/ContentView.swift` is the **original template from a teammate (Kevin)** — deliberately preserved, not deleted. It's reachable by tapping the avatar circle (top-right) on the Home list, opened in a sheet labeled "Original Template".

## File map

```
HoMoold/
  HoMooldApp.swift, RootView.swift, ContentView.swift (preserved teammate template)
  Models/
    RoomType, RiskLevel, FindingClass, Finding, RoomInspection (+ DetectionItem),
    KosProperty, LiveDetection, RoomNavigationTarget
  Services/
    MoldDetectionService.swift   — protocol + MockMoldDetectionService (used in #Previews only)
    RealMoldDetectionService.swift — actual analysis using the CoreML models
    CameraService.swift          — AVCaptureSession wrapper (recording + live detection)
    LiveObjectDetector.swift     — Vision/CoreML wrapper, one instance per model
    LocationService.swift        — CoreLocation, silent kecamatan auto-fill
  Data/
    AppDataStore.swift           — the ObservableObject source of truth
    DummyDataFactory.swift       — 5 seed KosProperty entries
  Components/Common/
    RiskBadge, RoomTagRow, PropertyCard, BoundingBoxOverlay, InfoSheetButton,
    PillButton, FullScreenImageViewer
  Features/
    Onboarding/OnboardingView.swift
    Home/HomeListView(+ViewModel), PropertyDetailView(+ViewModel)
    Inspection/
      InspectionFlowState, InspectionFlowView   — NavigationStack container, two entry modes
      RoomTypeSelectionView, RecordVideoView, VideoPreviewView, AnalyzingLoadingView
      GuidedRecordingController, GuidedInstructionBar — live-guidance state machine + UI
      NewReportInfoView — final "name + price" step for a brand-new kos
    Report/ReportView(+ViewModel), MoldRiskInfoSheet
  Utilities/PlaceholderImageFactory.swift — procedural room illustrations for dummy data
  AI/MoldDamp.mlpackage, AI/WindowAC.mlpackage — compiled CoreML models (bundled)
ModelSource/MoldDamp.pt, WindowAC.pt — raw trained weights (NOT in the app target, kept for re-export)
```

## Navigation flow

```
RootView --(hasSeenOnboarding? AppStorage)--> OnboardingView | HomeListView
HomeListView (List, swipe-to-delete, long-press to rename, FAB = new kos)
  -> tap kos -> PropertyDetailView (dashed "+ Tambah Ruangan" row at top, room cards
                swipe-to-delete, "..." toolbar menu = rename/delete kos)
       -> tap room card -> ReportView (read-only mode)
       -> tap "+ Tambah Ruangan" -> InspectionFlowView(existingProperty: this kos)
  -> tap FAB -> InspectionFlowView(existingProperty: nil)   [new kos]

InspectionFlowView (fullScreenCover, own NavigationStack):
  RoomTypeSelectionView -> RecordVideoView -> VideoPreviewView -> AnalyzingLoadingView -> ReportView
    -> (existingProperty case) Save button saves directly, dismisses
    -> (new-kos case) Save button pushes NewReportInfoView (name + price; location
       already auto-filled via GPS in the background) -> saves, dismisses, Home
       navigates straight to the new kos's detail page
```

Navigation avoids `NavigationLink` deliberately (it auto-adds a disclosure chevron inside `List`) — rows use plain `Button` + manual `NavigationPath.append(...)`. `RoomNavigationTarget` is a small `Hashable` wrapper (propertyID+roomID) used to disambiguate room pushes from kos-UUID pushes on the *same* shared `NavigationPath` (`PropertyDetailView` receives that path as a `@Binding`).

## AI/ML pipeline

Two YOLO models the user trained themselves (Ultralytics), originally `.pt`:
- `MoldDamp.pt` → classes `{0: damp, 1: mold}`
- `WindowAC.pt` → classes `{0: AC, 1: Window}`

Converted to CoreML (`nms=True`) and bundled as `HoMoold/AI/*.mlpackage`. **Conversion required Python 3.12 in a dedicated venv** — the system's Python 3.14 hits `RuntimeError: BlobWriter not loaded` in coremltools, and Ultralytics' own numpy auto-upgrade to 2.x breaks the torch→CoreML frontend separately (pin `numpy<2`). Full recipe is in the project's Claude memory (`project_yolo_coreml_pipeline.md`) if these ever need re-export.

Two separate consumers of these models:

1. **Live guidance** (`RecordVideoView` + `GuidedRecordingController`, driven by `CameraService`'s `AVCaptureVideoDataOutput`, throttled ~0.35s): a state machine walks the user through steps — *Look for AC → Look for window → Scan all walls → Look for mold/damp* — auto-advancing when a target is detected for a sustained ~1s (not just a flicker), with a manual "Lewati" (skip) button. **Steps are per-room-type**: bathroom/kitchen skip the AC step entirely (bathrooms basically never have AC). No bounding boxes are drawn on screen during recording anymore — only the instruction text/dot-progress bar. `videoRotationAngle = 90` is set on the video-data connection to pre-rotate buffers to portrait, so `LiveObjectDetector` must be called with Vision orientation `.up` (an earlier bug used `.right` here too — double-rotation — likely why AC detection was unreliable in testing; fixed but **not yet verified on-device**, since testing needs a physical iPhone).

2. **Final analysis** (`RealMoldDetectionService`, called from `AnalyzingLoadingView`): samples the *recorded* video every 0.5s via `AVAssetImageGenerator` (`appliesPreferredTrackTransform = true`, so frames are already upright — orientation `.up` is correct here and was never buggy), runs both models per frame, dedupes/caps findings (max 8), and derives `hasWindow`/`hasAC`/`riskScore`. A `Finding.frameImage` is the **actual video frame** where something was detected — this is also what feeds `RoomInspection.thumbnail` / `KosProperty.thumbnail`, so list/detail thumbnails show a real photo containing the detection, not a placeholder, whenever at least one finding exists.

`MockMoldDetectionService` still exists (used only by SwiftUI `#Preview`s) — same protocol, no CoreML dependency, useful for previewing UI without a recorded video.

## Known gaps / things to check next

- **AC live-detection reliability** — user reported it failing to detect their room's AC during a real test; the orientation fix above is a plausible root cause but is unconfirmed (needs on-device retest before assuming the trained model itself needs more data).
- `FindingClass.crack` exists in the type system (and prevention-tip copy references it conditionally) but the real `MoldDamp` model only outputs `mold`/`damp` — cracks are never actually produced by `RealMoldDetectionService`. Either retrain to include a crack class, or treat `.crack` as vestigial.
- Confidence thresholds are hardcoded per detector: `WindowAC` 0.4, `MoldDamp` 0.35 (`RealMoldDetectionService.swift` / `CameraService.swift`'s `SessionController`) — untuned, first-guess values.
- No persistence — reinstall/relaunch wipes everything back to the 5 dummy seed properties.
- Live camera + real-time detection can only be tested on a physical device — the Simulator has no camera, and per user preference this project verifies via `xcodebuild ... build` only, never the Simulator app.
- "Mode Pantau" (30-day before/after photo comparison + weather-based notifications) was explicitly out of scope in the original spec and was never started.

## Build

```bash
xcodebuild -project HoMoold.xcodeproj -scheme HoMoold -destination 'generic/platform=iOS Simulator' -configuration Debug build
```
This currently succeeds cleanly. Camera/location/CoreML features need a real device + `DEVELOPMENT_TEAM` signing (already set to `25HCRL7VJ3` in project settings) to actually exercise at runtime.
