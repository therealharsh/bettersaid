import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:html' as html;

import '../features/welcome/welcome_screen.dart';
import '../features/room_create/room_create_screen.dart';
import '../features/room_join/room_join_screen.dart';
import '../features/room_chat/room_chat_screen.dart';
import '../features/safety_pause/safety_pause_screen.dart';
import '../features/settings/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true, // Enable GoRouter debugging
    redirect: (context, state) {
      print('🔄 [Router] Redirect called');
      print('🔄 [Router] Current location: ${state.fullPath}');
      print('🔄 [Router] Current URI: ${state.uri}');
      print('🔄 [Router] Matched location: ${state.matchedLocation}');
      return null; // No redirect, let it proceed normally
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'welcome',
        builder: (context, state) {
          print('🏠 [Router] Welcome route matched!');
          return const WelcomeScreen();
        },
      ),
      GoRoute(
        path: '/test',
        name: 'test',
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: const Text('Test Route')),
            body: const Center(
              child: Text('Test route is working!'),
            ),
          );
        },
      ),
      GoRoute(
        path: '/create',
        name: 'create',
        builder: (context, state) => const RoomCreateScreen(),
      ),
      GoRoute(
        path: '/c/:publicCode',
        name: 'join',
        builder: (context, state) {
          print('🔗 [Router] Join route matched!');
          print('🔗 [Router] Full URI: ${state.uri}');
          print('🔗 [Router] Path: ${state.uri.path}');
          print('🔗 [Router] Fragment: ${state.uri.fragment}');
          print('🔗 [Router] Query parameters: ${state.uri.queryParameters}');
          print('🔗 [Router] Path parameters: ${state.pathParameters}');
          
          final publicCode = state.pathParameters['publicCode']!;
          
          // Get secret from query parameters (preferred) or fragment (fallback)
          String? secret = state.uri.queryParameters['secret'];
          
          // Fallback to fragment if query parameter is not available
          if (secret == null || secret.isEmpty) {
            try {
              final browserFragment = html.window.location.hash;
              print('🔗 [Router] Browser fragment (with #): $browserFragment');
              
              if (browserFragment.isNotEmpty && browserFragment.startsWith('#')) {
                secret = browserFragment.substring(1); // Remove the # prefix
              }
              
              // Also try state fragment
              if (secret == null || secret.isEmpty) {
                secret = state.uri.fragment;
              }
            } catch (e) {
              print('❌ [Router] Error accessing browser fragment: $e');
              secret = state.uri.fragment;
            }
          }
          
          print('🔗 [Router] Public code: $publicCode');
          print('🔗 [Router] Secret: $secret');
          
          return RoomJoinScreen(
            publicCode: publicCode,
            secret: secret,
          );
        },
      ),
      GoRoute(
        path: '/room/:publicCode',
        name: 'room',
        builder: (context, state) {
          print('💬 [Router] Room route matched!');
          print('💬 [Router] Full URI: ${state.uri}');
          print('💬 [Router] Path: ${state.uri.path}');
          print('💬 [Router] Fragment: ${state.uri.fragment}');
          print('💬 [Router] Query parameters: ${state.uri.queryParameters}');
          
          final publicCode = state.pathParameters['publicCode']!;
          
          // Get secret from query parameters (preferred) or fragment (fallback)
          String? secret = state.uri.queryParameters['secret'];
          
          // Fallback to fragment if query parameter is not available
          if (secret == null || secret.isEmpty) {
            try {
              final browserFragment = html.window.location.hash;
              print('💬 [Router] Browser fragment (with #): $browserFragment');
              
              if (browserFragment.isNotEmpty && browserFragment.startsWith('#')) {
                secret = browserFragment.substring(1); // Remove the # prefix
              }
              
              // Also try state fragment
              if (secret == null || secret.isEmpty) {
                secret = state.uri.fragment;
              }
            } catch (e) {
              print('❌ [Router] Error accessing browser fragment: $e');
              secret = state.uri.fragment;
            }
          }
              
          print('💬 [Router] Public code: $publicCode');
          print('💬 [Router] Secret: $secret');
          
          return RoomChatScreen(
            publicCode: publicCode,
            secret: secret,
          );
        },
      ),
      GoRoute(
        path: '/safety-pause',
        name: 'safety-pause',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return SafetyPauseScreen(
            blockedContent: extra?['blockedContent'] as String?,
            resources: extra?['resources'] as List<String>? ?? [],
          );
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) {
      print('❌ [Router] Page not found!');
      print('❌ [Router] Requested URI: ${state.uri}');
      print('❌ [Router] Requested path: ${state.uri.path}');
      print('❌ [Router] Fragment: ${state.uri.fragment}');
      print('❌ [Router] Available routes: /, /create, /c/:publicCode, /room/:publicCode, /safety-pause, /settings');
      
      return Scaffold(
        appBar: AppBar(
          title: const Text('Page Not Found'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('The page you are looking for does not exist.'),
              const SizedBox(height: 16),
              Text('Requested: ${state.uri.path}'),
              const SizedBox(height: 8),
              Text('Fragment: ${state.uri.fragment}'),
            ],
          ),
        ),
      );
    },
  );
});
