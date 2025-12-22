import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/memory_models.dart';

/// Gemini-powered smart summarization service
class GeminiSummarizationService {
  static final GeminiSummarizationService _instance = GeminiSummarizationService._internal();
  factory GeminiSummarizationService() => _instance;
  GeminiSummarizationService._internal();

  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static const String _model = 'gemini-1.5-flash';
  
  String? _apiKey;
  final Map<String, dynamic> _cache = {};
  static const Duration _cacheExpiry = Duration(hours: 1);

  /// Initialize the service with API key
  Future<void> initialize({String? apiKey}) async {
    _apiKey = apiKey ?? const String.fromEnvironment('GEMINI_API_KEY');
    
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Gemini API key not provided');
    }
    
    if (kDebugMode) {
      print('🤖 GeminiSummarizationService initialized');
    }
  }

  /// Summarize a list of memory chunks
  Future<MemoryOperationResult<MemoryChunk>> summarizeMemoryChunks(
    List<MemoryChunk> chunks, {
    int maxLength = 300,
    bool preserveImportantDetails = true,
    SummarizationStyle style = SummarizationStyle.concise,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      if (chunks.isEmpty) {
        return MemoryOperationResult.failure('No chunks to summarize');
      }

      // Check cache first
      final cacheKey = _generateCacheKey(chunks, maxLength, style);
      final cachedResult = _getCachedSummary(cacheKey);
      if (cachedResult != null) {
        stopwatch.stop();
        return MemoryOperationResult.success(
          cachedResult,
          executionTime: stopwatch.elapsed,
          metadata: {'operation': 'summarize_cached', 'cache_hit': true},
        );
      }

      // Prepare content for summarization
      final content = _prepareContentForSummarization(chunks, preserveImportantDetails);
      
      // Create summarization prompt
      final prompt = _createSummarizationPrompt(
        content,
        chunks,
        maxLength,
        style,
        preserveImportantDetails,
      );

      // Call Gemini API
      final summaryText = await _callGeminiAPI(prompt);
      
      // Create summary chunk
      final summaryChunk = _createSummaryChunk(chunks, summaryText, style);
      
      // Cache the result
      _cacheSummary(cacheKey, summaryChunk);
      
      stopwatch.stop();
      
      return MemoryOperationResult.success(
        summaryChunk,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'summarize_chunks',
          'original_chunks': chunks.length,
          'original_length': content.length,
          'summary_length': summaryText.length,
          'compression_ratio': summaryText.length / content.length,
          'style': style.name,
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to summarize chunks: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Summarize a single long memory chunk
  Future<MemoryOperationResult<MemoryChunk>> summarizeMemoryChunk(
    MemoryChunk chunk, {
    int maxLength = 200,
    SummarizationStyle style = SummarizationStyle.concise,
  }) async {
    return await summarizeMemoryChunks([chunk], maxLength: maxLength, style: style);
  }

  /// Create session summary from memory chunks
  Future<MemoryOperationResult<SessionSummary>> createSessionSummary(
    List<MemoryChunk> sessionChunks, {
    bool includeOutcomes = true,
    bool includeDecisions = true,
    bool includeContextCarryover = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      if (sessionChunks.isEmpty) {
        return MemoryOperationResult.failure('No chunks to summarize for session');
      }

      // Prepare session content
      final content = _prepareSessionContentForSummary(sessionChunks);
      
      // Create session summary prompt
      final prompt = _createSessionSummaryPrompt(
        content,
        sessionChunks,
        includeOutcomes,
        includeDecisions,
        includeContextCarryover,
      );

      // Call Gemini API
      final summaryResponse = await _callGeminiAPI(prompt);
      
      // Parse the structured response
      final sessionSummary = _parseSessionSummaryResponse(summaryResponse, sessionChunks);
      
      stopwatch.stop();
      
      return MemoryOperationResult.success(
        sessionSummary,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'create_session_summary',
          'chunk_count': sessionChunks.length,
          'session_duration': _calculateSessionDuration(sessionChunks).inMinutes,
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to create session summary: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Extract key insights from memory chunks
  Future<MemoryOperationResult<List<String>>> extractKeyInsights(
    List<MemoryChunk> chunks, {
    int maxInsights = 5,
    InsightType type = InsightType.general,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      if (chunks.isEmpty) {
        return MemoryOperationResult.failure('No chunks to analyze for insights');
      }

      final content = _prepareContentForInsightExtraction(chunks, type);
      final prompt = _createInsightExtractionPrompt(content, maxInsights, type);
      
      final response = await _callGeminiAPI(prompt);
      final insights = _parseInsightsResponse(response);
      
      stopwatch.stop();
      
      return MemoryOperationResult.success(
        insights,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'extract_insights',
          'chunk_count': chunks.length,
          'insight_type': type.name,
          'insights_found': insights.length,
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to extract insights: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Generate contextual tags for memory chunks
  Future<MemoryOperationResult<List<String>>> generateContextualTags(
    MemoryChunk chunk, {
    int maxTags = 8,
    bool includeEmotionalTags = true,
    bool includeTopicalTags = true,
    bool includeAdhdTags = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final prompt = _createTagGenerationPrompt(
        chunk,
        maxTags,
        includeEmotionalTags,
        includeTopicalTags,
        includeAdhdTags,
      );
      
      final response = await _callGeminiAPI(prompt);
      final tags = _parseTagsResponse(response);
      
      stopwatch.stop();
      
      return MemoryOperationResult.success(
        tags,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'generate_tags',
          'chunk_id': chunk.id,
          'tags_generated': tags.length,
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to generate tags: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Private helper methods

  String _prepareContentForSummarization(List<MemoryChunk> chunks, bool preserveImportantDetails) {
    final buffer = StringBuffer();
    
    // Sort chunks chronologically
    final sortedChunks = List<MemoryChunk>.from(chunks);
    sortedChunks.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    for (int i = 0; i < sortedChunks.length; i++) {
      final chunk = sortedChunks[i];
      
      buffer.writeln('--- Chunk ${i + 1} (${chunk.type.name}) ---');
      buffer.writeln('Time: ${chunk.timestamp.toIso8601String()}');
      
      if (preserveImportantDetails) {
        buffer.writeln('Importance: ${chunk.importanceScore.toStringAsFixed(2)}');
        buffer.writeln('Priority: ${chunk.priority.name}');
        if (chunk.tags.isNotEmpty) {
          buffer.writeln('Tags: ${chunk.tags.join(', ')}');
        }
      }
      
      buffer.writeln('Content: ${chunk.content}');
      buffer.writeln();
    }
    
    return buffer.toString();
  }

  String _createSummarizationPrompt(
    String content,
    List<MemoryChunk> chunks,
    int maxLength,
    SummarizationStyle style,
    bool preserveImportantDetails,
  ) {
    final styleDescription = _getStyleDescription(style);
    final chunkTypes = chunks.map((c) => c.type.name).toSet().join(', ');
    
    return '''
You are an AI assistant specialized in creating concise, ADHD-friendly summaries of conversation and task memory chunks.

CONTEXT:
- You are summarizing ${chunks.length} memory chunks of types: $chunkTypes
- The user has ADHD, so the summary should be clear, structured, and easy to scan
- Maximum summary length: $maxLength characters
- Style: $styleDescription
- Preserve important details: $preserveImportantDetails

CONTENT TO SUMMARIZE:
$content

INSTRUCTIONS:
1. Create a ${style.name} summary that captures the essential information
2. Use bullet points or numbered lists for better readability
3. Highlight key decisions, outcomes, and action items
4. Preserve important context that might be needed later
5. Use clear, simple language suitable for someone with ADHD
6. If there are multiple topics, organize them clearly
7. Include emotional context if relevant (stress, excitement, frustration)
8. Keep the summary under $maxLength characters

SUMMARY:''';
  }

  String _createSessionSummaryPrompt(
    String content,
    List<MemoryChunk> chunks,
    bool includeOutcomes,
    bool includeDecisions,
    bool includeContextCarryover,
  ) {
    return '''
You are an AI assistant creating a structured session summary for an ADHD user.

SESSION CONTENT:
$content

Create a JSON response with the following structure:
{
  "keyPoints": "Main points from the session in 2-3 sentences",
  "mainTopics": ["topic1", "topic2", "topic3"],
  "outcomes": ${includeOutcomes ? '{"outcome1": "description", "outcome2": "description"}' : '{}'},
  "completionScore": 0.8,
  "importantDecisions": ${includeDecisions ? '["decision1", "decision2"]' : '[]'},
  "contextCarryover": ${includeContextCarryover ? '{"key1": "value1", "key2": "value2"}' : '{}'}
}

Guidelines:
- Keep keyPoints concise but informative
- mainTopics should be 3-5 key themes
- completionScore should reflect how much was accomplished (0.0-1.0)
- importantDecisions should capture key choices made
- contextCarryover should include information needed for future sessions
- Use ADHD-friendly language (clear, direct, actionable)

JSON Response:''';
  }

  String _createInsightExtractionPrompt(String content, int maxInsights, InsightType type) {
    final typeDescription = _getInsightTypeDescription(type);
    
    return '''
You are an AI assistant specialized in extracting insights for ADHD users.

CONTENT:
$content

Extract up to $maxInsights key insights of type: $typeDescription

Format as a JSON array of strings:
["insight1", "insight2", "insight3"]

Focus on:
- Patterns in behavior or thinking
- Productivity insights
- Emotional patterns
- Decision-making patterns
- Time management insights
- Energy level patterns
- Attention and focus patterns

Make insights actionable and ADHD-friendly.

JSON Response:''';
  }

  String _createTagGenerationPrompt(
    MemoryChunk chunk,
    int maxTags,
    bool includeEmotionalTags,
    bool includeTopicalTags,
    bool includeAdhdTags,
  ) {
    return '''
Generate relevant tags for this memory chunk:

Type: ${chunk.type.name}
Content: ${chunk.content}
Existing tags: ${chunk.tags.join(', ')}

Generate up to $maxTags tags in JSON array format:
["tag1", "tag2", "tag3"]

Include:
${includeTopicalTags ? '- Topical tags (what the content is about)' : ''}
${includeEmotionalTags ? '- Emotional tags (mood, feelings, stress level)' : ''}
${includeAdhdTags ? '- ADHD-specific tags (hyperfocus, distraction, energy, etc.)' : ''}

Make tags:
- Specific and useful for retrieval
- Consistent with existing tag vocabulary
- ADHD-relevant when applicable

JSON Response:''';
  }

  Future<String> _callGeminiAPI(String prompt) async {
    if (_apiKey == null) {
      throw Exception('Gemini API key not initialized');
    }

    final url = Uri.parse('$_baseUrl/models/$_model:generateContent?key=$_apiKey');
    
    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.3,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 1024,
      },
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
        }
      ]
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
    }

    final responseData = jsonDecode(response.body);
    
    if (responseData['candidates'] == null || responseData['candidates'].isEmpty) {
      throw Exception('No response from Gemini API');
    }

    final content = responseData['candidates'][0]['content']['parts'][0]['text'];
    return content as String;
  }

  MemoryChunk _createSummaryChunk(List<MemoryChunk> originalChunks, String summaryText, SummarizationStyle style) {
    final firstChunk = originalChunks.first;
    final lastChunk = originalChunks.last;
    
    // Calculate average importance and attention weight
    final avgImportance = originalChunks.map((c) => c.importanceScore).reduce((a, b) => a + b) / originalChunks.length;
    final avgAttention = originalChunks.map((c) => c.attentionWeight).reduce((a, b) => a + b) / originalChunks.length;
    
    // Combine all tags
    final allTags = <String>{};
    for (final chunk in originalChunks) {
      allTags.addAll(chunk.tags);
    }
    allTags.add('summary');
    allTags.add(style.name);
    
    return MemoryChunk(
      id: '', // Will be assigned when stored
      userId: firstChunk.userId,
      sessionId: firstChunk.sessionId,
      type: MemoryType.summary,
      content: summaryText,
      metadata: {
        'summary_style': style.name,
        'original_chunk_count': originalChunks.length,
        'original_chunk_ids': originalChunks.map((c) => c.id).toList(),
        'time_span_start': firstChunk.timestamp.toIso8601String(),
        'time_span_end': lastChunk.timestamp.toIso8601String(),
        'compression_ratio': summaryText.length / originalChunks.fold(0, (sum, c) => sum + c.content.length),
      },
      tags: allTags.toList(),
      relevanceScore: avgImportance,
      attentionWeight: avgAttention,
      timestamp: DateTime.now(),
      lastAccessed: DateTime.now(),
      priority: _calculateSummaryPriority(originalChunks),
    );
  }

  SessionSummary _parseSessionSummaryResponse(String response, List<MemoryChunk> chunks) {
    try {
      // Clean the response to extract JSON
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}') + 1;
      final jsonString = response.substring(jsonStart, jsonEnd);
      
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      
      return SessionSummary(
        keyPoints: data['keyPoints'] as String? ?? '',
        mainTopics: List<String>.from(data['mainTopics'] ?? []),
        outcomes: Map<String, dynamic>.from(data['outcomes'] ?? {}),
        completionScore: (data['completionScore'] as num?)?.toDouble() ?? 0.0,
        importantDecisions: List<String>.from(data['importantDecisions'] ?? []),
        contextCarryover: Map<String, dynamic>.from(data['contextCarryover'] ?? {}),
      );
    } catch (error) {
      // Fallback to simple parsing if JSON parsing fails
      return SessionSummary(
        keyPoints: response.length > 500 ? '${response.substring(0, 500)}...' : response,
        mainTopics: _extractTopicsFromText(response),
        outcomes: {},
        completionScore: 0.5,
        importantDecisions: [],
        contextCarryover: {},
      );
    }
  }

  List<String> _parseInsightsResponse(String response) {
    try {
      final jsonStart = response.indexOf('[');
      final jsonEnd = response.lastIndexOf(']') + 1;
      final jsonString = response.substring(jsonStart, jsonEnd);
      
      final insights = jsonDecode(jsonString) as List;
      return insights.map((i) => i.toString()).toList();
    } catch (error) {
      // Fallback parsing
      return response.split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.replaceAll(RegExp(r'^[-*•]\s*'), '').trim())
          .where((line) => line.isNotEmpty)
          .take(5)
          .toList();
    }
  }

  List<String> _parseTagsResponse(String response) {
    try {
      final jsonStart = response.indexOf('[');
      final jsonEnd = response.lastIndexOf(']') + 1;
      final jsonString = response.substring(jsonStart, jsonEnd);
      
      final tags = jsonDecode(jsonString) as List;
      return tags.map((t) => t.toString().toLowerCase()).toList();
    } catch (error) {
      // Fallback parsing
      return response.split(',')
          .map((tag) => tag.trim().replaceAll(RegExp(r'["\[\]]'), ''))
          .where((tag) => tag.isNotEmpty)
          .take(8)
          .toList();
    }
  }

  String _prepareSessionContentForSummary(List<MemoryChunk> chunks) {
    final buffer = StringBuffer();
    
    // Group chunks by type for better organization
    final chunksByType = <MemoryType, List<MemoryChunk>>{};
    for (final chunk in chunks) {
      chunksByType[chunk.type] ??= [];
      chunksByType[chunk.type]!.add(chunk);
    }
    
    for (final entry in chunksByType.entries) {
      buffer.writeln('=== ${entry.key.name.toUpperCase()} ===');
      
      final sortedChunks = entry.value;
      sortedChunks.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      for (final chunk in sortedChunks) {
        buffer.writeln('${chunk.timestamp.toIso8601String()}: ${chunk.content}');
      }
      buffer.writeln();
    }
    
    return buffer.toString();
  }

  String _prepareContentForInsightExtraction(List<MemoryChunk> chunks, InsightType type) {
    final relevantChunks = chunks.where((chunk) {
      switch (type) {
        case InsightType.productivity:
          return chunk.type == MemoryType.task || chunk.type == MemoryType.hyperfocus;
        case InsightType.emotional:
          return chunk.metadata.containsKey('mood') || chunk.tags.any((t) => t.contains('emotion'));
        case InsightType.behavioral:
          return chunk.type == MemoryType.decision || chunk.type == MemoryType.interruption;
        case InsightType.general:
          return true;
      }
    }).toList();
    
    return relevantChunks.map((c) => '${c.timestamp}: ${c.content}').join('\n');
  }

  String _getStyleDescription(SummarizationStyle style) {
    switch (style) {
      case SummarizationStyle.concise:
        return 'Very brief, bullet-point style summary focusing on key facts';
      case SummarizationStyle.detailed:
        return 'Comprehensive summary preserving important details and context';
      case SummarizationStyle.actionable:
        return 'Focus on action items, decisions, and next steps';
      case SummarizationStyle.narrative:
        return 'Story-like summary that flows naturally and preserves sequence';
    }
  }

  String _getInsightTypeDescription(InsightType type) {
    switch (type) {
      case InsightType.productivity:
        return 'Insights about work patterns, productivity, and task management';
      case InsightType.emotional:
        return 'Insights about emotional patterns, mood, and stress';
      case InsightType.behavioral:
        return 'Insights about behavior patterns and decision-making';
      case InsightType.general:
        return 'General insights about patterns and trends';
    }
  }

  MemoryPriority _calculateSummaryPriority(List<MemoryChunk> chunks) {
    final priorities = chunks.map((c) => c.priority.index).toList();
    final avgPriority = priorities.reduce((a, b) => a + b) / priorities.length;
    
    if (avgPriority >= 4) return MemoryPriority.critical;
    if (avgPriority >= 3) return MemoryPriority.high;
    if (avgPriority >= 2) return MemoryPriority.normal;
    if (avgPriority >= 1) return MemoryPriority.low;
    return MemoryPriority.archive;
  }

  Duration _calculateSessionDuration(List<MemoryChunk> chunks) {
    if (chunks.isEmpty) return Duration.zero;
    
    chunks.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return chunks.last.timestamp.difference(chunks.first.timestamp);
  }

  List<String> _extractTopicsFromText(String text) {
    // Simple topic extraction - in production, use more sophisticated NLP
    final words = text.toLowerCase().split(RegExp(r'\W+'));
    final commonWords = {'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could', 'should', 'may', 'might', 'can', 'this', 'that', 'these', 'those'};
    
    final wordCounts = <String, int>{};
    for (final word in words) {
      if (word.length > 3 && !commonWords.contains(word)) {
        wordCounts[word] = (wordCounts[word] ?? 0) + 1;
      }
    }
    
    final sortedWords = wordCounts.entries.toList();
    sortedWords.sort((a, b) => b.value.compareTo(a.value));
    
    return sortedWords.take(5).map((e) => e.key).toList();
  }

  String _generateCacheKey(List<MemoryChunk> chunks, int maxLength, SummarizationStyle style) {
    final chunkIds = chunks.map((c) => c.id).join(',');
    return 'summary_${chunkIds.hashCode}_${maxLength}_${style.name}';
  }

  MemoryChunk? _getCachedSummary(String cacheKey) {
    final cached = _cache[cacheKey];
    if (cached != null) {
      final cacheTime = cached['timestamp'] as DateTime;
      if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
        return cached['summary'] as MemoryChunk;
      } else {
        _cache.remove(cacheKey);
      }
    }
    return null;
  }

  void _cacheSummary(String cacheKey, MemoryChunk summary) {
    _cache[cacheKey] = {
      'summary': summary,
      'timestamp': DateTime.now(),
    };
    
    // Limit cache size
    if (_cache.length > 100) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }
  }

  /// Dispose the service
  void dispose() {
    _cache.clear();
  }
}

/// Summarization styles
enum SummarizationStyle {
  concise,
  detailed,
  actionable,
  narrative,
}

/// Insight types
enum InsightType {
  productivity,
  emotional,
  behavioral,
  general,
}