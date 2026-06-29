# Verification

The ChatGPT sandbox used to create this ZIP does not include Flutter/Dart, so `flutter analyze` and `flutter test` could not be executed here.

Run locally:

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter run -d android
```

Expected result:

- Analyzer should be clean.
- Unit tests should pass.
- Android layout should scroll without bottom overflow.
- Windows Project page should use a table for the project list, and Material/Labor/Machinery pages should remain scrollable without overflow.


Phase 5 adds Billing/GST/Estimate/Profit-Loss. Run `flutter analyze` and `flutter test` locally because Flutter is not installed in this sandbox.
