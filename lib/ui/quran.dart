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
}