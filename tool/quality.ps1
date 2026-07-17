$ErrorActionPreference = 'Stop'

flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test

Write-Host 'Qualité Base0 validée.'

