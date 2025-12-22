import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design_tokens.dart';
import '../core/components/np_app_bar.dart';
import '../core/components/np_card.dart';
import '../core/components/np_button.dart';
import '../state/notion_provider.dart';
import '../core/notion/models/notion_models.dart';

class NotionLibraryScreen extends ConsumerStatefulWidget {
  const NotionLibraryScreen({super.key});

  @override
  ConsumerState<NotionLibraryScreen> createState() => _NotionLibraryScreenState();
}

class _NotionLibraryScreenState extends ConsumerState<NotionLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  NotionTemplate? _selectedTemplate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notionState = ref.watch(notionProvider);

    return Scaffold(
      appBar: NpAppBar(
        title: 'Notion Library',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(notionProvider.notifier).refreshPages();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/notion-settings');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab Bar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Recent', icon: Icon(Icons.access_time)),
              Tab(text: 'Templates', icon: Icon(Icons.dashboard_customize)),
              Tab(text: 'Synced', icon: Icon(Icons.sync)),
              Tab(text: 'Search', icon: Icon(Icons.search)),
            ],
          ),

          // Connection Status Banner
          if (!notionState.isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(DesignTokens.spacingMd),
              color: Colors.orange.shade100,
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade700),
                  const SizedBox(width: DesignTokens.spacingSm),
                  Expanded(
                    child: Text(
                      'Notion not connected. Connect in Settings to access your pages.',
                      style: TextStyle(color: Colors.orange.shade700),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/notion-settings'),
                    child: const Text('Connect'),
                  ),
                ],
              ),
            ),

          // Search Bar (visible on Search tab)
          if (_tabController.index == 3)
            Padding(
              padding: const EdgeInsets.all(DesignTokens.spacingMd),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search Notion pages...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                  if (value.isNotEmpty) {
                    ref.read(notionProvider.notifier).searchPages(value);
                  }
                },
              ),
            ),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRecentTab(notionState),
                _buildTemplatesTab(notionState),
                _buildSyncedTab(notionState),
                _buildSearchTab(notionState),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePageDialog(),
        icon: const Icon(Icons.add),
        label: const Text('New Page'),
      ),
    );
  }

  Widget _buildRecentTab(NotionState state) {
    if (!state.isConnected) {
      return _buildNotConnectedView();
    }

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final recentPages = state.pages.take(20).toList();

    if (recentPages.isEmpty) {
      return _buildEmptyView(
        icon: Icons.access_time,
        title: 'No Recent Pages',
        subtitle: 'Your recently accessed Notion pages will appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      itemCount: recentPages.length,
      itemBuilder: (context, index) {
        final page = recentPages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: DesignTokens.spacingMd),
          child: _buildPageCard(page),
        );
      },
    );
  }

  Widget _buildTemplatesTab(NotionState state) {
    const templates = NotionTemplate.values;

    return ListView.builder(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: DesignTokens.spacingMd),
          child: _buildTemplateCard(template),
        );
      },
    );
  }

  Widget _buildSyncedTab(NotionState state) {
    if (!state.isConnected) {
      return _buildNotConnectedView();
    }

    final syncedPages = state.pages.where((p) => p.isSynced).toList();

    if (syncedPages.isEmpty) {
      return _buildEmptyView(
        icon: Icons.sync,
        title: 'No Synced Pages',
        subtitle: 'Pages synced with Firestore will appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      itemCount: syncedPages.length,
      itemBuilder: (context, index) {
        final page = syncedPages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: DesignTokens.spacingMd),
          child: _buildPageCard(page, showSyncStatus: true),
        );
      },
    );
  }

  Widget _buildSearchTab(NotionState state) {
    if (!state.isConnected) {
      return _buildNotConnectedView();
    }

    if (_searchQuery.isEmpty) {
      return _buildEmptyView(
        icon: Icons.search,
        title: 'Search Notion',
        subtitle: 'Enter a search term to find your Notion pages.',
      );
    }

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final searchResults = state.searchResults;

    if (searchResults.isEmpty) {
      return _buildEmptyView(
        icon: Icons.search_off,
        title: 'No Results',
        subtitle: 'No pages found for "$_searchQuery".',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final page = searchResults[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: DesignTokens.spacingMd),
          child: _buildPageCard(page),
        );
      },
    );
  }

  Widget _buildPageCard(NotionPage page, {bool showSyncStatus = false}) {
    return NpCard(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            _getPageIcon(page.type),
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          page.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (page.excerpt.isNotEmpty)
              Text(
                page.excerpt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: DesignTokens.spacingXs),
            Row(
              children: [
                Text(
                  _formatDate(page.lastEditedTime),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (showSyncStatus) ...[
                  const SizedBox(width: DesignTokens.spacingSm),
                  Icon(
                    page.isSynced ? Icons.sync : Icons.sync_disabled,
                    size: 16,
                    color: page.isSynced ? Colors.green : Colors.grey,
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handlePageAction(value, page),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'open',
              child: ListTile(
                leading: Icon(Icons.open_in_new),
                title: Text('Open in Notion'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'sync',
              child: ListTile(
                leading: Icon(Icons.sync),
                title: Text('Sync to Firestore'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'duplicate',
              child: ListTile(
                leading: Icon(Icons.copy),
                title: Text('Duplicate'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        onTap: () => _openPage(page),
      ),
    );
  }

  Widget _buildTemplateCard(NotionTemplate template) {
    return NpCard(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(
            _getTemplateIcon(template),
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(
          _getTemplateDisplayName(template),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_getTemplateDescription(template)),
        trailing: NpButton(
          label: 'Create',
          type: NpButtonType.primary,
          onPressed: () => _createFromTemplate(template),
        ),
        onTap: () => _createFromTemplate(template),
      ),
    );
  }

  Widget _buildNotConnectedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.link_off,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          Text(
            'Notion Not Connected',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: DesignTokens.spacingSm),
          Text(
            'Connect your Notion account to access your pages.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DesignTokens.spacingLg),
          NpButton(
            label: 'Connect Notion',
            type: NpButtonType.primary,
            onPressed: () => Navigator.pushNamed(context, '/notion-settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: DesignTokens.spacingSm),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showCreatePageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Page'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Page Title',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                // Handle title input
              },
            ),
            const SizedBox(height: DesignTokens.spacingMd),
            DropdownButtonFormField<NotionTemplate>(
              decoration: const InputDecoration(
                labelText: 'Template (Optional)',
              ),
              initialValue: _selectedTemplate,
              items: NotionTemplate.values.map((template) {
                return DropdownMenuItem(
                  value: template,
                  child: Text(_getTemplateDisplayName(template)),
                );
              }).toList(),
              onChanged: (template) {
                setState(() => _selectedTemplate = template);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          NpButton(
            label: 'Create',
            type: NpButtonType.primary,
            onPressed: () {
              Navigator.pop(context);
              // Handle page creation
            },
          ),
        ],
      ),
    );
  }

  void _handlePageAction(String action, NotionPage page) async {
    final notionNotifier = ref.read(notionProvider.notifier);

    switch (action) {
      case 'open':
        await notionNotifier.openPageInNotion(page.id);
        break;
      case 'sync':
        await notionNotifier.syncPageToFirestore(page.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Page synced to Firestore')),
          );
        }
        break;
      case 'duplicate':
        await notionNotifier.duplicatePage(page.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Page duplicated')),
          );
        }
        break;
    }
  }

  void _openPage(NotionPage page) {
    // Open page details or in Notion app
    ref.read(notionProvider.notifier).openPageInNotion(page.id);
  }

  void _createFromTemplate(NotionTemplate template) async {
    try {
      await ref.read(notionProvider.notifier).createFromTemplate(template);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created ${_getTemplateDisplayName(template)} page'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create page: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  IconData _getPageIcon(String type) {
    switch (type.toLowerCase()) {
      case 'database':
        return Icons.table_chart;
      case 'page':
        return Icons.description;
      default:
        return Icons.note;
    }
  }

  IconData _getTemplateIcon(NotionTemplate template) {
    switch (template) {
      case NotionTemplate.dailyReflection:
        return Icons.today;
      case NotionTemplate.hyperfocusSession:
        return Icons.psychology;
      case NotionTemplate.contextSnapshot:
        return Icons.camera_alt;
      case NotionTemplate.energyTracking:
        return Icons.battery_full;
      case NotionTemplate.weeklyReview:
        return Icons.calendar_view_week;
      case NotionTemplate.goalSetting:
        return Icons.flag;
      case NotionTemplate.decisionLog:
        return Icons.account_tree;
      case NotionTemplate.resourceLibrary:
        return Icons.library_books;
      case NotionTemplate.moodTracker:
        return Icons.mood;
      case NotionTemplate.medicationLog:
        return Icons.medication;
      case NotionTemplate.appointmentNotes:
        return Icons.event_note;
      case NotionTemplate.achievementLog:
        return Icons.emoji_events;
      case NotionTemplate.strategyNotes:
        return Icons.lightbulb;
      case NotionTemplate.sensoryEnvironment:
        return Icons.sensors;
      case NotionTemplate.transitionRitual:
        return Icons.swap_horiz;
    }
  }

  String _getTemplateDisplayName(NotionTemplate template) {
    switch (template) {
      case NotionTemplate.dailyReflection:
        return 'Daily Reflection';
      case NotionTemplate.hyperfocusSession:
        return 'Hyperfocus Session';
      case NotionTemplate.contextSnapshot:
        return 'Context Snapshot';
      case NotionTemplate.energyTracking:
        return 'Energy Tracking';
      case NotionTemplate.weeklyReview:
        return 'Weekly Review';
      case NotionTemplate.goalSetting:
        return 'Goal Setting';
      case NotionTemplate.decisionLog:
        return 'Decision Log';
      case NotionTemplate.resourceLibrary:
        return 'Resource Library';
      case NotionTemplate.moodTracker:
        return 'Mood Tracker';
      case NotionTemplate.medicationLog:
        return 'Medication Log';
      case NotionTemplate.appointmentNotes:
        return 'Appointment Notes';
      case NotionTemplate.achievementLog:
        return 'Achievement Log';
      case NotionTemplate.strategyNotes:
        return 'Strategy Notes';
      case NotionTemplate.sensoryEnvironment:
        return 'Sensory Environment';
      case NotionTemplate.transitionRitual:
        return 'Transition Ritual';
    }
  }

  String _getTemplateDescription(NotionTemplate template) {
    switch (template) {
      case NotionTemplate.dailyReflection:
        return 'Reflect on your day, challenges, and wins';
      case NotionTemplate.hyperfocusSession:
        return 'Document deep work sessions and outcomes';
      case NotionTemplate.contextSnapshot:
        return 'Capture current context for later restoration';
      case NotionTemplate.energyTracking:
        return 'Track energy levels throughout the day';
      case NotionTemplate.weeklyReview:
        return 'Weekly planning and reflection template';
      case NotionTemplate.goalSetting:
        return 'Set and track ADHD-friendly goals';
      case NotionTemplate.decisionLog:
        return 'Log decisions to combat decision fatigue';
      case NotionTemplate.resourceLibrary:
        return 'Organize helpful resources and tools';
      case NotionTemplate.moodTracker:
        return 'Track mood patterns and triggers';
      case NotionTemplate.medicationLog:
        return 'Log medication effects and timing';
      case NotionTemplate.appointmentNotes:
        return 'Structured notes for appointments';
      case NotionTemplate.achievementLog:
        return 'Celebrate wins and progress';
      case NotionTemplate.strategyNotes:
        return 'Document effective strategies';
      case NotionTemplate.sensoryEnvironment:
        return 'Track optimal sensory conditions';
      case NotionTemplate.transitionRitual:
        return 'Plan smooth transitions between tasks';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}