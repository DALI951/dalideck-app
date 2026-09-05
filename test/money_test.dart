// Unit B tests — Money: budgets + recurring auto-apply (lib/models.dart,
// lib/ui/money.dart)
//
// Plan asserts (UNIT B):
//   happy — BudgetCategory limit 50000 + entries totaling 40000 → >=80% warning
//   edge  — RecurringEntry dayOfMonth=31 in a 30-day month does not auto-apply;
//           happy path creates exactly ONE entry and stamps lastApplied once.
//
// Notes on approach:
//  * The 80% warning rule lives inline in the private _BudgetTile widget
//    (money.dart) — there is no exported helper. `budgetRatio` below mirrors
//    that computation exactly, and the two widget tests at the bottom assert
//    the REAL widget renders the warning text at 80% / over-100%.
//  * applyRecurring() uses DateTime.now() with no injectable clock, so tests
//    express date-dependent expectations as invariants of the actual date.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalideck/models.dart';
import 'package:dalideck/ui/money.dart';

/// Mirror of money.dart _BudgetTile: spent = sum of this-month 'out' entries
/// matching the budget category; ratio = spent / limit (0 when limit <= 0).
double budgetRatio(AppState s, BudgetCategory b, String ym) {
  var spent = 0;
  for (final m in s.money) {
    if (m.date.startsWith(ym) && m.type == 'out' && m.cat == b.cat) {
      spent += m.amount;
    }
  }
  return b.limit > 0 ? spent / b.limit : 0.0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('budget spending warning (limit 50000, rule from money.dart)', () {
    final ym = todayStr().substring(0, 7);
    final prevMonth = isoOf(dateOf(todayStr()).subtract(const Duration(days: 31)));

    AppState stateWithSpending({required int spent}) {
      final s = AppState.seed()..repair();
      s.budgets.add(BudgetCategory(uid())..cat = 'food'..limit = 50000);
      s.money.add(MoneyEntry(uid())
        ..type = 'out'
        ..amount = spent
        ..cat = 'food'
        ..date = todayStr());
      return s;
    }

    test('80% spending shows the >=80% warning (limit 50000, spent 40000)', () {
      final s = stateWithSpending(spent: 40000);
      final ratio = budgetRatio(s, s.budgets.single, ym);
      expect(ratio, closeTo(0.8, 1e-9));
      expect(ratio >= 0.8 && ratio < 1.0, isTrue,
          reason: '80%..100% must land in the orange near-limit band');
    });

    test('100%+ spending flags over-budget', () {
      final s = stateWithSpending(spent: 60000);
      final ratio = budgetRatio(s, s.budgets.single, ym);
      expect(ratio, closeTo(1.2, 1e-9));
      expect(ratio >= 1.0, isTrue);
    });

    test('income, other categories and other months never count as spending', () {
      final s = stateWithSpending(spent: 40000);
      final b = s.budgets.single;
      s.money.add(MoneyEntry(uid())
        ..type = 'in'
        ..amount = 40000
        ..cat = 'food'
        ..date = todayStr());
      s.money.add(MoneyEntry(uid())
        ..type = 'out'
        ..amount = 99999
        ..cat = 'tech'
        ..date = todayStr());
      s.money.add(MoneyEntry(uid())
        ..type = 'out'
        ..amount = 99999
        ..cat = 'food'
        ..date = prevMonth);
      expect(prevMonth.substring(0, 7), isNot(ym));
      expect(budgetRatio(s, b, ym), closeTo(0.8, 1e-9));
    });

    test('limit 0 yields ratio 0 (no division by zero)', () {
      final s = AppState.seed()..repair();
      final b = BudgetCategory(uid())..cat = 'food'..limit = 0;
      s.budgets.add(b);
      s.money.add(MoneyEntry(uid())
        ..type = 'out'
        ..amount = 40000
        ..cat = 'food'
        ..date = todayStr());
      expect(budgetRatio(s, b, ym), 0.0);
    });

    testWidgets('real MoneyView shows "Near limit" at exactly 80%', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final s = AppState.seed()..repair();
      s.budgets.add(BudgetCategory(uid())..cat = 'food'..limit = 50000);
      s.money.add(MoneyEntry(uid())
        ..type = 'out'
        ..amount = 40000
        ..cat = 'food'
        ..date = todayStr());
      await tester.pumpWidget(MaterialApp(home: MoneyView(store: Store(s))));
      await tester.pump();
      expect(find.text('Near limit'), findsOneWidget);
      expect(find.text('40 of 50'), findsOneWidget); // fmtM(40000) of fmtM(50000)
    });

    testWidgets('real MoneyView shows "Over budget" past the limit', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final s = AppState.seed()..repair();
      s.budgets.add(BudgetCategory(uid())..cat = 'food'..limit = 50000);
      s.money.add(MoneyEntry(uid())
        ..type = 'out'
        ..amount = 60000
        ..cat = 'food'
        ..date = todayStr());
      await tester.pumpWidget(MaterialApp(home: MoneyView(store: Store(s))));
      await tester.pump();
      expect(find.text('Over budget'), findsOneWidget);
    });
  });

  group('applyRecurring (AppState)', () {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    test('happy path: dayOfMonth today creates exactly ONE entry and stamps '
        'lastApplied exactly once', () {
      final s = AppState()..repair();
      final r = RecurringEntry(uid())
        ..type = 'out'
        ..amount = 15000
        ..cat = 'food'
        ..note = 'Snacks'
        ..dayOfMonth = now.day
        ..active = true;
      s.recurring.add(r);
      expect(s.money, isEmpty);

      s.applyRecurring();
      expect(s.money.length, 1);
      final e = s.money.single;
      expect(e.type, 'out');
      expect(e.amount, 15000);
      expect(e.cat, 'food');
      expect(e.note, 'Snacks');
      expect(e.date, todayStr());
      expect(r.lastApplied, todayStr());

      // A second pass in the same month must not duplicate the entry.
      s.applyRecurring();
      expect(s.money.length, 1);
      expect(r.lastApplied, todayStr());
    });

    test('two due entries each apply exactly once', () {
      final s = AppState()..repair();
      s.recurring.addAll([
        RecurringEntry(uid())..type = 'out'..amount = 1000..dayOfMonth = now.day,
        RecurringEntry(uid())..type = 'in'..amount = 2000..dayOfMonth = now.day,
      ]);
      s.applyRecurring();
      s.applyRecurring();
      expect(s.money.length, 2);
    });

    test('edge: dayOfMonth=31 never applies in a month with fewer than 31 days',
        () {
      final s = AppState()..repair();
      final r = RecurringEntry(uid())..dayOfMonth = 31..active = true;
      s.recurring.add(r);
      s.applyRecurring();
      final guardSkips = 31 > daysInMonth; // e.g. always true in 30-day months
      if (guardSkips) {
        // The plan's exact edge: in a 30-day month the entry must not fire
        // and must not be stamped.
        expect(s.money, isEmpty);
        expect(r.lastApplied, isNull);
      }
      // Full invariant: in a 31-day month it only fires on the 31st itself.
      expect(s.money.length, (guardSkips || now.day != 31) ? 0 : 1);
    });

    test('dayOfMonth that already passed this month stays pending', () {
      final s = AppState()..repair();
      final r = RecurringEntry(uid())..dayOfMonth = 1..active = true;
      s.recurring.add(r);
      s.applyRecurring();
      // Fires only when the run date IS the 1st; otherwise stays pending.
      expect(s.money.length, now.day == 1 ? 1 : 0);
      if (now.day != 1) {
        expect(r.lastApplied, isNull);
      }
    });

    test('invalid dayOfMonth 0 never fires', () {
      final s = AppState()..repair();
      s.recurring.add(RecurringEntry(uid())..dayOfMonth = 0..active = true);
      s.applyRecurring();
      expect(s.money, isEmpty);
    });

    test('inactive entries never auto-apply even on the matching day', () {
      final s = AppState()..repair();
      final r = RecurringEntry(uid())
        ..dayOfMonth = now.day
        ..active = false;
      s.recurring.add(r);
      s.applyRecurring();
      expect(s.money, isEmpty);
      expect(r.lastApplied, isNull);
    });

    test('entries already applied this month (lastApplied) are skipped', () {
      final s = AppState()..repair();
      final r = RecurringEntry(uid())
        ..dayOfMonth = now.day
        ..active = true
        ..lastApplied = todayStr();
      s.recurring.add(r);
      s.applyRecurring();
      expect(s.money, isEmpty);
    });
  });
}