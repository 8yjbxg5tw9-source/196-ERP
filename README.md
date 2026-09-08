# FinAI Studio

FinAI Studio is an enterprise-grade AI financial and accounting platform built with Flutter and a feature-first Clean Architecture.

## Architecture

- `lib/config/` — environment selection, routing, design tokens, and the light/dark theme engine.
- `lib/core/` — framework-independent failures, use-case contracts, networking, utilities, SQLite schema/migrations, and secure storage.
- `lib/features/` — vertical feature modules (`auth`, `document_ocr`, `tax_copilot`, `reconciliation`, and `analytics`). Each feature is prepared for `data`, `domain`, and `presentation` layers.
- `lib/shared/` — reusable widgets shared by more than one feature, including the responsive desktop application shell.
- `lib/injection_container.dart` — explicit GetIt registrations, environment-aware infrastructure, database initialization, and secure storage setup.
- `lib/core/database/` — versioned offline-first SQLite service and relational schema for companies, documents, transactions, tax rules, and audit logs.
- `lib/core/storage/` — platform-backed encrypted key-value storage for tokens, AI keys, and database key material.
- `lib/core/network/` — connectivity-gated Dio client with secure auth headers, masked debug logging, exponential retries, and normalized domain failures.
- `lib/features/company/` — multi-company domain contracts, SQLite repository, secure active-company context, BLoC state engine, and desktop selector form.
- `lib/features/document_ocr/` — multi-format file ingestion, local document storage, OCR adapters, structured invoice models, and SQLite repository processing states.
- `lib/core/services/ocr_service.dart` — offline mock OCR parser plus an HTTP OCR/Vision/PaddleOCR gateway abstraction.
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

## Document ingestion and OCR

The dashboard accepts PDF, PNG, JPG, and JPEG files through `desktop_drop`, with a `file_picker` fallback. Imports require an active company and are processed in the following order:

1. Copy the source into the platform application-support directory under `documents/<sanitized-company-id>/`.
2. Persist a SQLite `pending` record, then update it to `processing` before OCR starts.
3. Save the normalized vendor, VÖEN/TIN, invoice number, dates, totals, currency, line items, positioned OCR lines, and raw OCR payload as `completed` JSON/SQLite data. Errors retain the source and persist a `failed` status when possible.

`MockOcrService` is the deterministic offline default for development. `HttpOcrService` can be registered in its place for a hosted OCR, Vision, or PaddleOCR endpoint. Document files are company-scoped and deletion only removes paths inside the managed application-support document directory.
