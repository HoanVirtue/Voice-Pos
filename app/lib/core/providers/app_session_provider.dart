import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Increments on every login / logout cycle.
/// All data providers watch this so they automatically rebuild (clearing
/// cached state) whenever the authenticated user changes.
final appSessionProvider = StateProvider<int>((ref) => 0);
