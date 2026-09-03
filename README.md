# StaffPurse

> Spend control for Nigeria's informal micro-businesses — issue capped virtual cards to staff, freeze instantly, see spend live. 
> Built on **BMONI** for the "Hack the Future" Hackathon.

StaffPurse allows business owners to instantly issue secure virtual spend cards to their staff without the friction of formal business registration or complex multi-tier banking approvals. 

By leveraging the BMONI Embedded SDK and Smart Wallets, StaffPurse owners retain complete self-custody of their main balance while instantly delegating capped NGN spending power to their team.

---

## 🛠 Tech Stack

- **Frontend:** Flutter (Mobile only, enforced by hardware keystore requirements)
- **State Management:** Riverpod
- **Backend / Database:** Supabase (PostgreSQL)
- **Infrastructure / Finance:** 
  - `bmoni_embedded_sdk` (Hardware secure enclave Keystore & EIP-191 signing)
  - `bmoni_embedded_wallets_cards` (Card Widgets)
  - `bkey_uikit` (BMONI Design System & Typography)

---

## 🚀 Getting Started

Because StaffPurse relies on the BMONI Embedded SDK which interacts directly with the **Android Keystore** and **iOS Secure Enclave**, this application **cannot be run on Web or Desktop**. You must run it on a physical device or a mobile emulator.

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.13+)
- Android Studio (for the Android Emulator) or Xcode
- A [Supabase](https://supabase.com/) Project
- A BMONI Sandbox API Key

### 2. Environment Setup
Create or update `lib/env.dart` with your Sandbox and Database keys:
```dart
class Env {
  static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
  static const String supabaseAnonKey = 'eyJ...';
  static const String bmoniBaseUrl = 'https://embedded-dev.bmoni.com/v1';
  static const String bmoniApiKey = 'pk_...'; 
}
```

### 3. Database Schema
Push the Supabase schema directly to your live project:
```bash
supabase db push
```
*(This sets up the `business`, `staff_member`, `card_assignment`, and `transaction_cache` tables).*

### 4. Run the App
Connect your Android Emulator or iOS Simulator, then:
```bash
flutter pub get
flutter run
```

---

## 🧪 Demo Pre-warm Script

To avoid live-demo friction, you can "pre-warm" the sandbox environment with a mock business and staff members before stepping on stage.

```bash
# Export your keys
export SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
export SUPABASE_KEY="eyJ..."
export BMONI_API_KEY="pk_..."

# Run the Dart pre-warm script
dart run scripts/prewarm_sandbox.dart
```

**Note on Cryptography:** 
The pre-warm script sets up the BMONI user and Supabase database relationships. However, **it cannot issue the virtual cards**. BMONI card issuance proposals *must* be signed by the smart wallet's secp256k1 private key, which is locked safely inside your mobile device's Secure Enclave. To finish the pre-warm, open the Flutter app on your emulator and tap **"Issue Card"**!

---

## 🏗 Architecture Reference
- Read [ARCHITECTURE.md](ARCHITECTURE.md) for data flow and structural decisions.
- Read [PRD.md](PRD.md) for product scope and target demographics.
