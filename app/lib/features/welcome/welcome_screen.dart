import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              
              // Logo and Title
              Column(
                children: [
                  Icon(
                    PhosphorIcons.target(),
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'BetterSaid',
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Anonymous, Link-Based Fight Mediator',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              
              const SizedBox(height: 48),
              
              // Description
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(
                        PhosphorIcons.magicWand(),
                        size: 32,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Cool down conflicts with AI-powered rewrites',
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set a goal, paste your heated draft, and get calm, direct, and brief alternatives to copy.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Action Buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => context.push('/create'),
                    icon: Icon(PhosphorIcons.plus()),
                    label: const Text('Create Anonymous Room'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showJoinDialog(context),
                    icon: Icon(PhosphorIcons.signIn()),
                    label: const Text('Join with Code'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Privacy Notice
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIcons.shieldCheck(),
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Anonymous by design • No accounts required',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showJoinDialog(BuildContext context) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the room code to join:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'e.g., 7KJ-4MZ',
                labelText: 'Room Code',
              ),
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  Navigator.of(context).pop();
                  context.push('/c/$value');
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = controller.text.trim();
              if (code.isNotEmpty) {
                Navigator.of(context).pop();
                context.push('/c/$code');
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}
