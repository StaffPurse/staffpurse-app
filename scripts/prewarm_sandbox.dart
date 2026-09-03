import 'dart:io';
import 'package:supabase/supabase.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// --- CONFIGURATION ---
// Set these in your terminal before running:
// export SUPABASE_URL="https://..."
// export SUPABASE_KEY="eyJ..."
// export BMONI_API_KEY="pk_..."

void main() async {
  print("🚀 Starting Sandbox Pre-warm...");

  final supabaseUrl = Platform.environment['SUPABASE_URL'];
  final supabaseKey = Platform.environment['SUPABASE_KEY'];
  final bmoniApiKey = Platform.environment['BMONI_API_KEY'];

  if (supabaseUrl == null || supabaseKey == null || bmoniApiKey == null) {
    print("Error: Missing environment variables. Please set SUPABASE_URL, SUPABASE_KEY, and BMONI_API_KEY.");
    exit(1);
  }

  final supabase = SupabaseClient(supabaseUrl, supabaseKey);
  const bmoniBaseUrl = "https://embedded-dev.bmoni.com/v1";
  final headers = {
    "Content-Type": "application/json",
    "x-api-key": bmoniApiKey,
  };

  try {
    // 1. Create Demo User
    print("\n1. Creating Demo Owner in BMONI...");
    final userPayload = {
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
    };

    final userRes = await http.post(
      Uri.parse('$bmoniBaseUrl/users'),
      headers: headers,
      body: jsonEncode(userPayload),
    );

    if (userRes.statusCode >= 300) {
      throw Exception("Failed to create BMONI user: ${userRes.body}");
    }

    final userId = jsonDecode(userRes.body)['id'];
    print("✅ BMONI User Created: $userId");

    print("\n⚠️  CRYPTOGRAPHIC CONSTRAINT:");
    print("BMONI's architecture locks the wallet private key in your mobile device's Secure Enclave.");
    print("A server-side script cannot forge the signature required to issue cards (EIP-191).");
    print("To fully issue the cards, you must execute the issuance flow on the emulator/device.");

    // 2. Setup Database Stubs
    print("\n2. Seeding Supabase database...");
    
    final businessRes = await supabase.from('business').insert({
      "owner_bmoni_user_id": userId,
      "owner_wallet_id": "PENDING_DEVICE_PROVISIONING",
      "name": "Acme Demo Corp"
    }).select().single();
    
    final businessId = businessRes['id'];
    print("✅ Business Created (ID: $businessId)");

    final staff1 = await supabase.from('staff_member').insert({
      "business_id": businessId,
      "name": "Alice Developer",
      "phone_number": "+2348000000001"
    }).select().single();
    
    final staff2 = await supabase.from('staff_member').insert({
      "business_id": businessId,
      "name": "Bob Designer",
      "phone_number": "+2348000000002"
    }).select().single();

    print("✅ Staff Created: ${staff1['name']}, ${staff2['name']}");
    
    print("\n🎉 Pre-warm partial success!");
    print("Next step: Open the Flutter app on your emulator to provision the wallet and issue the cards for Alice and Bob.");

  } catch (e) {
    print("Error during pre-warm: $e");
  }
}
