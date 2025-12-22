import 'package:flutter_riverpod/flutter_riverpod.dart';

// State provider for the selected navigation index
final navigationIndexProvider = StateProvider<int>((ref) => 0);
