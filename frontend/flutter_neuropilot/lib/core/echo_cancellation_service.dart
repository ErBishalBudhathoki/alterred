import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Service for software-based echo cancellation and audio fingerprinting.
///
/// This service helps prevent the system from responding to its own TTS output
/// by tracking what was spoken and filtering out similar audio patterns.
///
/// Features:
/// - Audio fingerprinting: Tracks recent TTS outputs for comparison
/// - Pattern matching: Detects if STT input matches recent TTS output
/// - Cooldown management: Enforces delays after TTS playback
/// - Silent marker detection: Can detect embedded markers in audio
/// - Platform AEC integration: Works alongside WebRTC/native AEC
class EchoCancellationService {
  /// Singleton instance
  static final EchoCancellationService _instance = EchoCancellationService._internal();
  factory EchoCancellationService() => _instance;
  EchoCancellationService._internal();

  /// Recent TTS outputs for fingerprinting (circular buffer)
  final Queue<_TtsFingerprint> _recentTts = Queue();
  
  /// Maximum number of TTS outputs to track
  static const int _maxFingerprints = 10;
  
  /// Minimum time (ms) to wait after TTS ends before accepting STT input
  static const int _minCooldownMs = 2000;
  
  /// Extended cooldown for longer TTS outputs
  static const int _extendedCooldownMs = 3500;
  
  /// Threshold for word overlap ratio to consider as echo
  static const double _echoThreshold = 0.4;
  
  /// Silent markers that may be embedded in TTS output
  /// These are phrases that indicate system-generated speech
  static const List<String> _silentMarkers = [
    'neuropilot says',
    'assistant response',
    'system message',
    'auto generated',
  ];
  
  /// Last TTS end timestamp
  DateTime? _lastTtsEnd;
  
  /// Current TTS text being spoken
  String? _currentTtsText;
  
  /// Whether TTS is currently playing
  bool _isSpeaking = false;
  
  /// Statistics for debugging
  int _totalFiltered = 0;
  int _totalPassed = 0;

  /// Records the start of TTS playback
  void onTtsStart(String text) {
    _isSpeaking = true;
    _currentTtsText = text;
    debugPrint('[EchoCancellation] TTS started: "${text.substring(0, text.length.clamp(0, 50))}..."');
  }

  /// Records the end of TTS playback and creates a fingerprint
  void onTtsEnd() {
    _isSpeaking = false;
    _lastTtsEnd = DateTime.now();
    
    if (_currentTtsText != null && _currentTtsText!.isNotEmpty) {
      final fingerprint = _TtsFingerprint(
        text: _currentTtsText!,
        timestamp: _lastTtsEnd!,
        wordSet: _extractWords(_currentTtsText!),
        phrases: _extractPhrases(_currentTtsText!),
      );
      
      _recentTts.addLast(fingerprint);
      
      // Keep buffer size limited
      while (_recentTts.length > _maxFingerprints) {
        _recentTts.removeFirst();
      }
      
      debugPrint('[EchoCancellation] TTS ended, fingerprint created. Buffer size: ${_recentTts.length}');
    }
    
    _currentTtsText = null;
  }

  /// Checks if the given STT input is likely an echo of recent TTS output
  /// 
  /// Returns true if the input should be filtered out
  bool isLikelyEcho(String sttInput) {
    if (sttInput.trim().isEmpty) return false;
    
    // Check if we're still in cooldown period
    if (_isSpeaking) {
      debugPrint('[EchoCancellation] Filtering: TTS still playing');
      _totalFiltered++;
      return true;
    }
    
    if (_lastTtsEnd != null) {
      final msSinceTts = DateTime.now().difference(_lastTtsEnd!).inMilliseconds;
      if (msSinceTts < _minCooldownMs) {
        debugPrint('[EchoCancellation] Filtering: In cooldown period (${msSinceTts}ms < ${_minCooldownMs}ms)');
        _totalFiltered++;
        return true;
      }
    }
    
    // Check for silent markers (system-generated speech indicators)
    final inputLower = sttInput.toLowerCase();
    for (final marker in _silentMarkers) {
      if (inputLower.contains(marker)) {
        debugPrint('[EchoCancellation] Filtering: Contains silent marker "$marker"');
        _totalFiltered++;
        return true;
      }
    }
    
    // Check against current TTS text
    if (_currentTtsText != null && _matchesText(sttInput, _currentTtsText!)) {
      debugPrint('[EchoCancellation] Filtering: Matches current TTS');
      _totalFiltered++;
      return true;
    }
    
    // Check against recent fingerprints
    final inputWords = _extractWords(sttInput);
    final inputPhrases = _extractPhrases(sttInput);
    
    for (final fp in _recentTts) {
      // Skip old fingerprints (older than 30 seconds)
      if (DateTime.now().difference(fp.timestamp).inSeconds > 30) continue;
      
      // Check word overlap
      final overlap = _calculateWordOverlap(inputWords, fp.wordSet);
      if (overlap >= _echoThreshold) {
        debugPrint('[EchoCancellation] Filtering: Word overlap ${(overlap * 100).toStringAsFixed(1)}% with recent TTS');
        _totalFiltered++;
        return true;
      }
      
      // Check phrase matching
      if (_hasPhraseMatch(inputPhrases, fp.phrases)) {
        debugPrint('[EchoCancellation] Filtering: Phrase match with recent TTS');
        _totalFiltered++;
        return true;
      }
      
      // Check direct containment
      if (_matchesText(sttInput, fp.text)) {
        debugPrint('[EchoCancellation] Filtering: Direct match with recent TTS');
        _totalFiltered++;
        return true;
      }
    }
    
    _totalPassed++;
    debugPrint('[EchoCancellation] Passed: "$sttInput" (filtered=$_totalFiltered, passed=$_totalPassed)');
    return false;
  }

  /// Filters echo words from STT input and returns cleaned text
  String filterEchoWords(String sttInput) {
    if (sttInput.trim().isEmpty) return '';
    
    final inputWords = sttInput.toLowerCase().split(RegExp(r'\s+'));
    final echoWords = <String>{};
    
    // Collect all echo words from recent TTS
    for (final fp in _recentTts) {
      if (DateTime.now().difference(fp.timestamp).inSeconds > 30) continue;
      echoWords.addAll(fp.wordSet);
    }
    
    if (_currentTtsText != null) {
      echoWords.addAll(_extractWords(_currentTtsText!));
    }
    
    // Filter out echo words, keeping only novel words
    final novelWords = inputWords.where((w) => 
      w.length >= 2 && !echoWords.contains(w.toLowerCase())
    ).toList();
    
    return novelWords.join(' ');
  }

  /// Returns the recommended cooldown time in milliseconds
  int getRecommendedCooldown() {
    if (_recentTts.isEmpty) return _minCooldownMs;
    
    final lastFp = _recentTts.last;
    final wordCount = lastFp.wordSet.length;
    
    // Longer TTS outputs need longer cooldown
    if (wordCount > 50) return _extendedCooldownMs;
    if (wordCount > 20) return (_minCooldownMs + _extendedCooldownMs) ~/ 2;
    return _minCooldownMs;
  }

  /// Clears all fingerprints (call when starting a new session)
  void reset() {
    _recentTts.clear();
    _currentTtsText = null;
    _lastTtsEnd = null;
    _isSpeaking = false;
    debugPrint('[EchoCancellation] Reset (session stats: filtered=$_totalFiltered, passed=$_totalPassed)');
    _totalFiltered = 0;
    _totalPassed = 0;
  }
  
  /// Returns statistics about echo cancellation performance
  Map<String, int> getStats() {
    return {
      'filtered': _totalFiltered,
      'passed': _totalPassed,
      'fingerprintCount': _recentTts.length,
    };
  }

  /// Extracts significant words from text
  Set<String> _extractWords(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3)
        .toSet();
  }

  /// Extracts common phrases for matching
  Set<String> _extractPhrases(String text) {
    final phrases = <String>{};
    final clean = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    
    // Common echo-prone phrases
    final patterns = [
      'timer set', 'time is up', 'focus session', 'starting focus',
      'body double', 'check in', 'checking in', 'how are you',
      'still working', 'great job', 'keep going', 'you got this',
      'listening', 'here with you', 'im here', "i'm here",
      'halfway point', 'percent complete', 'seconds remaining',
      'minute timer', 'minutes remaining', 'task selected',
    ];
    
    for (final pattern in patterns) {
      if (clean.contains(pattern)) {
        phrases.add(pattern);
      }
    }
    
    return phrases;
  }

  /// Calculates word overlap ratio between two word sets
  double _calculateWordOverlap(Set<String> input, Set<String> reference) {
    if (input.isEmpty || reference.isEmpty) return 0.0;
    final intersection = input.intersection(reference).length;
    return intersection / input.length;
  }

  /// Checks if any phrases match
  bool _hasPhraseMatch(Set<String> inputPhrases, Set<String> refPhrases) {
    return inputPhrases.intersection(refPhrases).isNotEmpty;
  }

  /// Checks if input text matches reference text
  bool _matchesText(String input, String reference) {
    final inputNorm = input.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final refNorm = reference.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
    
    if (inputNorm.isEmpty || refNorm.isEmpty) return false;
    
    // Direct containment
    if (refNorm.contains(inputNorm)) return true;
    if (inputNorm.contains(refNorm) && refNorm.length > 15) return true;
    
    return false;
  }
}

/// Fingerprint of a TTS output for echo detection
class _TtsFingerprint {
  final String text;
  final DateTime timestamp;
  final Set<String> wordSet;
  final Set<String> phrases;

  _TtsFingerprint({
    required this.text,
    required this.timestamp,
    required this.wordSet,
    required this.phrases,
  });
}
