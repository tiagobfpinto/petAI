import 'package:flutter/foundation.dart';

const int _testCoinsTarget = 260;
int? _maxRawSeen;
int _offset = 0;

/// Temporary helper: in debug builds keep a baseline coin amount for UI testing.
/// It lifts low balances up to [_testCoinsTarget] the first time, but will drop
/// back down once the backend sends a higher real balance (so purchases don't
/// inflate the total). Remove once real coin seeding is wired on the backend.
int applyTestCoins(int rawCoins) {
  if (!kDebugMode) return rawCoins;

  // Track the highest raw value we've seen to avoid compounding offsets.
  if (_maxRawSeen == null || rawCoins > _maxRawSeen!) {
    _maxRawSeen = rawCoins;
    _offset = (_testCoinsTarget - _maxRawSeen!).clamp(0, _testCoinsTarget);
  }

  return rawCoins + _offset;
}
