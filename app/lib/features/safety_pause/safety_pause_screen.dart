import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SafetyPauseScreen extends ConsumerWidget {
  final String? blockedContent;
  final List<String> resources;

  const SafetyPauseScreen({
    super.key,
    this.blockedContent,
    required this.resources,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Pause'),
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft()),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Column(
                children: [
                  Icon(
                    PhosphorIcons.shieldWarning(),
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Content Blocked',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your message was blocked by our safety systems',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Explanation
              Card(
                color: theme.colorScheme.errorContainer.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            PhosphorIcons.info(),
                            size: 20,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Why was this blocked?',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'BetterSaid uses AI safety systems to prevent harmful content including threats, harassment, self-harm, and other dangerous material. This helps keep conversations constructive and safe for everyone.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Suggestions
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            PhosphorIcons.lightbulb(),
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Try rephrasing your message',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• Focus on specific behaviors rather than personal attacks\n'
                        '• Use "I" statements to express your feelings\n'
                        '• Suggest concrete solutions or compromises\n'
                        '• Take a break if you\'re feeling overwhelmed',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Crisis Resources (if provided)
              if (resources.isNotEmpty) ...[
                const SizedBox(height: 24),
                Card(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              PhosphorIcons.heart(),
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Need support?',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'If you\'re going through a difficult time, these resources can help:',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        ...resources.map((resource) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: InkWell(
                            onTap: () => _launchResource(resource),
                            child: Row(
                              children: [
                                Icon(
                                  PhosphorIcons.arrowSquareOut(),
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    resource,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                      ],
                    ),
                  ),
                ),
              ],
              
              const Spacer(),
              
              // Action Buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => context.pop(),
                    icon: Icon(PhosphorIcons.arrowLeft()),
                    label: const Text('Go Back and Rephrase'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/'),
                    icon: Icon(PhosphorIcons.house()),
                    label: const Text('Return to Home'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
  
  Future<void> _launchResource(String resource) async {
    // In a real app, these would be actual URLs to crisis resources
    // For now, we'll just show a placeholder
    final uri = Uri.parse('https://example.com/crisis-resources');
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Handle error silently or show a message
    }
  }
}
