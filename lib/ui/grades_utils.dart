import '../models.dart';

/// Overall weighted moyenne calibrated to /20.
/// Formula: sum(score/max * coeff) / sum(coeff) * 20
double moyenne(AppState s, {int? term}) {
  num sumWeighted = 0;
  num sumCoeff = 0;
  for (final g in s.grades) {
    if (term != null && g.term != term) continue;
    if (g.max == 0) continue;
    final subj = _findSubject(s, g.subjectId);
    final coeff = subj?.coeff ?? 1;
    sumWeighted += (g.score / g.max) * coeff;
    sumCoeff += coeff;
  }
  if (sumCoeff == 0) return 0;
  return (sumWeighted / sumCoeff) * 20;
}

/// Per-subject moyenne calibrated to /20.
double subjectMoyenne(AppState s, String subjectId, {int? term}) {
  num sumWeighted = 0;
  num sumCoeff = 0;
  for (final g in s.grades) {
    if (g.subjectId != subjectId) continue;
    if (term != null && g.term != term) continue;
    if (g.max == 0) continue;
    final subj = _findSubject(s, g.subjectId);
    final coeff = subj?.coeff ?? 1;
    sumWeighted += (g.score / g.max) * coeff;
    sumCoeff += coeff;
  }
  if (sumCoeff == 0) return 0;
  return (sumWeighted / sumCoeff) * 20;
}

/// Needed score on next test (/20 basis) to reach [targetAvg].
/// Returns 0 if already above target, 21 if impossible.
double neededOnNextTest(AppState s, String subjectId, double targetAvg, {int? term}) {
  final subj = _findSubject(s, subjectId);
  final coeff = (subj?.coeff ?? 1).toDouble();

  // Current overall moyenne
  final currentAvg = moyenne(s, term: term);
  if (currentAvg >= targetAvg) return 0;

  // Total coeff across ALL grades (with term filter)
  num totalCoeff = 0;
  for (final g in s.grades) {
    if (term != null && g.term != term) continue;
    if (g.max == 0) continue;
    final c = _findSubject(s, g.subjectId)?.coeff ?? 1;
    totalCoeff += c;
  }

  // Sum of existing weighted terms for this subject (all grades of this subject)
  num thisSubjSum = 0;
  for (final g in s.grades) {
    if (g.subjectId != subjectId) continue;
    if (term != null && g.term != term) continue;
    if (g.max == 0) continue;
    thisSubjSum += (g.score / g.max) * coeff;
  }

  // Overall sum excluding this subject
  num overallSum = 0;
  for (final g in s.grades) {
    if (g.subjectId == subjectId) continue;
    if (term != null && g.term != term) continue;
    if (g.max == 0) continue;
    final c = _findSubject(s, g.subjectId)?.coeff ?? 1;
    overallSum += (g.score / g.max) * c;
  }

  // After adding one more test on this subject:
  // newAvg = (overallSum + thisSubjSum + x) / (totalCoeff + coeff) * 20 = targetAvg
  // x = (targetAvg / 20) * (totalCoeff + coeff) - overallSum - thisSubjSum
  final x = (targetAvg / 20) * (totalCoeff + coeff) - overallSum - thisSubjSum;

  // x is the weighted contribution of the new test: x = (newScore / 20) * coeff
  // So newScore = x / coeff * 20
  if (coeff == 0) return 21;
  final newScore = x / coeff * 20;

  if (newScore <= 0) return 0;
  if (newScore > 20) return 21;
  return newScore;
}

/// All subject moyennes keyed by subjectId.
Map<String, double> allSubjectMoyennes(AppState s, {int? term}) {
  final result = <String, double>{};
  for (final subj in s.subjects) {
    result[subj.id] = subjectMoyenne(s, subj.id, term: term);
  }
  return result;
}

Subject? _findSubject(AppState s, String? id) {
  if (id == null || id.isEmpty) return null;
  for (final subj in s.subjects) {
    if (subj.id == id) return subj;
  }
  return null;
}
