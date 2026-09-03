# Hackathon Demo Checklist (Sept 4, 12pm)

The codebase is officially 100% complete. This list is purely for demo rehearsal and stage preparation.

## 1. Sandbox Preparation
- [ ] **Locate the Mock Funding switch:** Identify how to fund the BMONI sandbox wallet (either via the BMONI Developer Portal dashboard or the `/ngn-rails` sandbox endpoint).
- [ ] **Simulate a Spend:** Verify how to trigger a mock transaction against the issued virtual card from the BMONI sandbox dashboard so you can show the transaction feed updating in real-time.

## 2. Pre-Presentation Setup (T-Minus 15 Minutes)
- [ ] **Pre-warm the database:** Run `dart run scripts/prewarm_sandbox.dart` from the terminal to seed the business and staff members.
- [ ] **Launch the App:** Run `flutter run` on an Android Emulator or iOS Simulator. 
- [ ] **Initialize the Keystore:** Click through the app to ensure the BMONI SDK provisions the hardware wallet on that specific emulator.

## 3. The Live Stage Script ("The Golden Path")
When presenting to the judges, follow this exact flow:
1. **Show the Dashboard:** Point out the main business wallet balance (Self-Custodied).
2. **Issue a Card:** Tap "Add Staff Member" to provision a card for a staff member. Explain that this relies on an EIP-191 signature signed by the device's Secure Enclave.
3. **Set Limits:** Navigate to the card management screen and set a Daily Limit.
4. **Simulate a Spend:** (Trigger the mock BMONI transaction on your laptop). Watch the transaction feed update in the app.
5. **Freeze the Card:** Tap the "Freeze Card" button to demonstrate the optimistic UI, haptic feedback, and instant state control the owner has over staff spending.
6. **The Pitch:** Explicitly name Bujeti and Prospa. Explain why StaffPurse targets the informal micro-business segment that those larger platforms are structurally not built to serve.
