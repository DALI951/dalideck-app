// Unit C tests — Habits heatmap/streaks (lib/ui/weeks.dart) + quran hifz
// seeding in models.dart repair() (lib/ui/quran.dart consumes it).
//
// Plan asserts (UNIT C):
//   happy — habitStreak 5 consecutive days
//   edge  — completionRate 0.0 with no days in range,
//           heatmapData length = 7*weeksBack
//   extra — bestStreak, heatmap cell values/recovery counting, quran repair()
//           seeds the hifz map (currentPage/currentJuz/revisionJuz/
//           revisionLog/lastReadDate) plus quran['lastAyah'].
import 'package:flutter_test/flutter_test.dart';
import 'package:dalideck/models.dart';
import 'package:dalideck/ui/weeks.dart';

/// ISO date `daysAgo` days before today.
String _d(int daysAgo) => isoOf(DateTime.now().subtract(Duration(days: daysAgo)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('habitStreak', () {
    test('counts 5 consecutive days ending today', () {
      final h = Habit(uid())..days = [_d(0), _d(1), _d(2), _d(3), _d(4)];
      expect(habitStreak(h), 5);
    });

    test('ignores an older day across a gap', () {
      final h = Habit(uid())..days = [_d(0), _d(1), _d(2), _d(3), _d(4), _d(10)];
      expect(habitStreak(h), 5);
    });

    test('counts from yesterday when today is not marked', () {
      final h = Habit(uid())..days = [_d(1), _d(2), _d(3), _d(4), _d(5)];
      expect(habitStreak(h), 5);
    });

    test('breaks on a gap and returns 0 for no days', () {
      final h = Habit(uid())..days = [_d(0), _d(2), _d(3)];
      expect(habitStreak(h), 1); // only today counts; yesterday is missing
      expect(habitStreak(Habit(uid())), 0);
    });
  });

  group('completionRate', () {
    test('0.0 when there are no days at all', () {
      expect(completionRate(Habit(uid())), 0.0);
    });

    test('0.0 when the only completions are outside the window', () {
      expect(completionRate(Habit(uid())..days = [_d(40)]), 0.0);
      // A completion exactly `days` ago is out of range (diff < days).
      expect(completionRate(Habit(uid())..days = [_d(30)]), 0.0);
    });

    test('counts distinct dates inside the window', () {
      final h = Habit(uid())..days = [_d(0), _d(1), _d(2), _d(3), _d(4), _d(4)];
      expect(completionRate(h), closeTo(5 / 30, 1e-9));
    });

    test('honors the days parameter', () {
      final h = Habit(uid())..days = [_d(0), _d(1), _d(2), _d(3), _d(4), _d(4)];
      expect(completionRate(h, days: 7), closeTo(5 / 7, 1e-9));
    });
  });

  group('heatmapData', () {
    test('returns exactly 7*weeksBack cells', () {
      final h = Habit(uid())..days = [_d(0)];
      expect(heatmapData(h, 12).length, 84);
      expect(heatmapData(h, 5).length, 35);
      expect(heatmapData(h, 1).length, 7);
      expect(heatmapData(h, 0), isEmpty);
    });

    test('counts each completion at the right cell; ignores older dates', () {
      final now = DateTime.now();
      final oldest = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 7 * 12 + now.weekday - 1));
      final inside = isoOf(oldest.add(const Duration(days: 5)));
      final tooOld = isoOf(oldest.subtract(const Duration(days: 1)));
      final h = Habit(uid())..days = [inside, tooOld];

      final data = heatmapData(h, 12);
      expect(data.length, 84);
      expect(data[5], 1);
      expect(data.where((c) => c > 0).length, 1);
    });

    test('multiple check-ins on one date count up (recovery support)', () {
      final now = DateTime.now();
      final oldest = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 7 * 12 + now.weekday - 1));
      final inside = isoOf(oldest.add(const Duration(days: 5)));
      final h = Habit(uid())..days = [inside, inside];
      expect(heatmapData(h, 12)[5], 2);
    });
  });

  group('bestStreak', () {
    test('finds the 5-day run', () {
      final h = Habit(uid())..days = [_d(0), _d(1), _d(2), _d(3), _d(4), _d(20)];
      expect(bestStreak(h), 5);
    });

    test('a gap splits runs and only the longest counts', () {
      final h = Habit(uid())..days = [_d(0), _d(1), _d(2), _d(10), _d(11), _d(30)];
      expect(bestStreak(h), 3);
    });

    test('single day is 1 and empty is 0', () {
      expect(bestStreak(Habit(uid())..days = [_d(0)]), 1);
      expect(bestStreak(Habit(uid())), 0);
    });

    test('duplicate dates do not extend a streak', () {
      final h = Habit(uid())..days = [_d(0), _d(0), _d(1), _d(2)];
      expect(bestStreak(h), 3);
    });
  });

  group('totalDone', () {
    test('equals the number of recorded days', () {
      final h = Habit(uid())..days = [_d(0), _d(1), _d(2), _d(3), _d(4)];
      expect(totalDone(h), 5);
      expect(totalDone(Habit(uid())), 0);
    });
  });

  group('quran repair() hifz seeding', () {
    test('seeds the full hifz map + lastAyah when quran is empty', () {
      final s = AppState();
      s.quran = {};
      s.repair();
      final h = Map<String, dynamic>.from(s.quran['hifz'] as Map);
      expect(h['currentPage'], 1);
      expect(h['currentJuz'], 1);
      expect(h['revisionJuz'], isA<List>());
      expect(h['revisionJuz'] as List, isEmpty);
      expect(h['revisionLog'], isA<Map>());
      expect(h['revisionLog'] as Map, isEmpty);
      expect(h['lastReadDate'], '');
      expect(s.quran['lastAyah'], 1);
    });

    test('preserves existing hifz values untouched', () {
      final s = AppState();
      s.quran = {
        'khitma': 3,
        'cur': [1, 2],
        'log': {'1': '2026-01-01'},
        'hifz': <String, dynamic>{
          'currentPage': 17,
          'currentJuz': 3,
          'revisionJuz': <int>[5],
          'revisionLog': <String, dynamic>{'5': '2026-08-01'},
          'lastReadDate': '2026-09-01',
        },
        'lastAyah': 42,
      };
      s.repair();
      final h = Map<String, dynamic>.from(s.quran['hifz'] as Map);
      expect(h['currentPage'], 17);
      expect(h['currentJuz'], 3);
      expect(h['revisionJuz'], [5]);
      expect(h['revisionLog'], {'5': '2026-08-01'});
      expect(h['lastReadDate'], '2026-09-01');
      expect(s.quran['lastAyah'], 42);
      expect(s.quran['khitma'], 3);
    });

    test('backs-fill missing hifz keys when only some exist', () {
      final s = AppState();
      s.quran['hifz'] = {'currentPage': 9};
      s.repair();
      final h = Map<String, dynamic>.from(s.quran['hifz'] as Map);
      expect(h['currentPage'], 9);
      expect(h['currentJuz'], 1);
      expect(h['revisionJuz'] as List, isEmpty);
      expect(h['lastReadDate'], '');
      expect(s.quran['lastAyah'], 1);
    });

    test('fromJson migration path seeds hifz for old payloads', () {
      // Old/partial synced payload without any hifz data:
      final back = AppState.fromJson({
        'v': 2,
        'quran': <String, dynamic>{'khitma': 1, 'cur': <int>[], 'log': <String, dynamic>{}},
      });
      final h = Map<String, dynamic>.from(back.quran['hifz'] as Map);
      expect(h['currentPage'], 1);
      expect(h['currentJuz'], 1);
      expect(h['revisionJuz'] as List, isEmpty);
      expect(h['lastReadDate'], '');
      expect(back.quran['lastAyah'], 1);
    });

    test('fromJson with no quran key still seeds hifz', () {
      final back = AppState.fromJson({'v': 2});
      expect(
        Map<String, dynamic>.from(back.quran['hifz'] as Map)['currentPage'],
        1,
      );
      expect(back.quran['lastAyah'], 1);
    });
  });
}