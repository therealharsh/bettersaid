import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'env.dart';
import 'storage.dart';

// Models
class CreateRoomResult {
  final String publicCode;
  final String shareUrl;
  final DateTime ttlExpiresAt;

  CreateRoomResult({
    required this.publicCode,
    required this.shareUrl,
    required this.ttlExpiresAt,
  });

  factory CreateRoomResult.fromJson(Map<String, dynamic> json) {
    return CreateRoomResult(
      publicCode: json['publicCode'],
      shareUrl: json['shareUrl'],
      ttlExpiresAt: DateTime.parse(json['ttlExpiresAt']),
    );
  }
}

class JoinRoomResult {
  final String sessionId;
  final String goal;
  final DateTime ttlExpiresAt;

  JoinRoomResult({
    required this.sessionId,
    required this.goal,
    required this.ttlExpiresAt,
  });

  factory JoinRoomResult.fromJson(Map<String, dynamic> json) {
    return JoinRoomResult(
      sessionId: json['sessionId'],
      goal: json['goal'],
      ttlExpiresAt: DateTime.parse(json['ttlExpiresAt']),
    );
  }
}

class RewriteResult {
  final String style;
  final String text;

  RewriteResult({
    required this.style,
    required this.text,
  });

  factory RewriteResult.fromJson(Map<String, dynamic> json) {
    return RewriteResult(
      style: json['style'],
      text: json['text'],
    );
  }
}

class RewriteResponse {
  final List<RewriteResult> rewrites;
  final String? notes;

  RewriteResponse({
    required this.rewrites,
    this.notes,
  });

  factory RewriteResponse.fromJson(Map<String, dynamic> json) {
    return RewriteResponse(
      rewrites: (json['rewrites'] as List)
          .map((r) => RewriteResult.fromJson(r))
          .toList(),
      notes: json['notes'],
    );
  }
}

class ChatMessage {
  final String id;
  final String chatId;
  final String? authorSession;
  final String role;
  final String content;
  final DateTime createdAt;
  final List<RewriteResult>? rewrites;

  ChatMessage({
    required this.id,
    required this.chatId,
    this.authorSession,
    required this.role,
    required this.content,
    required this.createdAt,
    this.rewrites,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      chatId: json['chat_id'],
      authorSession: json['author_session'],
      role: json['role'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      rewrites: json['rewrites'] != null
          ? (json['rewrites'] as List)
              .map((r) => RewriteResult.fromJson(r))
              .toList()
          : null,
    );
  }
}

class SafetyBlock {
  final bool blocked;
  final List<String> resources;

  SafetyBlock({
    required this.blocked,
    required this.resources,
  });

  factory SafetyBlock.fromJson(Map<String, dynamic> json) {
    return SafetyBlock(
      blocked: json['blocked'],
      resources: List<String>.from(json['resources'] ?? []),
    );
  }
}

class ApiClient {
  final Dio _dio;
  final StorageService _storage;
  final String _baseUrl;

  ApiClient({
    required String baseUrl,
    required StorageService storage,
    required String anonKey,
  })  : _baseUrl = baseUrl,
        _storage = storage,
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'apikey': anonKey,
            // Note: Authorization header is set per-request as needed
          },
        )) {
    // Store anon key for use in specific requests
    _anonKey = anonKey;
  }

  late final String _anonKey;

  // Create a new room
  Future<CreateRoomResult> createRoom({
    required String goal,
    int ttlHours = 12,
    bool allowObservers = false,
  }) async {
    print('🌐 [ApiClient] createRoom called');
    print('🌐 [ApiClient] Base URL: $_baseUrl');
    print('🌐 [ApiClient] Endpoint: /create-room');
    print('🌐 [ApiClient] Goal: "$goal"');
    print('🌐 [ApiClient] TTL Hours: $ttlHours');
    print('🌐 [ApiClient] Allow Observers: $allowObservers');
    
    try {
      print('🌐 [ApiClient] Making POST request...');
      final response = await _dio.post(
        '/create-room', 
        data: {
          'goal': goal,
          'ttlHours': ttlHours,
          'allowObservers': allowObservers,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $_anonKey',
        }),
      );

      print('✅ [ApiClient] Request successful!');
      print('🌐 [ApiClient] Response status: ${response.statusCode}');
      print('🌐 [ApiClient] Response data: ${response.data}');

      return CreateRoomResult.fromJson(response.data);
    } on DioException catch (e) {
      print('❌ [ApiClient] DioException caught');
      print('❌ [ApiClient] Error type: ${e.type}');
      print('❌ [ApiClient] Error message: ${e.message}');
      print('❌ [ApiClient] Response: ${e.response}');
      print('❌ [ApiClient] Request options: ${e.requestOptions}');
      throw _handleError(e);
    }
  }

  // Join a room
  Future<JoinRoomResult> joinRoom({
    required String publicCode,
    required String displayName,
    required String secret,
  }) async {
    print('🚪 [ApiClient] joinRoom called');
    print('🚪 [ApiClient] Public code: $publicCode');
    print('🚪 [ApiClient] Display name: $displayName');
    print('🚪 [ApiClient] Secret length: ${secret.length}');
    print('🚪 [ApiClient] Secret starts with: ${secret.isNotEmpty ? secret.substring(0, secret.length < 10 ? secret.length : 10) : "EMPTY"}...');
    
    try {
      final options = Options(
        headers: {
          'Content-Type': 'application/json',
          'apikey': _anonKey,
          'x-room-secret': secret,
          'Authorization': 'Bearer $_anonKey',
        },
      );
      print('🚪 [ApiClient] Request options headers: ${options.headers}');
      
      final response = await _dio.post(
        '/join-room',
        data: {
          'publicCode': publicCode,
          'displayName': displayName,
        },
        options: options,
      );

      final result = JoinRoomResult.fromJson(response.data);
      
      // Store session info
      await _storage.setSessionId(publicCode, result.sessionId);
      await _storage.setSecret(publicCode, secret);
      await _storage.setRoomGoal(publicCode, result.goal);
      await _storage.setTtlExpiration(publicCode, result.ttlExpiresAt);
      
      return result;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Send a draft message
  Future<void> sendDraft({
    required String publicCode,
    required String sessionId,
    required String draft,
  }) async {
    try {
      final secret = await _storage.getSecret(publicCode);
      if (secret == null) throw Exception('No secret found for room');

      await _dio.post(
        '/send-draft',
        data: {
          'publicCode': publicCode,
          'sessionId': sessionId,
          'draft': draft,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $_anonKey',
          'x-room-secret': secret,
        }),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 && 
          e.response?.data['blocked'] == true) {
        throw SafetyBlock.fromJson(e.response!.data);
      }
      throw _handleError(e);
    }
  }

  // Get rewrites for a draft
  Future<RewriteResponse> getRewrite({
    required String publicCode,
    required String sessionId,
    required String goal,
    required String draft,
  }) async {
    try {
      final secret = await _storage.getSecret(publicCode);
      if (secret == null) throw Exception('No secret found for room');

      final response = await _dio.post(
        '/rewrite',
        data: {
          'publicCode': publicCode,
          'sessionId': sessionId,
          'goal': goal,
          'draft': draft,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $_anonKey',
          'x-room-secret': secret,
        }),
      );

      return RewriteResponse.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 && 
          e.response?.data['blocked'] == true) {
        throw SafetyBlock.fromJson(e.response!.data);
      }
      throw _handleError(e);
    }
  }

  // List messages in a room
  Future<List<ChatMessage>> listMessages({
    required String publicCode,
    DateTime? since,
  }) async {
    try {
      final secret = await _storage.getSecret(publicCode);
      if (secret == null) throw Exception('No secret found for room');

      final queryParams = <String, dynamic>{
        'publicCode': publicCode,
      };
      
      if (since != null) {
        queryParams['since'] = since.toIso8601String();
      }

      final response = await _dio.get(
        '/list-messages',
        queryParameters: queryParams,
        options: Options(headers: {
          'Authorization': 'Bearer $_anonKey',
          'x-room-secret': secret,
        }),
      );

      return (response.data['messages'] as List)
          .map((m) => ChatMessage.fromJson(m))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Save room (extend TTL by 24h)
  Future<DateTime> saveRoom({
    required String publicCode,
  }) async {
    try {
      final secret = await _storage.getSecret(publicCode);
      if (secret == null) throw Exception('No secret found for room');

      final response = await _dio.post(
        '/save-room',
        data: {'publicCode': publicCode},
        options: Options(headers: {
          'Authorization': 'Bearer $_anonKey',
          'x-room-secret': secret,
        }),
      );

      return DateTime.parse(response.data['ttlExpiresAt']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Close room (hard delete)
  Future<void> closeRoom({
    required String publicCode,
  }) async {
    try {
      final secret = await _storage.getSecret(publicCode);
      if (secret == null) throw Exception('No secret found for room');

      await _dio.post(
        '/close-room',
        data: {'publicCode': publicCode},
        options: Options(headers: {
          'Authorization': 'Bearer $_anonKey',
          'x-room-secret': secret,
        }),
      );

      // Clean up local storage
      await _storage.clearRoom(publicCode);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    print('🔥 [ApiClient] Handling DioException');
    print('🔥 [ApiClient] Exception type: ${e.type}');
    print('🔥 [ApiClient] Exception message: ${e.message}');
    
    if (e.response != null) {
      print('🔥 [ApiClient] Response received');
      print('🔥 [ApiClient] Status code: ${e.response!.statusCode}');
      print('🔥 [ApiClient] Response headers: ${e.response!.headers}');
      print('🔥 [ApiClient] Response data: ${e.response!.data}');
      
      final data = e.response!.data;
      if (data is Map && data.containsKey('error')) {
        return data['error'];
      }
      return 'Server error: ${e.response!.statusCode}';
    } else if (e.type == DioExceptionType.connectionTimeout) {
      print('🔥 [ApiClient] Connection timeout');
      return 'Connection timeout';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      print('🔥 [ApiClient] Receive timeout');
      return 'Receive timeout';
    } else {
      print('🔥 [ApiClient] Network error');
      print('🔥 [ApiClient] Request options: ${e.requestOptions}');
      return 'Network error: ${e.message}';
    }
  }
}

// Provider
final apiClientProvider = FutureProvider<ApiClient>((ref) async {
  print('🏗️ [ApiClientProvider] Creating API client...');
  final env = ref.read(envProvider);
  print('🏗️ [ApiClientProvider] Supabase URL: ${env.supabaseUrl}');
  print('🏗️ [ApiClientProvider] Anon key length: ${env.supabaseAnonKey.length}');
  print('🏗️ [ApiClientProvider] Anon key starts with: ${env.supabaseAnonKey.substring(0, 20)}...');
  
  final storage = await ref.read(storageServiceAsyncProvider.future);
  print('🏗️ [ApiClientProvider] Storage service ready');
  
  final client = ApiClient(
    baseUrl: env.supabaseUrl,
    storage: storage,
    anonKey: env.supabaseAnonKey,
  );
  
  print('✅ [ApiClientProvider] API client created successfully');
  return client;
});
