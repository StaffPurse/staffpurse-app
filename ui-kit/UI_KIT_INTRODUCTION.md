> ## Documentation Index
> Fetch the complete documentation index at: https://bkey.mintlify.site/llms.txt
> Use this file to discover all available pages before exploring further.

# Introduction

> bkey_uikit — BMONI design system for Flutter.

`bkey_uikit` is the shared Flutter component library for all Bkey products. It ships the **BMONI design system**: colour tokens, a complete type scale, a `ThemeData` factory, and every UI primitive used across the product suite.

The package has **no dependency** on any app's business logic, state management, routing, or localisation framework. Import it, apply the theme, and use the components.

***

## What's included

| Layer             | Contents                                                                                                                                                  |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Design tokens** | `BMoniColors` — full colour palette + semantic light/dark tokens                                                                                          |
|                   | `BMoniTextStyles` — display, heading, body, and label type scale                                                                                          |
|                   | `BMoniTheme` — Flutter `ThemeData` factory + `TextTheme` wiring                                                                                           |
| **Fonts**         | *Rethink Sans* (weights 400–800, regular + italic) bundled in `assets/fonts/`                                                                             |
| **Wallet assets** | Background art for USD / NGN / EUR / GBP / CAD / MXN / consolidated, 6 colour variants per currency, and shared SVG icons                                 |
| **Components**    | Buttons, text fields, text area, file upload, avatars, layout cards, app bar, bottom sheets, selectors, toasts, empty/failure/loading states, wallet card |

***

## Single barrel import

Everything is exported from one file:

```dart theme={null}
import 'package:bkey_uikit/bkey_uikit.dart';
```

***

## Links

* [pub.dev package page](https://pub.dev/packages/bkey_uikit)
* [GitHub repository](https://github.com/bkey-inc/bkey_uikit)
* Next: [Installation](/uikit/installation)
