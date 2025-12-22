import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../design_tokens.dart';
import '../../../state/notion_provider.dart';
import '../models/notion_models.dart';

/// Floating quick capture button for Notion
class NotionQuickCaptureButton extends ConsumerWidget {
  final VoidCallback? onPressed;
  final bool mini;

  const NotionQuickCaptureButton({
    super.key,
    this.onPressed,
    this.mini = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(notionConnectionProvider);
    
    return connection.when(
      data: (conn) {
        if (!conn.isConnected) return const SizedBox.shrink();
        
        return FloatingActionButton(
          onPressed: onPressed ?? () => _showQuickCaptureModal(context, ref),
          mini: mini,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.note_add),
        ).animate()
          .scale(delay: 300.ms, duration: 300.ms, curve: Curves.easeOutBack)
          .fadeIn(delay: 300.ms);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showQuickCaptureModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotionQuickCaptureModal(),
    );
  }
}

/// Quick capture modal for creating Notion content
class NotionQuickCaptureModal extends ConsumerStatefulWidget {
  const NotionQuickCaptureModal({super.key});

  @override
  ConsumerState<NotionQuickCaptureModal> createState() => _NotionQuickCaptureModalState();
}

class _NotionQuickCaptureModalState extends ConsumerState<NotionQuickCaptureModal> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  
  NotionTemplate? _selectedTemplate;
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableTemplates = ref.watch(availableTemplatesProvider);
    final captureState = ref.watch(notionQuickCaptureProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacingMd),
            child: Row(
              children: [
                Icon(
                  Icons.note_add,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: DesignTokens.spacingSm),
                Text(
                  'Quick Capture to Notion',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          const Divider(),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(DesignTokens.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Template Selection
                  _buildTemplateSelection(availableTemplates),
                  const SizedBox(height: DesignTokens.spacingLg),
                  
                  // Title Input
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Enter a title for your note...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spacingMd),
                  
                  // Content Input
                  TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      hintText: 'What\'s on your mind?',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.edit_note),
                    ),
                    maxLines: 5,
                  ),
                  const SizedBox(height: DesignTokens.spacingMd),
                  
                  // Tags Input
                  TextField(
                    controller: _tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Tags (optional)',
                      hintText: 'adhd, productivity, ideas',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tag),
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spacingLg),
                  
                  // Error Display
                  if (captureState.error != null)
                    Container(
                      padding: const EdgeInsets.all(DesignTokens.spacingSm),
                      decoration: BoxDecoration(
                        color: DesignTokens.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                        border: Border.all(color: DesignTokens.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: DesignTokens.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              captureState.error!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: DesignTokens.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Actions
          Container(
            padding: const EdgeInsets.all(DesignTokens.spacingMd),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: DesignTokens.spacingSm),
                Expanded(
                  child: FilledButton(
                    onPressed: _isCreating || _titleController.text.isEmpty 
                        ? null 
                        : _createNote,
                    child: _isCreating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateSelection(List<Map<String, dynamic>> availableTemplates) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Template (optional)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: DesignTokens.spacingSm),
        Text(
          'Choose a template for structured ADHD-focused content',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: DesignTokens.spacingMd),
        
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // No template option
            _buildTemplateChip(
              context,
              'Quick Note',
              '📝',
              _selectedTemplate == null,
              () => setState(() => _selectedTemplate = null),
            ),
            
            // Template options
            ...availableTemplates.take(6).map((templateData) {
              final template = templateData['template'] as NotionTemplate;
              return _buildTemplateChip(
                context,
                templateData['name'] as String,
                templateData['icon'] as String,
                _selectedTemplate == template,
                () => setState(() => _selectedTemplate = template),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildTemplateChip(
    BuildContext context,
    String name,
    String icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              name,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    ).animate(target: isSelected ? 1 : 0)
      .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05));
  }

  Future<void> _createNote() async {
    if (_titleController.text.isEmpty) return;

    setState(() => _isCreating = true);

    try {
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      if (_selectedTemplate != null) {
        // Create from template
        await ref.read(notionQuickCaptureProvider.notifier).createFromTemplate(
          userId: 'current_user_id', // Get from auth
          template: _selectedTemplate!,
          customData: {
            'title': _titleController.text,
            'content': _contentController.text,
            'tags': tags,
          },
        );
      } else {
        // Create quick note
        await ref.read(notionQuickCaptureProvider.notifier).createQuickNote(
          userId: 'current_user_id', // Get from auth
          title: _titleController.text,
          content: _contentController.text,
          tags: tags,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(_selectedTemplate != null 
                    ? 'Template created in Notion!' 
                    : 'Note created in Notion!'),
              ],
            ),
            backgroundColor: DesignTokens.success,
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to create: $e')),
              ],
            ),
            backgroundColor: DesignTokens.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }
}

/// Compact quick capture widget for integration in other screens
class NotionQuickCaptureWidget extends ConsumerWidget {
  final String? placeholder;
  final VoidCallback? onTap;

  const NotionQuickCaptureWidget({
    super.key,
    this.placeholder,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(notionConnectionProvider);
    
    return connection.when(
      data: (conn) {
        if (!conn.isConnected) return const SizedBox.shrink();
        
        return GestureDetector(
          onTap: onTap ?? () => _showQuickCaptureModal(context, ref),
          child: Container(
            padding: const EdgeInsets.all(DesignTokens.spacingMd),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.note_add,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: DesignTokens.spacingSm),
                Expanded(
                  child: Text(
                    placeholder ?? 'Quick capture to Notion...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ).animate()
          .fadeIn(delay: 200.ms)
          .slideY(begin: 0.2, end: 0, delay: 200.ms);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showQuickCaptureModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotionQuickCaptureModal(),
    );
  }
}