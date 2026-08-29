import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalideck/main.dart';
import 'package:dalideck/models.dart';
import 'package:dalideck/store.dart';
import 'package:dalideck/sync.dart';
import 'package:dalideck/ui/school.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uid format mirrors web', () {
    final a = uid();
    expect(a.startsWith('x'), isTrue);
    expect(a.length, greaterThan(3));
  });

  test('jsonSer is deterministic and sorted', () {
    final m = {'b': 1, 'a': [3, 1, 2], 'c': 'x"y'};
    final s1 = jsonSer(m);
    final s2 = jsonSer({'a': [3, 1, 2], 'b': 1, 'c': 'x"y'});
    expect(s1, s2);
    expect(s1.contains('"a":'), isTrue);
    expect(s1.contains('"b":'), isTrue);
    expect(s1.contains('"c":"x\\"y"'), isTrue);
  });

  test('state roundtrip keeps money/cells/exams', () {
    final s = AppState.seed();
    s.money.add(MoneyEntry(uid())
      ..type = 'out'
      ..amount = 2500
      ..cat = 'school'
      ..date = todayStr());
    s.exams.add(Exam(uid())
      ..title = 'Maths test'
      ..subjectId = s.subjects.first.id
      ..date = addDaysStr(todayStr(), 5));
    if (s.periods.isNotEmpty) {
      s.cells['${s.periods.first.id}:0'] = s.subjects.first.id;
    }
    syncRevisionList(s);

    final back = AppState.fromJson((jsonOf(s)));
    expect(back.money.length, 1);
    expect(back.money.first.amount, 2500);
    expect(back.exams.first.title, 'Maths test');
    expect(back.cells.length, 1);
    expect(back.revision.where((r) => r.offset == 7).length, 1);
    expect(back.periods.length, s.periods.length);
  });

  testWidgets('boots and lands on Today', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await loadStore();
    final sync = SyncEngine(store);
    await tester.pumpWidget(DalideckApp(store: store, sync: sync));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Today'), findsWidgets);
  });
}

// tiny helper to get a JSON map
Map<String, dynamic> jsonOf(AppState s) =>
    Map<String, dynamic>.from(s.toJson());