# Orbit

Orbit is a Flutter app that tracks every VIT placement drive — registrations, PPTs, shortlists, and OAs — so nothing gets missed. Students get a single feed of the companies coming to campus, with the detail and deadlines for each drive in one place instead of scattered across notice boards, spreadsheets, and group chats. An admin surface for managing drives is planned behind a role gate.

## Project status

This is the initial scaffold: project structure, a routing skeleton with placeholder screens, and a Material 3 theme. There is no backend, authentication, or networking yet.

## Folder structure

```
lib/
├── core/           theme, routing, shared widgets, constants
├── features/
│   ├── auth/       splash and login
│   ├── companies/  student-facing drive list and detail
│   └── admin/      placeholder, role-gated later
├── models/         data models
├── services/       Firebase and API clients
└── main.dart
```

## Routes

| Path                     | Screen         |
| ------------------------ | -------------- |
| `/`                      | Splash         |
| `/login`                 | Login          |
| `/companies`             | Company list   |
| `/companies/:companyId`  | Company detail |
| `/admin`                 | Admin          |

## Getting started

Requires the Flutter SDK on the stable channel.

```bash
flutter pub get
flutter run
```

Targets Android and iOS. Web support is planned for the admin dashboard only.
