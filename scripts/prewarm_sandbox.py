import os
import requests
from supabase import create_client, Client
import json

# --- CONFIGURATION ---
# Export these in your terminal before running:
# export SUPABASE_URL="https://..."
# export SUPABASE_KEY="eyJ..."
# export BMONI_API_KEY="pk_..."

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")
BMONI_API_KEY = os.environ.get("BMONI_API_KEY")
BMONI_BASE_URL = "https://embedded-dev.bmoni.com/v1"

if not all([SUPABASE_URL, SUPABASE_KEY, BMONI_API_KEY]):
    print("Error: Missing environment variables. Please set SUPABASE_URL, SUPABASE_KEY, and BMONI_API_KEY.")
    exit(1)

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
headers = {
    "Content-Type": "application/json",
    "x-api-key": BMONI_API_KEY
}

def prewarm():
    print("🚀 Starting Sandbox Pre-warm...")

    # 1. Create Demo User
    print("\n1. Creating Demo Owner in BMONI...")
    user_payload = {
        "firstName": "Demo",
        "lastName": "Owner",
        "phoneNumber": "+2348000000000",
        "dateOfBirth": "1990-01-01",
        "address": {
            "streetLine1": "1 Hackathon Way",
            "city": "Lagos",
            "state": "Lagos",
            "postalCode": "100001",
            "countryCode": "NGA"
        },
        "identificationNumbers": {
            "bvn": "12345678901"
        }
    }
    res = requests.post(f"{BMONI_BASE_URL}/users", headers=headers, json=user_payload)
    res.raise_for_status()
    user_id = res.json()["id"]
    print(f"✅ BMONI User Created: {user_id}")

    # Note on Wallet & Cards:
    # Because BMONI's SDK generates the secp256k1 private key inside the mobile device's 
    # hardware Keystore/Secure Enclave, we cannot provision a smart wallet or sign card 
    # issuance proposals purely from a Python script without access to that hardware key.
    
    print("\n⚠️  CRYPTOGRAPHIC CONSTRAINT:")
    print("BMONI's architecture locks the wallet private key in your mobile device's Secure Enclave.")
    print("A server-side script cannot forge the signature required to issue cards (EIP-191).")
    print("To fully pre-warm the cards, you must execute the issuance flow on the emulator.")

    # 2. Setup Database Stubs
    print("\n2. Seeding Supabase database...")
    
    # We create a dummy wallet ID so the database is populated, but the app will overwrite 
    # this when you run it and actually initialize the hardware wallet.
    business_res = supabase.table("business").insert({
        "owner_bmoni_user_id": user_id,
        "owner_wallet_id": "PENDING_DEVICE_PROVISIONING",
        "name": "Acme Demo Corp"
    }).execute()
    business_id = business_res.data[0]["id"]
    print(f"✅ Business Created (ID: {business_id})")

    # Insert Staff
    staff1 = supabase.table("staff_member").insert({
        "business_id": business_id,
        "name": "Alice Developer",
        "phone_number": "+2348000000001"
    }).execute()
    
    staff2 = supabase.table("staff_member").insert({
        "business_id": business_id,
        "name": "Bob Designer",
        "phone_number": "+2348000000002"
    }).execute()

    print(f"✅ Staff Created: {staff1.data[0]['name']}, {staff2.data[0]['name']}")
    
    print("\n🎉 Pre-warm partial success!")
    print("Next step: Open the Flutter app on your emulator to provision the wallet and issue the cards for Alice and Bob.")

if __name__ == "__main__":
    prewarm()
