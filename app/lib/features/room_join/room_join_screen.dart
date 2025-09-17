import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:html' as html;

import '../../services/api_client.dart';

class RoomJoinScreen extends ConsumerStatefulWidget {
  final String publicCode;
  final String? secret;

  const RoomJoinScreen({
    super.key,
    required this.publicCode,
    this.secret,
  });

  @override
  ConsumerState<RoomJoinScreen> createState() => _RoomJoinScreenState();
}

class _RoomJoinScreenState extends ConsumerState<RoomJoinScreen> {
  final _displayNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    print('🔗 [RoomJoinScreen] Widget initialized');
    print('🔗 [RoomJoinScreen] Public code from widget: ${widget.publicCode}');
    print('🔗 [RoomJoinScreen] Secret from widget: ${widget.secret}');
    
    // Also check browser location directly
    try {
      final browserUrl = html.window.location.href;
      final browserFragment = html.window.location.hash;
      print('🔗 [RoomJoinScreen] Full browser URL: $browserUrl');
      print('🔗 [RoomJoinScreen] Browser fragment: $browserFragment');
    } catch (e) {
      print('❌ [RoomJoinScreen] Error accessing browser location: $e');
    }
  }
  
  String? _getSecretFromBrowser() {
    try {
      final browserFragment = html.window.location.hash;
      print('🔍 [RoomJoinScreen] Getting secret from browser fragment: $browserFragment');
      
      if (browserFragment.isNotEmpty && browserFragment.startsWith('#')) {
        final secret = browserFragment.substring(1); // Remove the # prefix
        print('🔍 [RoomJoinScreen] Extracted secret: $secret');
        return secret;
      }
    } catch (e) {
      print('❌ [RoomJoinScreen] Error extracting secret from browser: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Room'),
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft()),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Column(
                  children: [
                    Icon(
                      PhosphorIcons.signIn(),
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Join Conversation',
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a display name for this room',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Room Info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              PhosphorIcons.target(),
                              size: 20,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Room Code: ${widget.publicCode}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              PhosphorIcons.hourglassHigh(),
                              size: 20,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Room expires in 12 hours',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Display Name Input
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    hintText: 'e.g., Alex, Sam, or any name you prefer',
                    helperText: 'This name will be visible to others in the room',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a display name';
                    }
                    if (value.trim().length < 2) {
                      return 'Display name must be at least 2 characters';
                    }
                    if (value.trim().length > 20) {
                      return 'Display name must be less than 20 characters';
                    }
                    return null;
                  },
                ),
                
                const Spacer(),
                
                // Privacy Notice
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            PhosphorIcons.shieldCheck(),
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Anonymous & Private',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your display name is only used in this room and is not stored permanently. All conversations are automatically deleted.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Join Button
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _joinRoom,
                  icon: _isLoading 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(PhosphorIcons.arrowRight()),
                  label: Text(_isLoading ? 'Joining...' : 'Join Room'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Future<void> _joinRoom() async {
    print('🚪 [RoomJoin] Attempting to join room');
    print('🚪 [RoomJoin] Public code: ${widget.publicCode}');
    print('🚪 [RoomJoin] Secret from widget: ${widget.secret}');
    print('🚪 [RoomJoin] Secret is null: ${widget.secret == null}');
    print('🚪 [RoomJoin] Secret is empty: ${widget.secret?.isEmpty}');
    print('🚪 [RoomJoin] Display name: ${_displayNameController.text.trim()}');
    
    if (!_formKey.currentState!.validate()) {
      print('❌ [RoomJoin] Form validation failed');
      return;
    }
    
    // Try to get secret from widget first, then from browser as fallback
    String? secret = widget.secret;
    if (secret == null || secret.isEmpty) {
      print('🔍 [RoomJoin] Widget secret is null/empty, trying browser...');
      secret = _getSecretFromBrowser();
      print('🔍 [RoomJoin] Secret from browser: $secret');
    }
    
    if (secret == null || secret.isEmpty) {
      print('❌ [RoomJoin] No secret found in widget or browser - showing error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid room link. Please check the URL and try again.'),
        ),
      );
      return;
    }
    
    print('✅ [RoomJoin] Secret validation passed, proceeding with join...');
    
    setState(() => _isLoading = true);
    
    try {
      print('🚪 [RoomJoin] Getting API client...');
      final apiClient = await ref.read(apiClientProvider.future);
      
      print('🚪 [RoomJoin] Calling joinRoom API...');
      print('🚪 [RoomJoin] Final secret being used: $secret');
      await apiClient.joinRoom(
        publicCode: widget.publicCode,
        displayName: _displayNameController.text.trim(),
        secret: secret,
      );
      
      print('✅ [RoomJoin] Successfully joined room!');
      print('🚪 [RoomJoin] Navigating to chat...');
      
      // Navigate to room chat
      if (mounted) {
        context.go('/room/${widget.publicCode}?secret=$secret');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        String errorMessage = 'Failed to join room';
        
        if (e.toString().contains('not found')) {
          errorMessage = 'Room not found. It may have expired or been deleted.';
        } else if (e.toString().contains('unauthorized')) {
          errorMessage = 'Invalid room link. Please check the URL and try again.';
        } else {
          errorMessage = 'Failed to join room: $e';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
