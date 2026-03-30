# Regulit Flutter App

GRC SaaS for Israeli Privacy Law Compliance (Amendment 13).

## Project Structure

```
lib/
├── main.dart                         # App entry point
├── app/
│   ├── router.dart                   # GoRouter + role-based guards
│   └── theme.dart                    # AppColors, AppTextStyles, AppSpacing
│
├── core/
│   ├── api/api_client.dart           # Dio + JWT interceptor + refresh logic
│   ├── auth/auth_provider.dart       # Riverpod auth state (login/logout/SSO)
│   └── models/
│       ├── user.dart                 # AppUser, UserRole
│       ├── gap.dart                  # Gap, GapSummary, GapSeverity, GapCategory
│       └── task.dart                 # Task, Evidence, TaskStatus
│
├── features/
│   ├── auth/login_screen.dart        # Login + Microsoft SSO
│   ├── dashboard/                    # CEO Executive Dashboard
│   │   ├── executive_dashboard_screen.dart
│   │   └── widgets/risk_meter_widget.dart
│   ├── tasks/task_board_screen.dart  # IT Kanban board (web) + list (mobile)
│   ├── portfolio/portfolio_screen.dart # CSM all-client view
│   ├── gaps/gap_analysis_screen.dart  # Gap table + financial exposure
│   ├── classifier/classifier_wizard_screen.dart  # Onboarding questionnaire
│   ├── audit_pack/audit_pack_screen.dart         # Audit readiness + download
│   ├── evidence/evidence_queue_screen.dart       # Analyst review queue
│   └── ai_chat/ai_chat_screen.dart               # AI risk assistant (Claude)
│
└── shared/
    ├── widgets/
    │   ├── app_shell.dart            # Responsive nav (Rail web / BottomNav mobile)
    │   ├── metric_card.dart          # Reusable KPI card (currency, percent, count)
    │   └── status_badge.dart         # Status pills for gaps/tasks/severity
    └── utils/
        └── currency_formatter.dart   # ₪ NIS formatting (full, compact, change)
```

## Setup

```bash
# Install Flutter (>= 3.19)
flutter pub get

# Generate code (Freezed, Riverpod, Retrofit, Hive)
dart run build_runner build --delete-conflicting-outputs

# Run on web (primary target)
flutter run -d chrome --dart-define=API_BASE_URL=https://api.regulit.io/api

# Run on iOS
flutter run -d ios

# Run on Android
flutter run -d android
```

## Fonts

Download the **Heebo** font family from Google Fonts and place the `.ttf` files in `assets/fonts/`:
- `Heebo-Regular.ttf`
- `Heebo-Medium.ttf`
- `Heebo-SemiBold.ttf`
- `Heebo-Bold.ttf`
- `Heebo-ExtraBold.ttf`

## Code Generation

This project uses `build_runner` for:
- **Freezed** — immutable data models with `copyWith`, `==`, `fromJson`
- **Riverpod Generator** — `@riverpod` annotation processing
- **Retrofit** — type-safe HTTP client
- **Hive Generator** — local storage type adapters

Run after any model changes:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `API_BASE_URL` | `https://api.regulit.io/api` | Backend API base URL |

Pass at build time: `--dart-define=API_BASE_URL=https://staging.regulit.io/api`

## Role-based Navigation

| Role | Home screen | Access |
|------|-------------|--------|
| `regulit_admin` / `csm` / `analyst` | Portfolio | All `/admin/*` routes |
| `client_admin` | Executive Dashboard | Dashboard, Audit Pack, AI Chat |
| `it_executor` | Task Board | Tasks, Documents |
| `employee` | Task Board | Tasks (Phase 2: Training) |

## Phase 2 Features (not yet implemented)

- `features/training/` — Employee micro-video courses + quiz engine
- `features/phishing/` — Phishing simulation campaign management
- Policy Signer (digital e-signature for procedures)
- Regulatory Update Monitor (auto-detect new IL privacy law changes)
- Integration Hub (Monday.com / Jira bi-directional sync)

## Tech Stack

| Layer | Package |
|-------|---------|
| State | `flutter_riverpod` + `riverpod_annotation` |
| Routing | `go_router` |
| HTTP | `dio` + `retrofit` |
| Storage | `hive_flutter` + `flutter_secure_storage` |
| Charts | `fl_chart` + `syncfusion_flutter_gauges` |
| Forms | `flutter_form_builder` |
| PDF | `pdf` + `printing` |
| i18n | `flutter_localizations` + `intl` |
| Animations | `flutter_animate` |
| Files | `file_picker` |
