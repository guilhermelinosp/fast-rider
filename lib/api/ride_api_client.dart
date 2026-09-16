import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:fast_rider/models/ride.dart';

abstract interface class RideApiClient {
  Future<RideResponse> createRide(RideRequest request);
}

class RideApiException implements Exception {
  const RideApiException({
    required this.code,
    required this.message,
    this.requestId,
    this.statusCode,
  });

  final String code;
  final String message;
  final String? requestId;
  final int? statusCode;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' ($statusCode)';
    final request = requestId == null ? '' : ' [requestId: $requestId]';
    return 'RideApiException$status: $code - $message$request';
  }
}

class HttpRideApiClient implements RideApiClient {
  HttpRideApiClient({
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;
  final Duration timeout;

  @override
  Future<RideResponse> createRide(RideRequest request) async {
    late final Uri endpoint;
    try {
      endpoint = Uri.parse('$_baseUrl/api/v1/rides');
    } on FormatException {
      throw const RideApiException(
        code: 'invalid_base_url',
        message: 'The configured backend URL is invalid.',
      );
    }

    late final http.Response response;
    try {
      response = await _client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'rider_id': request.riderId,
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const RideApiException(
        code: 'timeout',
        message: 'The request timed out.',
      );
    } on SocketException {
      throw const RideApiException(
        code: 'connection_error',
        message: 'Could not connect to the backend.',
      );
    } on http.ClientException catch (error) {
      throw RideApiException(code: 'connection_error', message: error.message);
    } catch (error) {
      throw RideApiException(code: 'network_error', message: error.toString());
    }

    final payload = _decodeObject(response.body);
    final requestId = _requestId(payload) ?? response.headers['x-request-id'];

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RideApiException(
        code: _stringValue(payload?['code']) ?? 'http_error',
        message:
            _stringValue(payload?['message']) ??
            'Backend returned HTTP ${response.statusCode}.',
        requestId: requestId,
        statusCode: response.statusCode,
      );
    }

    if (payload == null) {
      throw RideApiException(
        code: 'malformed_response',
        message: 'Backend returned an invalid JSON response.',
        requestId: requestId,
        statusCode: response.statusCode,
      );
    }

    try {
      return RideResponse.fromJson(payload);
    } on FormatException catch (error) {
      throw RideApiException(
        code: 'malformed_response',
        message: error.message,
        requestId: requestId,
        statusCode: response.statusCode,
      );
    }
  }

  Map<String, dynamic>? _decodeObject(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        return {...decoded, ...error};
      }
      return decoded;
    } on FormatException {
      return null;
    }
  }

  String? _requestId(Map<String, dynamic>? payload) {
    return _stringValue(payload?['requestId']) ??
        _stringValue(payload?['request_id']);
  }

  String? _stringValue(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
}
