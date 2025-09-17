import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/api_client.dart';

class RoomCreateScreen extends ConsumerStatefulWidget {
  const RoomCreateScreen({super.key});

  @override
  ConsumerState<RoomCreateScreen> createState() => _RoomCreateScreenState();
}

class _RoomCreateScreenState extends ConsumerState<RoomCreateScreen> {
  final _goalController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _allowObservers = false;
  
  String? _shareUrl;
  String? _publicCode;

  @override
  void dispose() {
    _goalController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Room'),
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft()),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _shareUrl != null ? _buildShareView() : _buildCreateForm(),
        ),
      ),
    );
  }
  
  Widget _buildCreateForm() {
    final theme = Theme.of(context);
    
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Column(
            children: [
              Icon(
                PhosphorIcons.target(),
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Set Your Goal',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'What do you want to achieve from this conversation?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Display Name Input
          TextFormField(
            controller: _displayNameController,
            decoration: const InputDecoration(
              labelText: 'Your Display Name',
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
          
          const SizedBox(height: 24),
          
          // Goal Input
          TextFormField(
            controller: _goalController,
            decoration: const InputDecoration(
              labelText: 'Conversation Goal',
              hintText: 'e.g., "Resolve our disagreement about the project timeline"',
              helperText: 'Keep it specific and actionable (max 200 characters)',
            ),
            maxLength: 200,
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a goal for this conversation';
              }
              if (value.trim().length < 10) {
                return 'Please provide a more specific goal';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 24),
          
          // Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Room Settings',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  
                  // TTL Info
                  Row(
                    children: [
                      Icon(
                        PhosphorIcons.hourglassHigh(),
                        size: 20,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto-delete in 12 hours',
                              style: theme.textTheme.bodyMedium,
                            ),
                            Text(
                              'Room will self-destruct unless saved',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Observer Setting
                  SwitchListTile(
                    value: _allowObservers,
                    onChanged: (value) => setState(() => _allowObservers = value),
                    title: const Text('Allow observers'),
                    subtitle: const Text('Let others view without participating'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          
          const Spacer(),
          
          // Create Button
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _createRoom,
            icon: _isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(PhosphorIcons.plus()),
            label: Text(_isLoading ? 'Creating...' : 'Create Anonymous Room'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildShareView() {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success Header
        Column(
          children: [
            Icon(
              PhosphorIcons.checkCircle(),
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Room Created!',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Share this link to invite someone to join',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        
        const SizedBox(height: 32),
        
        // QR Code
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                QrImageView(
                  data: _shareUrl!,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  'Room Code: $_publicCode',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Share Actions
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () => _copyLink(),
              icon: Icon(PhosphorIcons.copy()),
              label: const Text('Copy Link'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _shareLink(),
              icon: Icon(PhosphorIcons.shareNetwork()),
              label: const Text('Share Link'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _openRoom(),
              icon: Icon(PhosphorIcons.arrowRight()),
              label: const Text('Join Room'),
            ),
          ],
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
          child: Row(
            children: [
              Icon(
                PhosphorIcons.shieldCheck(),
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your room is anonymous and will auto-delete in 12 hours unless saved.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Future<void> _createRoom() async {
    print('🎯 [RoomCreate] Create Anonymous Room button clicked');
    print('🎯 [RoomCreate] Form validation check...');
    
    if (!_formKey.currentState!.validate()) {
      print('❌ [RoomCreate] Form validation failed');
      return;
    }
    
    print('✅ [RoomCreate] Form validation passed');
    print('🎯 [RoomCreate] Goal: "${_goalController.text.trim()}"');
    print('🎯 [RoomCreate] Allow observers: $_allowObservers');
    
    setState(() => _isLoading = true);
    print('🎯 [RoomCreate] Loading state set to true');
    
    try {
      print('🎯 [RoomCreate] Getting API client...');
      final apiClient = await ref.read(apiClientProvider.future);
      print('✅ [RoomCreate] API client obtained successfully');
      
      print('🎯 [RoomCreate] Calling createRoom API...');
      final result = await apiClient.createRoom(
        goal: _goalController.text.trim(),
        allowObservers: _allowObservers,
      );
      print('✅ [RoomCreate] Room created successfully!');
      print('🎯 [RoomCreate] Public code: ${result.publicCode}');
      print('🎯 [RoomCreate] Share URL: ${result.shareUrl}');
      print('🎯 [RoomCreate] TTL expires at: ${result.ttlExpiresAt}');
      
      setState(() {
        _shareUrl = result.shareUrl;
        _publicCode = result.publicCode;
        _isLoading = false;
      });
      print('✅ [RoomCreate] UI updated with room details');
    } catch (e) {
      print('❌ [RoomCreate] Error creating room: $e');
      print('❌ [RoomCreate] Error type: ${e.runtimeType}');
      setState(() => _isLoading = false);
      
      if (mounted) {
        print('🎯 [RoomCreate] Showing error snackbar');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create room: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
  
  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _shareUrl!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard')),
    );
  }
  
  void _shareLink() {
    Share.share(
      _shareUrl!,
      subject: 'Join my BetterSaid conversation',
    );
  }
  
  Future<void> _openRoom() async {
    print('🚪 [RoomCreate] Opening room...');
    print('🚪 [RoomCreate] Share URL: $_shareUrl');
    
    final uri = Uri.parse(_shareUrl!);
    final publicCode = uri.pathSegments.last;
    final secret = uri.queryParameters['secret'] ?? '';
    
    print('🚪 [RoomCreate] Parsed URI: $uri');
    print('🚪 [RoomCreate] Public code: $publicCode');
    print('🚪 [RoomCreate] Secret from query params: "$secret"');
    print('🚪 [RoomCreate] Secret length: ${secret.length}');
    
    try {
      // Join the room with the display name
      final apiClient = await ref.read(apiClientProvider.future);
      await apiClient.joinRoom(
        publicCode: publicCode,
        displayName: _displayNameController.text.trim(),
        secret: secret,
      );
      
      // Navigate to the room
      final roomUrl = '/room/$publicCode?secret=$secret';
      print('🚪 [RoomCreate] Navigating to: $roomUrl');
      
      if (mounted) {
        context.go(roomUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join room: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
