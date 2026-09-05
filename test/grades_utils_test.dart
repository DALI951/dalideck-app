// Unit A tests — School grades utils (lib/ui/grades_utils.dart)
//
// Plan asserts (UNIT A):
//   happy — moyenne() weighted across 2 subjects with different coeffs
//   edge  — neededOnNextTest returns 0 when target exceeded,
//           >max (21) when impossible, and the correct value otherwise
import 'package:flutter_test/flutter_test.dart';
import 'package:dalideck/models.dart';
import 'package:dalideck/ui/grades_utils.dart';

/// Fixture: subject A (coeff 2) with 14/20 and subject B (coeff 1) with
/// 10/20, both term 1. Returns (state, subjectAId, subjectBId).
(AppState, String, String) _twoSubjects() {
  final s = AppState();
  final a = Subject(uid())..name = 'Maths'..coeff = 2;
  final b = Subject(uid())..name = 'English'..coeff = 1;
  s.subjects = [a, b];
  s.grades = [
    Grade(uid())..subjectId = a.id..score = 14..max = 20..term = 1,
    Grade(uid())..subjectId = b.id..score = 10..max = 20..term = 1,
  ];
  return (s, a.id, b.id);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('moyenne', () {
    test('weights grades by subject coefficient across 2 subjects', () {
      final (s, _, _) = _twoSubjects();
      // (14/20*2 + 10/20*1) / (2+1) * 20 = 12.666… — NOT the unweighted 12.5
      expect(moyenne(s), closeTo(12.666666666, 0.001));
      expect(moyenne(s), isNot(closeTo(12.5, 0.0001)));
    });

    test('returns 0.0 when there are no grades', () {
      final s = AppState();
      s.repair();
      expect(moyenne(s), 0.0);
    });

    test('skips malformed grades with max == 0 (no division by zero)', () {
      final s = AppState();
      s.repair();
      final a = Subject(uid())..name = 'Maths'..coeff = 2;
      s.subjects = [a];
      s.grades.add(Grade(uid())..subjectId = a.id..score = 10..max = 0);
      expect(moyenne(s), 0.0);
      expect(subjectMoyenne(s, a.id), 0.0);
    });

    test('uses default coeff 1 for grades with unknown/absent subject', () {
      final s = AppState();
      s.repair();
      s.grades.add(Grade(uid())..score = 10..max = 20); // subjectId == null
      expect(moyenne(s), closeTo(10.0, 0.001));
    });

    test('honors the term filter', () {
      final (s, a, _) = _twoSubjects();
      s.grades.add(Grade(uid())..subjectId = a..score = 8..max = 20..term = 2);
      expect(moyenne(s, term: 1), closeTo(12.666666666, 0.001));
      expect(moyenne(s, term: 2), closeTo(8.0, 0.001));
      expect(moyenne(s), closeTo(10.8, 0.001));
    });

    test('subjectMoyenne isolates a single subject', () {
      final (s, a, b) = _twoSubjects();
      expect(subjectMoyenne(s, a), closeTo(14.0, 0.001));
      expect(subjectMoyenne(s, b), closeTo(10.0, 0.001));
      expect(subjectMoyenne(s, 'unknown-subject'), 0.0);
    });

    test('allSubjectMoyennes returns an entry for every subject', () {
      final (s, a, b) = _twoSubjects();
      // Rebuild the two graded subjects from their ids, plus one subject
      // that has no grades yet.
      final c = Subject(uid())..name = 'Physics'..coeff = 3;
      s.subjects = [
        Subject(a)..name = 'Maths'..coeff = 2,
        Subject(b)..name = 'English'..coeff = 1,
        c,
      ];
      final m = allSubjectMoyennes(s);
      expect(m.keys.toSet(), {a, b, c.id});
      expect(m[a], closeTo(14.0, 0.001));
      expect(m[b], closeTo(10.0, 0.001));
      expect(m[c.id], 0.0);
    });
  });

  group('neededOnNextTest', () {
    test('returns 0 when already above the target', () {
      final (s, a, _) = _twoSubjects(); // current moyenne ≈ 12.667
      expect(neededOnNextTest(s, a, 12.0), 0);
      expect(neededOnNextTest(s, a, 12.5), 0);
    });

    test('returns the exact score needed otherwise (cross-checked)', () {
      final (s, a, _) = _twoSubjects();
      final needed = neededOnNextTest(s, a, 14.0);
      expect(needed, closeTo(16.0, 0.001)); // Maths coeff 2, English 10/20 coeff 1
      // Applying the computed grade must land exactly on the target:
      s.grades.add(Grade(uid())..subjectId = a..score = needed..max = 20..term = 1);
      expect(moyenne(s), closeTo(14.0, 0.001));
    });

    test('works for the lower-coeff subject too', () {
      final (s, _, b) = _twoSubjects();
      final needed = neededOnNextTest(s, b, 14.0);
      expect(needed, closeTo(18.0, 0.001));
      s.grades.add(Grade(uid())..subjectId = b..score = needed..max = 20..term = 1);
      expect(moyenne(s), closeTo(14.0, 0.001));
    });

    test('returns 21 when the target is impossible', () {
      final (s, a, _) = _twoSubjects();
      expect(neededOnNextTest(s, a, 20.0), 21);
    });

    test('returns 21 when impossible even for the small-coeff subject', () {
      final (s, _, b) = _twoSubjects();
      expect(neededOnNextTest(s, b, 20.0), 21);
    });

    test('with no grades the required score equals the target', () {
      final s = AppState();
      s.repair();
      final a = Subject(uid())..name = 'Maths'..coeff = 2;
      s.subjects = [a];
      expect(neededOnNextTest(s, a.id, 14.0), closeTo(14.0, 0.001));
    });

    test('respects the term filter', () {
      final (s, a, _) = _twoSubjects();
      s.grades.add(Grade(uid())..subjectId = a..score = 8..max = 20..term = 2);
      // Term 1 view is unchanged → same 16.0 as the base fixture.
      expect(neededOnNextTest(s, a, 14.0, term: 1), closeTo(16.0, 0.001));
      // All-terms view is dragged down by the 8/20: reaching 14 with one
      // more Maths test would need 22/20 → impossible.
      expect(neededOnNextTest(s, a, 14.0), 21);
    });
  });
}