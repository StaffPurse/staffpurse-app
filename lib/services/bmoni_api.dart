import 'dart:convert';
import 'package:http/http.dart' as http;
import '../env.dart';

class BmoniApi {
  static final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'x-api-key': Env.bmoniApiKey,
  };

  /// Creates a user in BMONI and initiates the NGN onboarding/KYC flow.
  /// Returns the newly created user ID.
  static Future<String> createUserAndKyc({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String dateOfBirth,
    required String bvn,
  }) async {
    final url = Uri.parse('${Env.bmoniBaseUrl}/users');
    
    final createUserPayload = {
      "firstName": firstName,
      "lastName": lastName,
      "email": "${firstName.toLowerCase()}.${lastName.toLowerCase()}@staffpurse.local",
      "phoneNumber": phoneNumber,
    };

    final userResponse = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(createUserPayload),
    );

    if (userResponse.statusCode < 200 || userResponse.statusCode >= 300) {
      throw Exception('Failed to create BMONI user: ${userResponse.body}');
    }

    final userData = jsonDecode(userResponse.body);
    final userId = userData['id'] as String;

    // 2. Submit KYC data
    final kycUrl = Uri.parse('${Env.bmoniBaseUrl}/users/$userId/kyc/activate');
    final kycPayload = {
      "dateOfBirth": dateOfBirth,
      "address": {
        "streetLine1": "1 Hackathon Way",
        "city": "Lagos",
        "state": "Lagos",
        "postalCode": "100001",
        "countryCode": "NGA"
      },
      "identificationNumbers": {
        "bvn": bvn
      }
    };

    final kycResponse = await http.post(
      kycUrl,
      headers: _headers,
      body: jsonEncode(kycPayload),
    );

    if (kycResponse.statusCode < 200 || kycResponse.statusCode >= 300) {
      throw Exception('Failed to activate KYC: ${kycResponse.body}');
    }

    return userId;
  }

  /// Create a card and get the proposal ID and payload to sign.
  static Future<Map<String, dynamic>> createCard({
    required String userId,
    required String smartWalletId,
    required String cardName,
    required String nin,
  }) async {
    final url = Uri.parse('${Env.bmoniBaseUrl}/users/$userId/cards');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        "cardName": cardName,
        "cardColor": "#4285F4",
        "currency": "NGN",
        "type": "virtual",
        "smartWalletId": smartWalletId,
        "nin": nin, // Required on first card
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create card: ${response.body}');
    }
  }

  /// Polls for the sign-payload until it is ready.
  static Future<String> pollSignPayload({
    required String userId,
    required String proposalId,
  }) async {
    final url = Uri.parse('${Env.bmoniBaseUrl}/users/$userId/smart-wallets/proposals/$proposalId/sign-payload');
    
    // Simple polling loop
    while (true) {
      final response = await http.get(url, headers: _headers);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['signPayload'] as String;
      } else if (response.statusCode == 409) {
        // 409 means "not ready, keep polling"
        await Future.delayed(const Duration(seconds: 2));
      } else {
        throw Exception('Failed to poll sign-payload: ${response.body}');
      }
    }
  }

  /// Submit the signed proposal to finalize card creation.
  static Future<Map<String, dynamic>> submitSignature({
    required String userId,
    required String proposalId,
    required String signature,
  }) async {
    final url = Uri.parse('${Env.bmoniBaseUrl}/users/$userId/smart-wallets/proposals/$proposalId/sign');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        "signature": signature,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to submit signature: ${response.body}');
    }
  }

  /// Get the spending limits caps on the card from the provider.
  static Future<Map<String, dynamic>> getCardLimits({
    required String userId,
    required String cardId,
  }) async {
    final url = Uri.parse('${Env.bmoniBaseUrl}/users/$userId/cards/$cardId/limits');
    final response = await http.get(
      url,
      headers: _headers,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get limits: ${response.body}');
    }
  }

  /// Set the spending limits on the card.
  static Future<void> setCardLimits({
    required String userId,
    required String cardId,
    required double dailyLimit,
    required double transactionLimit,
  }) async {
    final url = Uri.parse('${Env.bmoniBaseUrl}/users/$userId/cards/$cardId/set-limit');
    final response = await http.put(
      url,
      headers: _headers,
      body: jsonEncode({
        "totalDailyLimit": dailyLimit,
        "maxSingleTransactionAmount": transactionLimit,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to set limits: ${response.body}');
    }
  }

  /// Get a single card to read its live status.
  static Future<Map<String, dynamic>> getCard({
    required String userId,
    required String cardId,
  }) async {
    final url = Uri.parse('${Env.bmoniBaseUrl}/users/$userId/cards/$cardId');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get card: ${response.body}');
    }
  }

  /// Update the status of a card (e.g. BLOCKED or ACTIVE).
  static Future<void> updateCardStatus({
    required String userId,
    required String cardId,
    required String status,
  }) async {
    final url = Uri.parse('${Env.bmoniBaseUrl}/users/$userId/cards/$cardId/status');
    final response = await http.put(
      url,
      headers: _headers,
      body: jsonEncode({"status": status}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Status transition failed: ${response.body}');
    }
  }

  /// Fetch the transaction feed for a card.
  static Future<List<dynamic>> getCardTransactions({
    required String userId,
    required String cardId,
  }) async {
    final url = Uri.parse('${Env.bmoniBaseUrl}/users/$userId/cards/$cardId/transactions');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      if (data is List) return data;
      if (data['data'] is List) return data['data'];
      return [data]; 
    } else {
      throw Exception('Failed to fetch transactions: ${response.body}');
    }
  }
}


