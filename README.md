# HoMoold — Indoor Mold Detection

HoMoold is an iOS app that helps **second-hand property seekers (buyers)**
inspect a house or room for indoor mold and produce a clear **mold-growth risk report**
they can use as a negotiation or red-flag signal before committing to a purchase.

It is deliberately **not** a DIY remediation tool. The reports are framed for decision-making
("ask the seller/landlord to remediate", "walk away", "red flag") — never as occupant
cleanup advice.

The app combines three on-device capabilities:

1. **On-device mold detection** — a Core ML segmentation model runs live over the camera
   feed and draws bounding boxes + pixel masks on detected mold.
2. **LiDAR area measurement** — on LiDAR-equipped iPhones, the real-world surface area of
   each mold patch is measured in cm² using scene depth + camera intrinsics.
3. **A growth-risk classifier** — a tabular Core ML model fuses weather, room conditions,
   and the detected mold severity into a Low / Medium / High growth-risk class with a
   confidence score.

Everything runs **100% on-device**. There is no backend, no account, and no network call
except an optional, key-free weather lookup.

---

## Table of Contents

- [Who it's for](#who-its-for)
- [What it does (user flow)](#what-it-does-user-flow)
- [Key features](#key-features)
- [Architecture](#architecture)
- [The ML pipeline](#the-ml-pipeline)
- [Project structure](#project-structure)
- [Models & sources](#models--sources)
- [Tech stack](#tech-stack)
- [Requirements](#requirements)
- [Building & running](#building--running)
- [Persistence & privacy](#persistence--privacy)
- [Notable engineering decisions](#notable-engineering-decisions)
- [Known limitations](#known-limitations)
- [License](#license)

---

## Who it's for

- **Buyers** evaluating a pre-owned home, apartment, or room.
- People who want an **objective, documented** signal about mold risk to support
  due-diligence and negotiation — not a weather app, not a remediation guide.

The report copy is written for a **decision/negotiation** audience: it surfaces red flags
and recommends asking the seller/landlord to remediate, or walking away. It never instructs
the occupant to clean the mold themselves.

---

## What it does (user flow)

The app opens to a property list. (First launch shows an onboarding screen once.)

```
RootView
  └─ HomeListView            (list of properties you've added)
       └─ PropertyDetailView (rooms inspected for that property)
            └─ InspectionFlowView  (NavigationStack, per-room inspection)
                 ├─ ConditionFormView     collect room conditions + location/weather
                 ├─ GuidanceView          how to position the phone / what mold looks like
                 ├─ CaptureView           LIVE camera + LiDAR mold detection
                 ├─ AnalyzingLoadingView  runs the risk classifier
                 └─ ReportView            findings + risk class + confidence → Save
```

**Capture flow (the core experience):**

- **Scanning** — live camera, no overlay. The model runs every ~0.4s in the background,
  but only to drive a red/green indicator and guidance text ("too close", "too far",
  "hold steady").
- **Stabilizing** — once mold is detected *and* it's within LiDAR range, a short
  countdown holds so the user can steady the camera.
- **Ready** — indicator turns green; the user taps the capture button (capture is
  **manual**, by design).
- **Preview** — the frame is frozen, full detection (with masks) + area is computed, and
  bounding boxes + area numbers are drawn over the photo. The user can **Retake** (discard),
  **Another mold spot** (accept + scan again), or **Done** (accept + close).
- Accepted findings flow into the report, which is saved locally against the property/room.

---

## Key features

- **Live mold detection** with bounding boxes and pixel-precise segmentation masks.
- **Real-world area measurement** (cm²) via LiDAR depth — optional; the app still works
  on non-LiDAR iPhones, it just can't measure area.
- **Mold severity level (0–3)** derived from total detected area.
- **Growth-risk classification**: Low / Medium / High, with a confidence distribution
  across all three classes.
- **Room condition inputs**: AC present, window present, visible dampness, wall cracks —
  these are model inputs, not decoration.
- **Location + weather**: outdoor temperature and humidity are fetched (key-free) and fed
  into the risk model.
- **Local-first storage**: all properties, rooms, findings, and photos live in one JSON
  file on the device. No account, no server.
- **Graceful degradation**: if a model fails to load or weather can't be fetched, the UI
  degrades explicitly (labeled estimate / "unavailable") instead of crashing.

---

## Architecture

HoMoold is a **SwiftUI MVVM** app.

- **Single source of truth** — `AppDataStore` (`Data/AppDataStore.swift`) is an
  `@ObservableObject` holding `[KosProperty]`. It owns persistence (auto-load on init,
  auto-save on any mutation) and the risk recomputation logic.
- **One ViewModel per screen** — every major screen has a paired `*ViewModel`
  (`ObservableObject`) that feeds a `*View`.
- **Shared store flows down** from `RootView` into Home / Inspection / Report.
- **Services are stateless wrappers** around device APIs and Core ML models.

Data flow for one inspection:

```
Camera/LiDAR frame
  → upright CGImage                       (FrameImageRenderer)
  → MoldDetector                          (boxes + masks, manual NMS, CPU-only)
  → ARAreaCalculator                      (cm² via scene depth + intrinsics)
  → ConditionForm inputs (AC/window/damp/crack)
  + WeatherService (outdoor temp/humidity)
  → RiskClassifierService                 (Low/Medium/High + confidence)
  → ReportView
  → saved into AppDataStore               (local JSON)
```

---

## The ML pipeline

### 1. Mold detection — `MoldDetector` (`Services/MoldDetector.swift`)

Wraps a Core ML model (currently the **single-class "Mold" segmentation** model,
`AI/Mold.mlpackage`) via **Vision**. It is intentionally tolerant of different export
shapes:

- Number of classes and input size are **read from the tensor shape at runtime**, not
  hardcoded — so swapping the bundled model does not require code changes.
- Supports both **detect-only** (box) and **segment** (box + 32-coefficient mask proto)
  Ultralytics exports.
- Non-Max Suppression and box decoding are done **manually** (the export ships without an
  NMS pipeline).
- Detection runs on an **upright `CGImage`** rendered from the ARKit frame
  (`CIImage.oriented(.right)`, forced **sRGB** color space). This fixed a bug where raw
  pixel-buffer + manual orientation produced model scores ≈ 0 on every anchor.
- **`.cpuOnly` compute units** — the Ultralytics→CoreML exports crash with SIGABRT on
  GPU/ANE, so CPU is forced (safe, slightly slower).
- **`.scaleFill`** (stretch, no letterbox) — `.scaleFit` was tried and broke detection.
- Confidence threshold is **0.40** (below that, grout lines and corner shadows were
  mis-flagged as mold).

Live scanning uses **box-only** detection (cheap); the full **mask** decode is reserved for
capture, where the result is actually drawn and measured.

### 2. Area measurement — `ARAreaCalculator` (`Services/ARAreaCalculator.swift`)

Converts a detected box/mask into a real-world area in cm² using the ARKit scene depth
map, depth confidence map, and camera intrinsics. Falls back to the bounding box when no
LiDAR depth is available.

### 3. Risk classification — `RiskClassifierService` (`Services/RiskClassifierService.swift`)

Wraps `RiskClassifier.mlmodel`, a **Create ML tabular classifier** (decision tree).

| Input             | Meaning                              |
|-------------------|--------------------------------------|
| `T_out`           | Outdoor temperature (°C)             |
| `RH_out`          | Outdoor relative humidity (%)        |
| `AC`              | AC present (0/1)                     |
| `Window`          | Window present (0/1)                 |
| `Dampness`        | Visible dampness (0/1)               |
| `Wall_Crack`      | Wall crack (0/1)                     |
| `Mold`            | Detected mold severity level (0–3)   |

Output: `Risk_Class` ∈ {`Low`, `Medium`, `High`} plus a probability distribution over all
three classes (used for the confidence card).

- Humidity gets a **computed offset**: base +5, plus +5 if no AC, plus +5 if no window —
  a sealed, unconditioned room is assumed more humid so the model receives the right signal.
- Also **`.cpuOnly`** (GPU/ANE SIGABRT risk).
- Runs in `AnalyzingLoadingView` to assemble the report, and again in
  `AppDataStore.recomputeRiskLevel` whenever a room's conditions are edited later.

---

## Project structure

```
HoMoold/
├── HoMooldApp.swift            @main App; UIKit appearance (window tint, nav title), light-mode only
├── RootView.swift              First-launch gate → Onboarding or Home; owns the AppDataStore
├── AI/
│   ├── Mold.mlpackage          Current mold segmentation model (single-class "mold")
│   └── RiskClassifier.mlmodel  Create ML tabular risk classifier
├── Assets.xcassets/            ~35 color sets + images (teal brand palette, icons, samples)
├── Components/Common/          Reusable UI: PillButton, PropertyCard, BoundingBoxOverlay,
│                               MoldDetectionBox, FullScreenImageViewer, PagedCarousel, ...
├── Data/
│   └── AppDataStore.swift      Single source of truth; local JSON persistence; risk recompute
├── Features/
│   ├── Home/                   Property list + detail (HomeListView/ViewModel, PropertyDetail*)
│   ├── Inspection/             Capture → analyze flow (CaptureView/ViewModel, ConditionForm,
│   │                           Guidance, MoldReference, AnalyzingLoading, InspectionFlow)
│   ├── Report/                 ReportView/ViewModel, RiskPredictionDetailSheet, MoldRiskInfoSheet
│   └── Onboarding/             OnboardingView (one-time welcome)
├── Models/                     Data types: KosProperty, RoomInspection, Finding, SegmentationInstance,
│                               LiveDetection + enums (RoomType, MoldSeverity, RiskLevel, ...)
├── Services/                   MoldDetector, RiskClassifierService, ARAreaCalculator,
│                               ARDepthCaptureSession, LocationService, WeatherService
└── Utilities/                  Theme (brand tokens), Typography (fonts), PlaceholderImageFactory
ModelSource/
├── MoldDamp.pt                 Source PyTorch model (2-class detect/segment experiments)
└── MoldDampSeg.pt              Source PyTorch segmentation model
HoMoold.xcodeproj/              Xcode project
```

---

## Models & sources

| Artifact                | Role                                    | Origin |
|-------------------------|-----------------------------------------|--------|
| `AI/Mold.mlpackage`     | Live mold detection + segmentation      | Exported from a PyTorch/YOLO model (Ultralytics) via coremltools |
| `AI/RiskClassifier.mlmodel` | Growth-risk tabular classifier      | Trained in Create ML |
| `ModelSource/MoldDamp.pt`   | PyTorch source (2-class detect/seg) | Training/export source — not used at runtime |
| `ModelSource/MoldDampSeg.pt` | PyTorch source (segmentation)      | Training/export source — not used at runtime |

The PyTorch `.pt` files are the **training/export source**. The iOS app consumes only the
compiled Core ML versions under `AI/`. To swap or improve the detector, retrain/export in
`ModelSource/`, then replace the `.mlpackage` under `AI/` — `MoldDetector` adapts to the
new tensor shape automatically.

---

## Tech stack

- **SwiftUI** (MVVM) — all UI
- **ARKit** — camera frames + LiDAR scene depth (`ARDepthCaptureSession`)
- **Core ML + Vision** — mold detection and risk classification
- **AVFoundation** — camera torch control
- **Core Image / Core Graphics** — upright frame rendering + luminance estimation
- **Combine** — reactive state in view models
- **Foundation** — `JSONEncoder/Decoder` local persistence, `URLSession` weather fetch
- **Open-Meteo** — key-free weather API (no API key required)

---

## Requirements

- **iOS 26.5+** (deployment target set in the Xcode project)
- **Xcode 26.x** with the iOS SDK
- **iPhone** — the app is built around the camera and ARKit. LiDAR (iPhone Pro models)
  enables area measurement; non-LiDAR iPhones still run detection and the risk report,
  just without cm² area.
- A physical device is required to exercise the camera/ARKit/LiDAR paths; the Simulator
  has no torch and no LiDAR.

> Bundle identifier: `com.ginn.HooMold` · Marketing version `1.0`.

---

## Building & running

```bash
# 1. Open the project
open "HoMoold.xcodeproj"

# 2. Select your team + a development provisioning profile
#    (Signing & Capabilities — the bundle id is com.ginn.HooMold)
# 3. Choose your iPhone as the run destination
# 4. Build & run (⌘R)
```

There is no package manager step — dependencies are Apple frameworks only. The Core ML
models are already compiled into the bundle.

To swap the detection model: replace `HoMoold/AI/Mold.mlpackage` with a new
Ultralytics→CoreML export (single- or two-class, detect or segment). No code change needed
as long as the output tensor shape follows the documented convention.

---

## Persistence & privacy

- All data — properties, rooms, findings, photos — is stored in **one JSON file**
  (`properties.json`) in the app's `Application Support` directory, including photos
  encoded as JPEG `Data`.
- Data **persists across launches** (auto-load on store init, auto-save on mutation) and
  **never leaves the device**.
- The only network call is an **optional** weather fetch to Open-Meteo (no API key, no
  identifying payload beyond lat/long). If it fails, the app falls back to a clearly
  **labeled** climate estimate and marks the inspection as weather-estimated.

---

## Notable engineering decisions

These are the non-obvious choices that keep the app correct and crash-free:

- **CPU-only Core ML.** Both models are forced to `.cpuOnly` because the exported graphs
  SIGABRT on GPU/ANE (`MPSGraphExecutable ... MLIR pass manager failed`). Slower, but safe.
- **Upright CGImage path for detection.** Running detection on the raw ARKit pixel buffer
  with manual orientation gave model scores ≈ 0 on every anchor. Rendering to an upright,
  sRGB-forced `CGImage` first (the proven video-path approach) fixed it.
- **Manual NMS + box decode.** The Core ML export ships without an NMS pipeline, so
  non-max suppression and box decoding are implemented in `MoldDetector`.
- **Runtime shape inference.** Class count and input size are read from the tensor, so the
  detector survives model swaps without code edits.
- **Weather estimate is always labeled.** When GPS/API fails, the report uses
  Indonesia-lowland defaults (27 °C / 80% RH) but flags `isWeatherEstimated` and tells the
  user — never silently.
- **Edits recompute risk.** Changing a room's AC/window/damp/crack from the list recomputes
  the risk level in `AppDataStore`, not just in the Report screen.
- **Preview crop to the visible band.** The 4:3 sensor frame is taller than the screen, so
  only the center band is visible; captured frames are cropped to exactly what was on screen
  and boxes are remapped, so off-screen mold is never reported.
- **Luminance via CGContext, not CIAreaAverage.** `CIAreaAverage` + `render(toBitmap:)`
  returns 0.0 here (a Core Image color-management pitfall); a 32×32 CGContext downscale with
  Rec.601 luma is used instead for the low-light warning.
- **Light-mode only**, with UIKit appearance tweaks (window tint, large-title nav color)
  set in `HoMooldApp` because SwiftUI can't color those.

---

## Known limitations

- **Detection quality depends on the bundled model.** Earlier experiments
  (`MoldDamp`, `MoldDampSeg`) scored poorly; the current single-class `Mold` model is the
  best so far. Thresholds (confidence 0.40, stable ticks 5) are tuned to it.
- **Area needs LiDAR.** cm² measurement requires a LiDAR iPhone; otherwise area is omitted.
- **Single light theme.**
- **No backend/sync.** Data is local to one device; there is no multi-device sync or export
  sharing yet (reports live in-app).
- **Weather is a point-in-time snapshot**, not a history — the risk model sees current
  outdoor conditions only.

