import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';

import 'crash_log.dart';

/// Phrases our own code already throws that are fine to show the user as-is.
const List<String> _friendlyPrefixes = [
  'This email or phone is already registered',
  'This phone or email is already registered',
  'This build of StaffPurse',
  'PIN must be exactly 6 digits',
  'Enter valid non-negative limits',
  'Phone must be in +234 format',
];

/// Converts any thrown object into a short, human-friendly message.
///
/// The full technical detail is written to the on-device crash log so
/// diagnosis still works — the user just never sees raw exceptions, HTTP
/// status codes or JSON error bodies.
String userFacingError(Object error, {String? fallback}) {
  final raw = error.toString();

  // Always record the technical detail before mapping — even errors that are
  // safe to show as-is (early return below) must stay diagnosable from the
  // on-device log.
  CrashLog.write('RAW ERROR: $raw');

  for (final p in _friendlyPrefixes) {
    if (raw.contains(p)) {
      return raw
          .replaceFirst('Exception: ', '')
          .replaceFirst('Setup failed: ', '');
    }
  }

  String message;
  if (error is BmoniSignerException) {
    switch (error.errorCode) {
      case BmoniSignerErrorCode.pinInvalid:
        message = 'The wallet PIN must be exactly 6 digits.';
        break;
      case BmoniSignerErrorCode.walletAlreadyExists:
        message = 'A wallet already exists on this device. Try again in a moment.';
        break;
      default:
        message = 'Secure signing failed on this device. Please try again.';
    }
  } else if (error is SocketException ||
      error is http.ClientException ||
      raw.contains('Failed host lookup') ||
      raw.contains('Connection refused') ||
      raw.contains('Connection closed before')) {
    message = 'Can\u2019t reach the server. Check your internet connection and try again.';
  } else if (error is TimeoutException ||
      raw.contains('timed out') ||
      raw.contains('TimeoutException')) {
    message = 'The server took too long to respond. Please try again.';
  } else if (raw.contains('already registered') ||
      raw.contains('user_already_exists') ||
      raw.contains('already exists') ||
      raw.contains('409') ||
      raw.contains('23505')) {
    message = 'This email or phone is already registered on another account. Use a different email and phone, or log in if you already completed setup.';
  } else if (raw.contains('401') ||
      raw.contains('Unauthorized') ||
      raw.contains('403')) {
    message = 'Your session has expired or your details are incorrect. Please log in again.';
  } else if (raw.contains('E101') ||
      raw.contains('active balances') ||
      raw.contains('cannot deactivate')) {
    message = 'Your wallet still has funds. Move the funds out before deleting the account.';
  } else if (raw.contains('E503') || raw.contains('Insufficient balance')) {
    message = 'Issuing a card costs a small fee, and this wallet has no funds yet. Open Fund Wallet from the dashboard to request sandbox test funds, then try again.';
  } else if (raw.contains('404') || raw.contains('Not Found')) {
    message = 'That doesn\u2019t exist on the server yet. Try again shortly.';
  } else if (raw.contains('400') ||
      raw.contains('422') ||
      raw.contains('Invalid') ||
      raw.contains('validation')) {
    message = 'One of the details you entered was not accepted. Double-check and try again.';
  } else if (raw.contains('429') || raw.contains('Too Many Requests')) {
    message = 'Too many attempts \u2014 wait a moment and try again.';
  } else if (raw.contains('500') ||
      raw.contains('502') ||
      raw.contains('503')) {
    message = 'The server hit a hiccup. Please try again in a moment.';
  } else if (error is PlatformException) {
    message = 'A device operation failed. Please try again.';
  } else if (error is FormatException) {
    message = 'Something you entered wasn\u2019t recognised. Double-check and try again.';
  } else if (raw.contains('signing failed')) {
    message = 'Secure signing failed on this device. Please try again.';
  } else {
    message = fallback ?? 'Something went wrong. Please try again.';
  }

  return message;
}