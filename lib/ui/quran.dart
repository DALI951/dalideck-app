import 'package:flutter/material.dart';
import '../i18n.dart';
import '../main.dart';
import '../models.dart';

class QuranView extends StatelessWidget {
  final Store store;
  const QuranView({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store.s;
    final q = s.quran;
    final cur = (q['cur'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
    final log = (q['log'] as Map?) ?? {};
    final khitma = (q['khitma'] as num?)?.toInt() ?? 0;
    final progress = (cur.length / 30).clamp(0.0, 1.0);

    // favorite (last read date) juz today
    final tod = todayStr();

    return Scaffold(
      appBar: AppBar(title: Text(t('quran'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('current_khitma'),
                    style: const TextStyle(color: kAccent, fontSize: 11, letterSpacing: 1.5)),
                const SizedBox(height: 6),
                Text('${cur.length}/30', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: kPanel,
                    color: kAccent,
                  ),
                ),
                const SizedBox(height: 10),
                Text('${t('khitma')} ${t('read_today')}: $khitma',
                    style: const TextStyle(color: kMuted, fontSize: 13)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          _hifzCard(context),
          const SizedBox(height: 12),
          _dailyAyahCard(context),
          const SizedBox(height: 12),
          if (khitma > 0)
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text('${t('khitma')} #$khitma 🎉',
                  style: const TextStyle(color: Colors.greenAccent)),
            ),
          const SizedBox(height: 12),
          Text(t('juz_grid').toUpperCase(),
              style: const TextStyle(color: kMuted, fontSize: 12, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (var j = 1; j <= 30; j++)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    var khitmaDone = false;
                    store.mutate(() {
                      final nl = List<int>.from(cur);
                      if (nl.contains(j)) {
                        nl.remove(j);
                        log.remove('$j');
                      } else {
                        nl.add(j);
                        log['$j'] = tod;
                      }
                      s.quran['cur'] = nl;
                      s.quran['log'] = Map<String, dynamic>.from(log);
                      if (nl.length >= 30) {
                        khitmaDone = true;
                        s.quran['khitma'] = (s.quran['khitma'] as num? ?? 0).toInt() + 1;
                        s.quran['cur'] = <int>[];
                        s.quran['log'] = <String, dynamic>{};
                      }
                    });
                    if (khitmaDone) showSnack(context, '${t('khitma')} 🎉');
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: cur.contains(j) ? kAccent.withValues(alpha: 0.28) : kPanel,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: cur.contains(j) ? kAccent : Colors.transparent,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$j',
                      style: TextStyle(
                        color: cur.contains(j) ? Colors.white : kMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(t('read_today').toUpperCase(),
              style: const TextStyle(color: kMuted, fontSize: 12, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          if (log.values.where((d) => '$d' == tod).isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(t('no_results'), style: const TextStyle(color: kMuted)),
            ),
          ...log.entries.where((e) => '$e.value' == tod).map((e) => Card(
                child: ListTile(
                  dense: true,
                  title: Text('${t('juz')} ${e.key}'),
                  trailing: Text(tod, style: const TextStyle(color: kMuted)),
                ),
              )),
        ],
      ),
    );
  }

  Widget _hifzCard(BuildContext context) {
    final q = store.s.quran;
    final hifz = (q['hifz'] is Map)
        ? Map<String, dynamic>.from(q['hifz'] as Map)
        : <String, dynamic>{};
    final juz = (hifz['currentJuz'] is num)
        ? (hifz['currentJuz'] as num).toInt()
        : 1;
    final page = (hifz['currentPage'] is num)
        ? (hifz['currentPage'] as num).toInt()
        : 1;
    final rev = (hifz['revisionJuz'] is List)
        ? (hifz['revisionJuz'] as List)
            .map((e) => (e as num).toInt())
            .toList()
        : <int>[];
    final log = (hifz['revisionLog'] is Map)
        ? Map<String, dynamic>.from(hifz['revisionLog'] as Map)
        : <String, dynamic>{};
    final tod = todayStr();

    void goPage(int dir) {
      store.mutate(() {
        var j = juz;
        var p = page + dir;
        if (p < 1) {
          if (j > 1) {
            j--;
            p = 20;
          } else {
            p = 1;
          }
        } else if (p > 20) {
          if (j < 30) {
            j++;
            p = 1;
          } else {
            p = 20;
          }
        }
        final h = Map<String, dynamic>.from(hifz);
        h['currentJuz'] = j;
        h['currentPage'] = p;
        q['hifz'] = h;
      });
    }

    Future<void> addJuz() async {
      final free = [for (var j = 1; j <= 30; j++) if (!rev.contains(j)) j];
      if (free.isEmpty) {
        showSnack(context, t('revision_schedule'));
        return;
      }
      final picked = await showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kPanel,
          title: Text(t('choose_juz')),
          content: SizedBox(
            width: double.maxFinite,
            height: 260,
            child: GridView.count(
              crossAxisCount: 5,
              children: [
                for (final j in free)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.pop(ctx, j),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kAccent),
                      ),
                      alignment: Alignment.center,
                      child: Text('$j',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      if (picked == null) return;
      store.mutate(() {
        final h = Map<String, dynamic>.from(hifz);
        h['revisionJuz'] = [...rev, picked];
        q['hifz'] = h;
      });
    }

    void markRevised(int jz) {
      store.mutate(() {
        final h = Map<String, dynamic>.from(hifz);
        final l = Map<String, dynamic>.from(log)..['$jz'] = tod;
        final r = List<int>.from(rev)..remove(jz)..add(jz);
        h['revisionLog'] = l;
        h['revisionJuz'] = r;
        q['hifz'] = h;
      });
    }

    int revAge(String jz) {
      final d = log[jz];
      if (d == null || '$d'.isEmpty) return -1;
      return diffDays('$d', tod);
    }

    Color revColor(int days) => days <= 7
        ? Colors.greenAccent
        : days <= 14
            ? Colors.orangeAccent
            : kAccent;

    String revText(String jz) {
      final days = revAge(jz);
      if (days < 0) return t('never');
      return t('last_revised').replaceFirst('%s', '$days');
    }

    return Card(
      color: kPanel,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('hifz_tracker'),
              style: const TextStyle(color: kAccent, fontSize: 11, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text(t('current_juz'), style: const TextStyle(color: kMuted, fontSize: 13)),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                onPressed: () => goPage(-1),
                icon: const Icon(Icons.chevron_left, color: kAccent),
              ),
              Expanded(
                child: Column(children: [
                  Text('${t('juz')} $juz',
                      style:
                          const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(t('current_page').replaceFirst('%s', '$page'),
                      style: const TextStyle(color: kMuted, fontSize: 12)),
                ]),
              ),
              IconButton(
                onPressed: () => goPage(1),
                icon: const Icon(Icons.chevron_right, color: kAccent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (page / 20).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: kBg,
              color: kAccent,
            ),
          ),
          const SizedBox(height: 4),
          Text(t('pages_in_juz'),
              style: const TextStyle(color: kMuted, fontSize: 11)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(t('revision_schedule'),
                    style: const TextStyle(
                        color: kMuted,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700)),
              ),
              TextButton.icon(
                onPressed: addJuz,
                icon: const Icon(Icons.add, size: 16),
                label: Text(t('add_juz_revision'),
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (rev.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(t('no_revision'),
                  style: const TextStyle(color: kMuted)),
            )
          else
            ...[
              for (final jz in rev) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: kBg, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('revise_juz').replaceFirst('%s', '$jz'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(revText('$jz'),
                                style: TextStyle(color: revColor(revAge('$jz')), fontSize: 11)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => markRevised(jz),
                        style: TextButton.styleFrom(foregroundColor: kAccent),
                        child: Text(t('mark_revised'),
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ],
        ]),
      ),
    );
  }

  Widget _dailyAyahCard(BuildContext context) {
    final q = store.s.quran;
    final lastAyah = (q['lastAyah'] is num)
        ? (q['lastAyah'] as num).toInt()
        : 1;
    final tod = todayStr();
    final hifz = (q['hifz'] is Map)
        ? Map<String, dynamic>.from(q['hifz'] as Map)
        : <String, dynamic>{};
    final lastRead = hifz['lastReadDate'] as String? ?? '';
    final ayah = lastRead == tod ? lastAyah : lastAyah + 1;

    Future<void> pickTime() async {
      final cur =
          store.s.settings.notif['ayahTime'] as String? ?? '07:00';
      final parts = cur.split(':');
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 7,
          minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
        ),
      );
      if (picked == null) return;
      final timeStr = '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}';
      store.mutate(() => store.s.settings.notif['ayahTime'] = timeStr);
      if (context.mounted) showSnack(context, '${t('set_ayah_time')}: $timeStr');
    }

    return Card(
      color: kPanel,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(t('daily_ayah_num'),
                      style: const TextStyle(
                          color: kAccent, fontSize: 11, letterSpacing: 1.5)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: pickTime,
                  icon: const Icon(Icons.alarm, size: 18, color: kMuted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('$ayah',
                style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 4),
            Text('${t('daily_ayah')} · ${t('juz')} ${((ayah - 1) ~/ 20) + 1}',
                style: const TextStyle(color: kMuted, fontSize: 12)),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: kAccent),
              onPressed: () => store.mutate(() {
                final h = Map<String, dynamic>.from((q['hifz'] as Map?) ?? {});
                h['lastReadDate'] = tod;
                q['hifz'] = h;
                q['lastAyah'] = ayah;
              }),
              icon: const Icon(Icons.check, size: 16),
              label: Text(t('mark_read')),
            ),
          ],
        ),
      ),
    );
  }
}