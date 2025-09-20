import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../services/api_client.dart';
import '../../services/storage.dart';
import '../../theme/theme.dart';

class RoomChatScreen extends ConsumerStatefulWidget {
  final String publicCode;
  final String? secret;

  const RoomChatScreen({
    super.key,
    required this.publicCode,
    this.secret,
  });

  @override
  ConsumerState<RoomChatScreen> createState() => _RoomChatScreenState();
}

class _RoomChatScreenState extends ConsumerState<RoomChatScreen> {
  final _draftController = TextEditingController();
  final _scrollController = ScrollController();
  
  Timer? _pollingTimer;
  String? _sessionId;
  String? _goal;
  DateTime? _ttlExpiration;
  List<ChatMessage> _messages = [];
  RewriteResponse? _currentRewrites;
  
  bool _isLoadingMessages = true;
  bool _isGeneratingRewrites = false;
  bool _isSendingDraft = false;
  bool _roomSaved = false;
  
  String _selectedRewriteStyle = 'calm';
  


  @override
  void initState() {
    super.initState();
    // Defer initialization to avoid inherited widget access issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRoom();
    });
  }

  @override
  void dispose() {
    _draftController.dispose();
    _scrollController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeRoom() async {
    print('🔧 [RoomChat] Initializing room...');
    print('🔧 [RoomChat] Public code: ${widget.publicCode}');
    print('🔧 [RoomChat] Secret: "${widget.secret}"');
    print('🔧 [RoomChat] Secret is null: ${widget.secret == null}');
    print('🔧 [RoomChat] Secret is empty: ${widget.secret?.isEmpty}');
    
    if (widget.secret == null || widget.secret!.isEmpty) {
      print('❌ [RoomChat] Secret validation failed');
      _showError('Invalid room link. Please check the URL and try again.');
      return;
    }
    
    print('✅ [RoomChat] Secret validation passed');

    try {
      final storage = await ref.read(storageServiceAsyncProvider.future);
      
      // Store the secret
      await storage.setSecret(widget.publicCode, widget.secret!);
      
      // Get stored session info
      _sessionId = await storage.getSessionId(widget.publicCode);
      _goal = await storage.getRoomGoal(widget.publicCode);
      _ttlExpiration = await storage.getTtlExpiration(widget.publicCode);
      
      print('🔧 [RoomChat] Session ID: $_sessionId');
      print('🔧 [RoomChat] Goal: $_goal');
      print('🔧 [RoomChat] TTL Expiration: $_ttlExpiration');
      
      // If session info is missing, fetch room info and auto-join
      if (_sessionId == null || _goal == null) {
        print('🔧 [RoomChat] Session info missing, attempting to fetch room info and auto-join...');
        try {
          final apiClient = await ref.read(apiClientProvider.future);
          
          // First, try to get room info by listing messages (which validates the room and returns goal)
          // We can extract goal from the room validation in list-messages
          await _loadMessages(); // This will validate the room exists and is accessible
          
          // If we don't have a session ID, join the room with a default name
          if (_sessionId == null) {
            final joinResult = await apiClient.joinRoom(
              publicCode: widget.publicCode,
              displayName: 'Anonymous',
              secret: widget.secret!,
            );
            _sessionId = joinResult.sessionId;
            await storage.setSessionId(widget.publicCode, _sessionId!);
          }
          
          // If we still don't have goal after joining, there might be an issue
          if (_goal == null) {
            print('⚠️ [RoomChat] Goal is still null after auto-join attempt');
            _showError('Unable to load room information. Please try refreshing.');
            return;
          }
          
          print('✅ [RoomChat] Auto-join successful, Session ID: $_sessionId, Goal: $_goal');
        } catch (e) {
          print('❌ [RoomChat] Auto-join failed: $e');
          _showError('Failed to access room. Please try again or use a valid room link.');
          return;
        }
      }
      
      // Try to load initial messages, but don't fail if it doesn't work
      try {
        await _loadMessages();
      } catch (e) {
        print('⚠️ [RoomChat] Initial message load failed, continuing anyway: $e');
        setState(() => _isLoadingMessages = false);
      }
      
      // Start polling for new messages
      _startPolling();
      
    } catch (e) {
      print('❌ [RoomChat] Initialization failed: $e');
      _showError('Failed to initialize room: $e');
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadMessages();
    });
  }

  Future<void> _loadMessages() async {
    try {
      print('📨 [RoomChat] Loading messages...');
      final apiClient = await ref.read(apiClientProvider.future);
      final storage = await ref.read(storageServiceAsyncProvider.future);
      
      final lastMessageTime = await storage.getLastMessageTime(widget.publicCode);
      print('📨 [RoomChat] Last message time: $lastMessageTime');
      
      final messages = await apiClient.listMessages(
        publicCode: widget.publicCode,
        since: lastMessageTime,
      );
      
      print('📨 [RoomChat] Received ${messages.length} messages');
      
      if (messages.isNotEmpty) {
        setState(() {
          // Deduplicate messages by ID before adding
          final existingIds = _messages.map((m) => m.id).toSet();
          final newMessages = messages.where((m) => !existingIds.contains(m.id)).toList();
          
          print('📨 [RoomChat] Adding ${newMessages.length} new messages (${messages.length - newMessages.length} duplicates filtered)');
          
          _messages.addAll(newMessages);
          _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        });
        
        // Update last message time using the latest message's timestamp
        final latestMessage = messages.reduce((a, b) => 
          a.createdAt.isAfter(b.createdAt) ? a : b);
        await storage.setLastMessageTime(
          widget.publicCode,
          latestMessage.createdAt,
        );
        
        // Scroll to bottom only if new messages were actually added
        final existingIds = _messages.map((m) => m.id).toSet();
        final newMessages = messages.where((m) => !existingIds.contains(m.id));
        
        if (newMessages.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
      
      setState(() => _isLoadingMessages = false);
    } catch (e) {
      setState(() => _isLoadingMessages = false);
      print('❌ [RoomChat] Error loading messages: $e');
      // Don't show error for polling failures to avoid spam, but log it
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    
    return Scaffold(
      backgroundColor: isLight ? AppTheme.offWhite : AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.publicCode,
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            if (_ttlExpiration != null)
              Text(
                _getTtlText(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft()),
          onPressed: () => context.pop(),
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.shareNetwork()),
            onPressed: _shareRoom,
            tooltip: 'Copy room link',
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 8),
          if (!_roomSaved)
            IconButton(
              icon: Icon(PhosphorIcons.bookmarkSimple()),
              onPressed: _saveRoom,
              tooltip: 'Save room (+24h)',
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Icon(PhosphorIcons.dotsThreeVertical()),
            onSelected: _handleMenuAction,
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(PhosphorIcons.gear()),
                  title: const Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'close',
                child: ListTile(
                  leading: Icon(PhosphorIcons.x(), color: AppTheme.danger),
                  title: Text('Close Room', style: TextStyle(color: AppTheme.danger)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Goal Banner with glassmorphism
          if (_goal != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.glassContainer(
                isLight: isLight,
                opacity: 0.1,
                borderColor: theme.colorScheme.primary.withOpacity(0.3),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      PhosphorIcons.target(),
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Room Goal',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _goal!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          // Messages List
          Expanded(
            child: _isLoadingMessages && _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading messages...',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _buildMessageItem(_messages[index]),
                  ),
          ),
          
          // Rewrites Section
          if (_currentRewrites != null || _isGeneratingRewrites) _buildRewritesSection(),
          
          // Draft Input
          _buildDraftInput(),
        ],
      ),
    );
  }
  
  Widget _buildMessageItem(ChatMessage message) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final isUser = message.role == 'user';
    final isCurrentUser = message.authorSession == _sessionId;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Avatar with gradient
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: isUser 
                  ? (isCurrentUser ? AppTheme.primaryGradient : AppTheme.lavenderGradient)
                  : AppTheme.tealGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (isUser 
                      ? (isCurrentUser ? theme.colorScheme.primary : theme.colorScheme.secondary)
                      : theme.colorScheme.tertiary).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              isUser ? PhosphorIcons.user() : PhosphorIcons.magicWand(),
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          
          // Message Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with improved spacing
                Row(
                  children: [
                    Text(
                      isUser ? (isCurrentUser ? 'You' : 'Other') : 'BetterSaid',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isUser 
                            ? (isCurrentUser ? theme.colorScheme.primary : theme.colorScheme.secondary)
                            : theme.colorScheme.tertiary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outline.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatTime(message.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Message Text with glassmorphism
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.glassContainer(
                    isLight: isLight,
                    opacity: isUser ? 0.08 : 0.12,
                    blur: 12,
                    borderColor: isUser 
                        ? (isCurrentUser 
                            ? theme.colorScheme.primary.withOpacity(0.2)
                            : theme.colorScheme.secondary.withOpacity(0.2))
                        : theme.colorScheme.tertiary.withOpacity(0.2),
                  ),
                  child: Text(
                    message.content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                    ),
                  ),
                ),
                
                // Rewrites (if any) - only show to the message author
                if (message.rewrites != null && 
                    message.rewrites!.isNotEmpty && 
                    message.authorSession == _sessionId) ...[
                  const SizedBox(height: 12),
                  _buildMessageRewrites(message.rewrites!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMessageRewrites(List<RewriteResult> rewrites) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Rewrites:',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.tertiary,
            ),
          ),
          const SizedBox(height: 8),
          ...rewrites.map((rewrite) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStyleColor(rewrite.style, theme),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    rewrite.style.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rewrite.text,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  icon: Icon(PhosphorIcons.copy(), size: 16),
                  onPressed: () => _copyText(rewrite.text),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  Widget _buildRewritesSection() {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    
    // Handle loading state with enhanced design
    if (_isGeneratingRewrites) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.elevatedGlassContainer(
          isLight: isLight,
          opacity: 0.15,
          blur: 20,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.tealGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    PhosphorIcons.magicWand(),
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Generating AI Rewrites...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(
              color: theme.colorScheme.tertiary,
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Crafting calm, direct, and brief alternatives',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    // Handle empty/error state
    if (_currentRewrites == null || _currentRewrites!.rewrites.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get the selected rewrite
    final selectedRewrite = _currentRewrites!.rewrites.firstWhere(
      (r) => r.style == _selectedRewriteStyle,
      orElse: () => _currentRewrites!.rewrites.first,
    );
    
    return AnimatedContainer(
      duration: AppTheme.smoothTransition,
      curve: AppTheme.gentleEase,
      margin: const EdgeInsets.all(16),
      decoration: AppTheme.elevatedGlassContainer(
        isLight: isLight,
        opacity: 0.12,
        blur: 15,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.tealGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    PhosphorIcons.magicWand(),
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Rewrites',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Choose your communication style',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _currentRewrites = null),
                  icon: Icon(PhosphorIcons.x(), size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          
          // Enhanced Segmented Control
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: _currentRewrites!.rewrites.map((rewrite) {
                  final isSelected = _selectedRewriteStyle == rewrite.style;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: AppTheme.quickTransition,
                      curve: AppTheme.gentleEase,
                      child: InkWell(
                        onTap: () => setState(() => _selectedRewriteStyle = rewrite.style),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: isSelected 
                                ? _getStyleGradient(rewrite.style)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: _getStyleColor(rewrite.style, theme).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ] : null,
                          ),
                          child: Text(
                            rewrite.style.toUpperCase(),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: isSelected 
                                  ? Colors.white 
                                  : theme.colorScheme.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Selected Rewrite Text with animation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AnimatedSwitcher(
              duration: AppTheme.smoothTransition,
              child: Container(
                key: ValueKey(_selectedRewriteStyle),
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.glassContainer(
                  isLight: isLight,
                  opacity: 0.08,
                  blur: 10,
                  borderColor: _getStyleColor(_selectedRewriteStyle, theme).withOpacity(0.2),
                ),
                child: Text(
                  selectedRewrite.text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Enhanced Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Copy Button with glassmorphism
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: IconButton(
                    onPressed: () => _copyText(selectedRewrite.text),
                    icon: Icon(PhosphorIcons.copy()),
                    tooltip: 'Copy to clipboard',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Send Button with gradient
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: _getStyleGradient(_selectedRewriteStyle),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _getStyleColor(_selectedRewriteStyle, theme).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _sendRewrite(selectedRewrite.text),
                      icon: Icon(PhosphorIcons.paperPlaneRight(), size: 18),
                      label: const Text('Send Rewrite'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Notes with improved styling
          if (_currentRewrites!.notes != null && _currentRewrites!.notes!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      PhosphorIcons.info(),
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _currentRewrites!.notes!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
  Widget _buildDraftInput() {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.95),
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
        ),
      ),
      child: Column(
        children: [
          // Enhanced TextField with glassmorphism
          Container(
            decoration: AppTheme.glassContainer(
              isLight: isLight,
              opacity: 0.08,
              blur: 10,
            ),
            child: TextField(
              controller: _draftController,
              decoration: InputDecoration(
                hintText: 'Type your message here...',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.all(20),
              ),
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.5,
              ),
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(height: 16),
          
          // Enhanced Action Buttons
          Row(
            children: [
              // Primary Draft Button with gradient
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isGeneratingRewrites || _draftController.text.trim().isEmpty
                        ? null
                        : _generateRewrites,
                    icon: _isGeneratingRewrites
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(PhosphorIcons.magicWand(), size: 20),
                    label: Text(
                      _isGeneratingRewrites ? 'Generating...' : 'Draft',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Secondary Send Button with glassmorphism
              Container(
                decoration: AppTheme.glassContainer(
                  isLight: isLight,
                  opacity: 0.1,
                  blur: 10,
                  borderColor: theme.colorScheme.secondary.withOpacity(0.3),
                ),
                child: IconButton(
                  onPressed: _isSendingDraft || _draftController.text.trim().isEmpty
                      ? null
                      : _showSendConfirmation,
                  icon: _isSendingDraft
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.secondary,
                            ),
                          ),
                        )
                      : Icon(
                          PhosphorIcons.paperPlaneRight(),
                          size: 20,
                          color: theme.colorScheme.secondary,
                        ),
                  tooltip: 'Send without AI rewrites',
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Helper text
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                PhosphorIcons.lightbulb(),
                size: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tap "Draft" for calm, direct, and brief alternatives',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Color _getStyleColor(String style, ThemeData theme) {
    switch (style) {
      case 'calm':
        return theme.colorScheme.primary;
      case 'direct':
        return theme.colorScheme.secondary;
      case 'brief':
        return theme.colorScheme.tertiary;
      default:
        return theme.colorScheme.primary;
    }
  }
  
  LinearGradient _getStyleGradient(String style) {
    switch (style) {
      case 'calm':
        return AppTheme.primaryGradient;
      case 'direct':
        return AppTheme.lavenderGradient;
      case 'brief':
        return AppTheme.tealGradient;
      default:
        return AppTheme.primaryGradient;
    }
  }
  
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}d';
    }
  }
  
  String _getTtlText() {
    if (_ttlExpiration == null) return '';
    
    final now = DateTime.now();
    final remaining = _ttlExpiration!.difference(now);
    
    if (remaining.isNegative) {
      return 'Expired';
    } else if (remaining.inHours < 1) {
      return 'Expires in ${remaining.inMinutes}m';
    } else {
      return 'Expires in ${remaining.inHours}h';
    }
  }
  
  Future<void> _generateRewrites() async {
    // If session info is missing, try to initialize first
    if (_goal == null || _sessionId == null) {
      print('🔧 [RoomChat] Missing session info for rewrites, attempting to fix...');
      
      try {
        final storage = await ref.read(storageServiceAsyncProvider.future);
        
        // Try to get session ID from storage again
        if (_sessionId == null) {
          _sessionId = await storage.getSessionId(widget.publicCode);
        }
        
        // If still missing, auto-join
        if (_sessionId == null) {
          final apiClient = await ref.read(apiClientProvider.future);
          final joinResult = await apiClient.joinRoom(
            publicCode: widget.publicCode,
            displayName: 'Anonymous',
            secret: widget.secret!,
          );
          _sessionId = joinResult.sessionId;
          await storage.setSessionId(widget.publicCode, _sessionId!);
        }
        
        // Try to get goal from storage again
        if (_goal == null) {
          _goal = await storage.getRoomGoal(widget.publicCode);
        }
        
        // If still missing, there's an issue with room data
        if (_goal == null) {
          print('❌ [RoomChat] Unable to retrieve room goal');
          _showError('Unable to generate rewrites. Room information is missing.');
          return;
        }
        
        print('✅ [RoomChat] Session info recovered - Session ID: $_sessionId, Goal: $_goal');
      } catch (e) {
        print('❌ [RoomChat] Failed to recover session info: $e');
        _showError('Unable to generate rewrites. Please try refreshing the page.');
        return;
      }
    }
    
    setState(() => _isGeneratingRewrites = true);
    
    try {
      final apiClient = await ref.read(apiClientProvider.future);
      final rewrites = await apiClient.getRewrite(
        publicCode: widget.publicCode,
        sessionId: _sessionId!,
        goal: _goal!,
        draft: _draftController.text.trim(),
      );
      
      setState(() {
        _currentRewrites = rewrites;
        _selectedRewriteStyle = 'calm'; // Default to calm
        _isGeneratingRewrites = false;
      });
    } on SafetyBlock catch (safetyBlock) {
      setState(() => _isGeneratingRewrites = false);
      
      if (mounted) {
        context.push('/safety-pause', extra: {
          'blockedContent': _draftController.text,
          'resources': safetyBlock.resources,
        });
      }
    } catch (e) {
      setState(() => _isGeneratingRewrites = false);
      _showError('Failed to generate rewrites: $e');
    }
  }
  
  void _showSendConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              PhosphorIcons.warning(),
              color: Theme.of(context).colorScheme.error,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('Send Unfiltered Message?'),
          ],
        ),
        content: const Text(
          'You\'re about to send your message without using AI rewrites. This means it hasn\'t been optimized for better communication.\n\nAre you sure you want to send the original message?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _sendDraft();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Send Anyway'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendDraft() async {
    if (_sessionId == null) {
      _showError('Room not properly initialized');
      return;
    }
    
    setState(() => _isSendingDraft = true);
    
    try {
      final apiClient = await ref.read(apiClientProvider.future);
      await apiClient.sendDraft(
        publicCode: widget.publicCode,
        sessionId: _sessionId!,
        draft: _draftController.text.trim(),
      );
      
      _draftController.clear();
      setState(() {
        _isSendingDraft = false;
        _currentRewrites = null;
      });
      
      // Immediately load new messages
      await _loadMessages();
    } on SafetyBlock catch (safetyBlock) {
      setState(() => _isSendingDraft = false);
      
      if (mounted) {
        context.push('/safety-pause', extra: {
          'blockedContent': _draftController.text,
          'resources': safetyBlock.resources,
        });
      }
    } catch (e) {
      setState(() => _isSendingDraft = false);
      _showError('Failed to send message: $e');
    }
  }
  
  void _sendRewrite(String rewriteText) {
    _draftController.text = rewriteText;
    setState(() => _currentRewrites = null);
    _sendDraft();
  }
  
  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }
  
  void _shareRoom() {
    final roomLink = 'https://localhost:5000/c/${widget.publicCode}?secret=${widget.secret}';
    Clipboard.setData(ClipboardData(text: roomLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Room link copied to clipboard!'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveRoom() async {
    try {
      final apiClient = await ref.read(apiClientProvider.future);
      final newExpiration = await apiClient.saveRoom(publicCode: widget.publicCode);
      
      final storage = await ref.read(storageServiceAsyncProvider.future);
      await storage.setTtlExpiration(widget.publicCode, newExpiration);
      
      setState(() {
        _ttlExpiration = newExpiration;
        _roomSaved = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room saved for 24 more hours')),
      );
    } catch (e) {
      _showError('Failed to save room: $e');
    }
  }
  
  void _handleMenuAction(String action) {
    switch (action) {
      case 'settings':
        context.push('/settings');
        break;
      case 'close':
        _showCloseRoomDialog();
        break;
    }
  }
  
  void _showCloseRoomDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Room'),
        content: const Text(
          'This will permanently delete the room and all messages. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _closeRoom();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Close Room'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _closeRoom() async {
    try {
      final apiClient = await ref.read(apiClientProvider.future);
      await apiClient.closeRoom(publicCode: widget.publicCode);
      
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      _showError('Failed to close room: $e');
    }
  }
  
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}
