import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../theme/theme.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isLight
                ? [
                    theme.colorScheme.background,
                    AppTheme.offWhite,
                  ]
                : [
                    theme.colorScheme.background,
                    AppTheme.charcoalGray,
                  ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              children: [
                // Top spacer for better vertical centering
                const Spacer(flex: 2),
                
                // Hero Section
                Column(
                  children: [
                    // Logo with glassmorphism effect
                    Container(
                      width: 96,
                      height: 96,
                      decoration: AppTheme.elevatedGlassContainer(
                        isLight: isLight,
                        opacity: 0.2,
                      ),
                      child: Icon(
                        PhosphorIcons.target(),
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Title with improved typography
                    Text(
                      'BetterSaid',
                      style: theme.textTheme.displayLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    // Subtitle with better spacing
                    Text(
                      'Anonymous, Link-Based Fight Mediator',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                
                const SizedBox(height: 64),
                
                // Feature Card with glassmorphism
                Container(
                  decoration: AppTheme.glassContainer(
                    isLight: isLight,
                    opacity: 0.15,
                    blur: 15,
                  ),
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      // Feature icon with gradient background
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: AppTheme.lavenderGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          PhosphorIcons.magicWand(),
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Feature title
                      Text(
                        'Cool down conflicts with AI-powered rewrites',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      
                      // Feature description
                      Text(
                        'Set a goal, paste your heated draft, and get calm, direct, and brief alternatives to copy.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const Spacer(flex: 3),
                
                // Action Buttons with improved styling
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Primary CTA with gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.deepBlue.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/create'),
                        icon: Icon(PhosphorIcons.plus(), size: 20),
                        label: const Text('Create Anonymous Room'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          textStyle: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Secondary CTA
                    OutlinedButton.icon(
                      onPressed: () => _showJoinDialog(context),
                      icon: Icon(PhosphorIcons.signIn(), size: 20),
                      label: const Text('Join with Code'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        textStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Privacy Notice with improved styling
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIcons.shieldCheck(),
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Anonymous by design • No accounts required',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
              ],
            ),
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
