> ## Documentation Index
> Fetch the complete documentation index at: https://bkey.mintlify.site/llms.txt
> Use this file to discover all available pages before exploring further.

# Installation & setup

> Add bkey_uikit to your Flutter project and apply the BMONI theme.

## Add the dependency

```yaml pubspec.yaml theme={null}
dependencies:
  bkey_uikit: ^0.0.1
```

```bash theme={null}
flutter pub get
```

***

## Apply the theme

Wrap your `MaterialApp` with `BMoniTheme.darkTheme()` (or `lightTheme()`) to inject the full design system — colours, typography, and component defaults — into the widget tree.

```dart theme={null}
import 'package:bkey_uikit/bkey_uikit.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(
    MaterialApp(
      theme: BMoniTheme.darkTheme(),
      home: const MyHomePage(),
    ),
  );
}
```

Both `darkTheme()` and `lightTheme()` return a fully configured `ThemeData`. You can pass the same value to `MaterialApp.darkTheme` / `MaterialApp.theme` to support system-level dark mode automatically:

```dart theme={null}
MaterialApp(
  theme: BMoniTheme.lightTheme(),
  darkTheme: BMoniTheme.darkTheme(),
  themeMode: ThemeMode.system,
  // ...
)
```

***

## Font registration

The *Rethink Sans* font is bundled inside the package. No extra `pubspec.yaml` `fonts:` block is needed in your app — Flutter's pub package font injection takes care of it automatically.

***

## Import

All tokens, enums, and components are exported from a single barrel:

```dart theme={null}
import 'package:bkey_uikit/bkey_uikit.dart';
```

***

## Run the example

A full component gallery is in the `example/` directory:

```bash theme={null}
cd example
flutter pub get
flutter run
```

The gallery groups every widget by category and is themed with `BMoniTheme.darkTheme()`.
