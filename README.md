# FinAI Studio

FinAI Studio is an enterprise-grade AI financial and accounting platform built with Flutter and a feature-first Clean Architecture.

## Architecture

- `lib/config/` — environment selection, routing, design tokens, and the light/dark theme engine.
- `lib/core/` — framework-independent failures, use-case contracts, networking, and utilities.
- `lib/features/` — vertical feature modules (`auth`, `document_ocr`, `tax_copilot`, `reconciliation`, and `analytics`). Each feature is prepared for `data`, `domain`, and `presentation` layers.
- `lib/shared/` — reusable widgets shared by more than one feature, including the responsive desktop application shell.
- `lib/injection_container.dart` — explicit GetIt registrations and environment-aware infrastructure setup.
- `window_manager` — desktop window sizing, custom title bar behavior, native controls, and lifecycle hooks.

## Run

```bash
flutter pub get
flutter run -d windows
```

The Windows desktop target starts at 1280×800, enforces a 1100×700 minimum, and uses the custom shell title bar. Development is the default environment. Select production configuration at build time with:

```bash
flutter run --dart-define=APP_ENV=production
```

The project enables strict analyzer inference, casts, and raw-type checks in `analysis_options.yaml`.
