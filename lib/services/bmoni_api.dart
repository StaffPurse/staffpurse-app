import 'dart:convert';
import 'package:http/http.dart' as http;
import '../env.dart';

class BmoniApi {
  static Future<Map<String, dynamic>> bvnLookup({
    required String userId,
    required String bvn,
  }) async {
    // The exact verified bvn-lookup endpoint requires the active userId!
    final url = Uri.parse('${Env.bmoniBaseUrl}/users/$userId/kyc/bvn-lookup/$bvn');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('BVN lookup failed: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  static final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'x-api-key': Env.bmoniApiKey,
  };

  /// Safely unwraps nested objects if the BMONI API returns them.
  static dynamic _unwrapData(dynamic responseBody) {
    if (responseBody is Map) {
      if (responseBody.containsKey('data')) return responseBody['data'];
      if (responseBody.containsKey('user')) return responseBody['user'];
      if (responseBody.containsKey('card')) return responseBody['card'];
      if (responseBody.containsKey('proposal')) return responseBody['proposal'];
    }
    return responseBody;
  }

  /// Creates a user in BMONI and initiates the NGN onboarding/KYC flow.
  /// Returns the newly created user ID.
    static Future<String> createUserOnly({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
  }) async {
    final url = Uri.parse('${Env.bmoniBaseUrl}/users');
    
    final createUserPayload = {
      "firstName": firstName,
      "lastName": lastName,
      "email": email,
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

    final userData = _unwrapData(jsonDecode(userResponse.body));
    final userId = (userData['bmoniUserId'] ?? userData['userId'] ?? userData['id']).toString();
    if (userId == 'null' || userId.isEmpty) {
      throw Exception('Could not extract user ID from response: $userData');
    }
    return userId;
  }

  static Future<void> activateKycOnly({
    required String userId,
    required String dateOfBirth,
    required String bvn,
  }) async {
    // 1. PATCH the KYC profile
    final patchUrl = Uri.parse('${Env.bmoniBaseUrl}/users/$userId/kyc');
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

    final patchResponse = await http.patch(
      patchUrl,
      headers: _headers,
      body: jsonEncode(kycPayload),
    );

    if (patchResponse.statusCode < 200 || patchResponse.statusCode >= 300) {
      throw Exception('Failed to PATCH KYC: ${patchResponse.body}');
    }

    // 2. ACTIVATE KYC (Empty body for NGN)
    final activateUrl = Uri.parse('${Env.bmoniBaseUrl}/users/$userId/kyc/activate');
    final activateResponse = await http.post(
      activateUrl,
      headers: _headers,
    );

    if (activateResponse.statusCode < 200 || activateResponse.statusCode >= 300) {
      throw Exception('Failed to activate KYC: ${activateResponse.body}');
    }
  }

    static Future<Map<String, dynamic>> getOwnerProofChallenge({
    required String userId,
    required String userOwnerAddress,
  }) async {
    final url = Uri.parse('${Env.bmoniBaseUrl}/users/$userId/smart-wallets/owner-proof-challenges');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({"currency": "CNGN", "userOwnerAddress": userOwnerAddress}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(jsonDecode(response.body));
    }
    throw Exception('Failed to get challenge: ${response.body}');
  }

  static Future<Map<String, dynamic>> createManagedWallet({
    required String userId,
    required String userOwnerAddress,
    required String challengeId,
    required String signature,
  }) async {
    final url = Uri.parse('${Env.bmoniBaseUrl}/users/$userId/smart-wallets/create-managed');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        "currency": "CNGN",
        "userOwnerAddress": userOwnerAddress,
        "ownerProofChallengeId": challengeId,
        "ownerProofSignature": signature,
      }),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(jsonDecode(response.body));
    }
    throw Exception('Failed to create managed wallet: ${response.body}');
  }

  static Future<Map<String, dynamic>> startNigeriaOnboarding({
    required String userId,
    required String bvn,
    required String ngnWalletAddress,
    required int ngnWalletIndex,
  }) async {
    final url = Uri.parse('${Env.bmoniBaseUrl}/users/$userId/onboarding/start-nigeria');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        "bvn": bvn,
        "ngnWalletAddress": ngnWalletAddress,
        "ngnWalletIndex": ngnWalletIndex,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to start Nigeria onboarding: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getOnboardingStatus({
    required String userId,
  }) async {
    final url = Uri.parse('${Env.bmoniBaseUrl}/users/$userId/onboarding/status');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to get onboarding status: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  /// Create a card
 /// and get the proposal ID and payload to sign.
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
      return _unwrapData(jsonDecode(response.body));
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
        final data = _unwrapData(jsonDecode(response.body));
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
      return _unwrapData(jsonDecode(response.body));
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
      return _unwrapData(jsonDecode(response.body));
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
      return _unwrapData(jsonDecode(response.body));
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
      final data = _unwrapData(jsonDecode(response.body));
      if (data is List) return data;
      if (data is Map && data.containsKey('transactions')) return data['transactions'] as List;
      if (data is Map && data.containsKey('data')) return data['data'] as List;
      return [data]; 
    } else {
      throw Exception('Failed to fetch transactions: ${response.body}');
    }
  }
  static Future<Map<String, dynamic>> getDepositAccount({
    required String userId,
  }) async {
    final url = Uri.parse('${Env.bmoniBaseUrl}/users/$userId/bank-accounts/deposit-accounts/NGN');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch deposit account: ${response.body}');
    }
  }

}
