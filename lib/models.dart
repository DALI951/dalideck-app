import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// DaliDeck state model — mirrors the web app JSON exactly (dalideck.v1 v2).
// Money amounts are millimes (1000 = 1 TND). Dates are 'YYYY-MM-DD'.
// ---------------------------------------------------------------------------

int _uidSeq = 0;
String uid() =>
    'x${(++_uidSeq)}${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';

String two(int n) => n.toString().padLeft(2, '0');
String isoOf(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
String todayStr() => isoOf(DateTime.now());
DateTime dateOf(String s) => DateTime(
    int.parse(s.substring(0, 4)),
    int.parse(s.substring(5, 7)),
    int.parse(s.substring(8, 10)));
String addDaysStr(String s, int n) => isoOf(dateOf(s).add(Duration(days: n)));
int diffDays(String a, String b) => dateOf(b).difference(dateOf(a)).inDays;
String dueStr(DateTime d) => isoOf(d);

// semaine index: 0=Mon .. 6=Sun (same convention as the web `wday`)
int wdayIdx(String s) => dateOf(s).weekday - 1;
int todayIdx() => DateTime.now().weekday - 1;

// Deterministic canonical serializer — MUST byte-match the web jsonSer() so
// sync `seen` strings compare equal across platforms.
String jsonSer(Object? v) {
  if (v == null) return 'null';
  if (v is bool) return v ? 'true' : 'false';
  if (v is int) return '$v';
  if (v is double) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }
  if (v is String) return '"${_esc(v)}"';
  if (v is List) return '[${v.map(jsonSer).join(',')}]';
  if (v is Map) {
    final keys = v.keys.map((k) => k.toString()).toList()..sort();
    return '{'
        '${keys.map((k) => '"${_esc(k)}":${jsonSer(v[k])}').join(',')}'
        '}';
  }
  return 'null';
}

String _esc(String s) =>
    s.replaceAll('\\', r'\\').replaceAll('"', r'\"');

// fmtM: millimes -> human currency string (like web fmtM)
String fmtM(int millimes) {
  final v = millimes / 1000;
  final body = v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(3)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
  final re = RegExp(r'\B(?=(\d{3})+(?!\d))');
  return body.replaceAllMapped(re, (_) => ',');
}
int tndToM(String s) {
  final d = double.tryParse(s.replaceAll(',', '')) ?? 0;
  return (d * 1000).round();
}

// ---------------------------------------------------------------------------

class Settings {
  String name = 'Dali';
  String lang = 'en';
  String currency = 'TND';
  List<int> schoolDays = const [0, 1, 2, 3, 4, 5];
  String schoolStart = '2026-09-15';
  int monthlyBudget = 100000;
  bool prayer = true;
  Map<String, dynamic> notif = {
    'enabled': false,
    'tasks': true,
    'exams': true,
    'backup': true,
    'habits': false
  };

  Settings();

  Map<String, dynamic> toJson() => {
        'name': name,
        'lang': lang,
        'currency': currency,
        'schoolDays': schoolDays,
        'schoolStart': schoolStart,
        'monthlyBudget': monthlyBudget,
        'prayer': prayer,
        'notif': notif,
      };

  factory Settings.fromJson(Map<String, dynamic> j, Settings d) {
    final s = Settings()
      ..name = (j['name'] as String?) ?? d.name
      ..lang = (j['lang'] as String?) ?? d.lang
      ..currency = (j['currency'] as String?) ?? d.currency
      ..schoolStart = (j['schoolStart'] as String?) ?? d.schoolStart;
    if (j['schoolDays'] is List) {
      s.schoolDays = (j['schoolDays'] as List).whereType<int>().toList();
    } else {
      s.schoolDays = d.schoolDays;
    }
    if (j['monthlyBudget'] is num) {
      s.monthlyBudget = (j['monthlyBudget'] as num).toInt();
    } else {
      s.monthlyBudget = d.monthlyBudget;
    }
    if (j['prayer'] is bool) s.prayer = j['prayer'] as bool;
    if (j['notif'] is Map) {
      s.notif = Map<String, dynamic>.from(j['notif'] as Map);
    }
    return s;
  }
}

class IdItem {
  String id;
  IdItem(this.id);
}

class Account extends IdItem {
  String name = 'Cash';
  String type = 'cash';
  int base = 0;
  Account(super.id);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type, 'base': base};
  factory Account.fromJson(Map<String, dynamic> j) => Account('${j['id']}')
    ..name = '${j['name'] ?? 'Cash'}'
    ..type = '${j['type'] ?? 'cash'}'
    ..base = (j['base'] as num?)?.toInt() ?? 0;
}

class Subject extends IdItem {
  String name = '';
  num coeff = 1;
  Subject(super.id);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'coeff': coeff};
  factory Subject.fromJson(Map<String, dynamic> j) => Subject('${j['id']}')
    ..name = '${j['name'] ?? ''}'
    ..coeff = (j['coeff'] as num?) ?? 1;
}

class Period extends IdItem {
  String label = '';
  String time = '';
  Period(super.id);
  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'time': time};
  factory Period.fromJson(Map<String, dynamic> j) => Period('${j['id']}')
    ..label = '${j['label'] ?? ''}'
    ..time = '${j['time'] ?? ''}';
}

class Task extends IdItem {
  String title = '';
  String? subjectId;
  String? due;
  String prio = 'med';
  bool done = false;
  String? doneDate;
  Task(super.id);
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (subjectId != null) 'subjectId': subjectId,
        if (due != null) 'due': due,
        'prio': prio,
        'done': done,
        if (doneDate != null) 'doneDate': doneDate,
      };
  factory Task.fromJson(Map<String, dynamic> j) => Task('${j['id']}')
    ..title = '${j['title'] ?? ''}'
    ..subjectId = j['subjectId'] as String?
    ..due = j['due'] as String?
    ..prio = '${j['prio'] ?? 'med'}'
    ..done = j['done'] == true
    ..doneDate = j['doneDate'] as String?;
}

class Exam extends IdItem {
  String title = '';
  String? subjectId;
  String date = todayStr();
  int term = 1;
  Exam(super.id);
  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, if (subjectId != null) 'subjectId': subjectId, 'date': date, 'term': term};
  factory Exam.fromJson(Map<String, dynamic> j) => Exam('${j['id']}')
    ..title = '${j['title'] ?? ''}'
    ..subjectId = j['subjectId'] as String?
    ..date = '${j['date'] ?? todayStr()}'
    ..term = (j['term'] as num?)?.toInt() ?? 1;
}

class Grade extends IdItem {
  String? subjectId;
  String label = '';
  num score = 12;
  num max = 20;
  String date = todayStr();
  int term = 1;
  Grade(super.id);
  Map<String, dynamic> toJson() => {
        'id': id,
        if (subjectId != null) 'subjectId': subjectId,
        'label': label,
        'score': score,
        'max': max,
        'date': date,
        'term': term,
      };
  factory Grade.fromJson(Map<String, dynamic> j) => Grade('${j['id']}')
    ..subjectId = j['subjectId'] as String?
    ..label = '${j['label'] ?? ''}'
    ..score = (j['score'] as num?) ?? 12
    ..max = (j['max'] as num?) ?? 20
    ..date = '${j['date'] ?? todayStr()}'
    ..term = (j['term'] as num?)?.toInt() ?? 1;
}

class Project extends IdItem {
  String name = '';
  String status = 'idea';
  String prio = 'med';
  String tag = 'other';
  String nextStep = '';
  String lastWorked = todayStr();
  Project(super.id);
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status,
        'prio': prio,
        'tag': tag,
        'nextStep': nextStep,
        'lastWorked': lastWorked,
      };
  factory Project.fromJson(Map<String, dynamic> j) => Project('${j['id']}')
    ..name = '${j['name'] ?? ''}'
    ..status = '${j['status'] ?? 'idea'}'
    ..prio = '${j['prio'] ?? 'med'}'
    ..tag = '${j['tag'] ?? 'other'}'
    ..nextStep = '${j['nextStep'] ?? ''}'
    ..lastWorked = '${j['lastWorked'] ?? todayStr()}';
}

class MoneyEntry extends IdItem {
  String type = 'out'; // 'out' | 'in'
  int amount = 0; // millimes
  String? accountId;
  String cat = 'other';
  String note = '';
  String date = todayStr();
  MoneyEntry(super.id);
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'amount': amount,
        'cat': cat,
        'note': note,
        'date': date,
        if (accountId != null) 'accountId': accountId,
      };
  factory MoneyEntry.fromJson(Map<String, dynamic> j) => MoneyEntry('${j['id']}')
    ..type = '${j['type'] ?? 'out'}'
    ..amount = (j['amount'] as num?)?.toInt() ?? 0
    ..accountId = j['accountId'] as String?
    ..cat = '${j['cat'] ?? 'other'}'
    ..note = '${j['note'] ?? ''}'
    ..date = '${j['date'] ?? todayStr()}';
}

class Habit extends IdItem {
  String name = '';
  List<String> days = [];
  Habit(super.id);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'days': days};
  factory Habit.fromJson(Map<String, dynamic> j) => Habit('${j['id']}')
    ..name = '${j['name'] ?? ''}'
    ..days = (j['days'] as List?)?.map((e) => '$e').toList() ?? [];
}

class Note extends IdItem {
  String text = '';
  String date = todayStr();
  Note(super.id);
  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'date': date};
  factory Note.fromJson(Map<String, dynamic> j) => Note('${j['id']}')
    ..text = '${j['text'] ?? ''}'
    ..date = '${j['date'] ?? todayStr()}';
}

class Session extends IdItem {
  String date = todayStr();
  int mins = 0;
  String? subjectId;
  Session(super.id);
  Map<String, dynamic> toJson() => {'id': id, 'date': date, 'mins': mins, if (subjectId != null) 'subjectId': subjectId};
  factory Session.fromJson(Map<String, dynamic> j) => Session('${j['id']}')
    ..date = '${j['date'] ?? todayStr()}'
    ..mins = (j['mins'] as num?)?.toInt() ?? 0
    ..subjectId = j['subjectId'] as String?;
}

class Tutoring extends IdItem {
  String date = todayStr();
  int mins = 0;
  String? subjectId;
  String note = '';
  Tutoring(super.id);
  Map<String, dynamic> toJson() => {'id': id, 'date': date, 'mins': mins, 'subjectId': subjectId, 'note': note};
  factory Tutoring.fromJson(Map<String, dynamic> j) => Tutoring('${j['id']}')
    ..date = '${j['date'] ?? todayStr()}'
    ..mins = (j['mins'] as num?)?.toInt() ?? 0
    ..subjectId = j['subjectId'] as String?
    ..note = '${j['note'] ?? ''}';
}

class Revision extends IdItem {
  String examId;
  int offset;
  bool done = false;
  String? doneDate;
  Revision(this.examId, this.offset) : super(uid());
  Map<String, dynamic> toJson() =>
      {'id': id, 'examId': examId, 'offset': offset, 'done': done, 'doneDate': doneDate};
  factory Revision.fromJson(Map<String, dynamic> j) => Revision(
      '${j['examId'] ?? ''}', (j['offset'] as num?)?.toInt() ?? 1)
    ..done = j['done'] == true
    ..doneDate = j['doneDate'] as String?;
}

// ---------------------------------------------------------------------------

const kColls = [
  'settings', 'accounts', 'subjects', 'periods', 'cells',
  'tasks', 'exams', 'grades', 'revision', 'tutoring', 'sessions',
  'projects', 'money', 'habits', 'notes', 'quran', 'review'
];

class AppState {
  int v = 2;
  Settings settings = Settings();
  List<Account> accounts = [];
  List<Subject> subjects = [];
  List<Period> periods = [];
  Map<String, String> cells = {};
  List<Task> tasks = [];
  List<Exam> exams = [];
  List<Grade> grades = [];
  List<Revision> revision = [];
  List<Tutoring> tutoring = [];
  List<Session> sessions = [];
  List<Project> projects = [];
  List<MoneyEntry> money = [];
  List<Habit> habits = [];
  List<Note> notes = [];
  Map<String, dynamic> quran = {'khitma': 0, 'cur': [], 'log': {}};
  Map<String, dynamic> review = {'weeks': {}};

  AppState();

  static AppState seed() {
    final s = AppState();
    final cash = Account(uid())..name = 'Cash'..type = 'cash'..base = 0;
    s.accounts = [cash];
    s.subjects = [
      ('Arabic', 2), ('French', 2), ('English', 1), ('Maths', 3),
      ('Algorithmique & Programmation', 3), ("Systèmes & Tech. de l'Info", 2),
      ('Physics', 2), ('Islamic Ed', 1), ('History', 1), ('Geography', 1),
      ('Philosophy', 1)
    ].map((t) => Subject(uid())..name = t.$1..coeff = t.$2).toList();
    s.periods = [
      ('P1', '08:00 – 08:55'), ('P2', '08:55 – 09:50'), ('P3', '09:50 – 10:40'),
      ('P4', '10:55 – 11:50'), ('P5', '11:50 – 12:45'), ('P6', '14:00 – 14:55'),
      ('P7', '14:55 – 15:50'), ('P8', '16:05 – 17:00')
    ].map((t) => Period(uid())..label = t.$1..time = t.$2).toList();
    return s;
  }

  Map<String, Object?> toJson() => {
        'v': v,
        'settings': settings.toJson(),
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'subjects': subjects.map((a) => a.toJson()).toList(),
        'periods': periods.map((a) => a.toJson()).toList(),
        'cells': Map<String, String>.from(cells),
        'tasks': tasks.map((a) => a.toJson()).toList(),
        'exams': exams.map((a) => a.toJson()).toList(),
        'grades': grades.map((a) => a.toJson()).toList(),
        'revision': revision.map((a) => a.toJson()).toList(),
        'tutoring': tutoring.map((a) => a.toJson()).toList(),
        'sessions': sessions.map((a) => a.toJson()).toList(),
        'projects': projects.map((a) => a.toJson()).toList(),
        'money': money.map((a) => a.toJson()).toList(),
        'habits': habits.map((a) => a.toJson()).toList(),
        'notes': notes.map((a) => a.toJson()).toList(),
        'quran': quran,
        'review': review,
      };

  factory AppState.fromJson(Map<String, dynamic> j) {
    final s = AppState();
    final d = AppState.seed().settings;
    final set = j['settings'];
    if (set is Map) s.settings = Settings.fromJson(Map<String, dynamic>.from(set), d);
    if (j['accounts'] is List) s.accounts = _list<Account>(j['accounts'], Account.fromJson);
    if (j['subjects'] is List) s.subjects = _list<Subject>(j['subjects'], Subject.fromJson);
    if (j['periods'] is List) s.periods = _list<Period>(j['periods'], Period.fromJson);
    if (j['cells'] is Map) s.cells = Map<String, String>.fromIterables(
        (j['cells'] as Map).keys.map((k) => '$k'),
        (j['cells'] as Map).values.map((v) => '$v'));
    if (j['tasks'] is List) s.tasks = _list<Task>(j['tasks'], Task.fromJson);
    if (j['exams'] is List) s.exams = _list<Exam>(j['exams'], Exam.fromJson);
    if (j['grades'] is List) s.grades = _list<Grade>(j['grades'], Grade.fromJson);
    if (j['revision'] is List) s.revision = _list<Revision>(j['revision'], Revision.fromJson);
    if (j['tutoring'] is List) s.tutoring = _list<Tutoring>(j['tutoring'], Tutoring.fromJson);
    if (j['sessions'] is List) s.sessions = _list<Session>(j['sessions'], Session.fromJson);
    if (j['projects'] is List) s.projects = _list<Project>(j['projects'], Project.fromJson);
    if (j['money'] is List) s.money = _list<MoneyEntry>(j['money'], MoneyEntry.fromJson);
    if (j['habits'] is List) s.habits = _list<Habit>(j['habits'], Habit.fromJson);
    if (j['notes'] is List) s.notes = _list<Note>(j['notes'], Note.fromJson);
    if (j['quran'] is Map) s.quran = Map<String, dynamic>.from(j['quran'] as Map);
    if (j['review'] is Map) s.review = Map<String, dynamic>.from(j['review'] as Map);
    s.repair();
    return s;
  }

  static List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) f) =>
      (v as List).whereType<Map>().map((m) => f(Map<String, dynamic>.from(m))).toList();

  void repair() {
    v = 2;
    final d = AppState.seed();
    if (subjects.isEmpty) subjects = d.subjects;
    if (periods.isEmpty) periods = d.periods;
    if (quran.isEmpty) quran = {'khitma': 0, 'cur': [], 'log': {}};
    if (review.isEmpty) review = {'weeks': {}};
  }

  String? subjectName(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final s in subjects) {
      if (s.id == id) return s.name;
    }
    return null;
  }

  Object? coll(String name) {
    switch (name) {
      case 'settings': return settings.toJson();
      case 'accounts': return accounts.map((a) => a.toJson()).toList();
      case 'subjects': return subjects.map((a) => a.toJson()).toList();
      case 'periods': return periods.map((a) => a.toJson()).toList();
      case 'cells': return Map<String, String>.from(cells);
      case 'tasks': return tasks.map((a) => a.toJson()).toList();
      case 'exams': return exams.map((a) => a.toJson()).toList();
      case 'grades': return grades.map((a) => a.toJson()).toList();
      case 'revision': return revision.map((a) => a.toJson()).toList();
      case 'tutoring': return tutoring.map((a) => a.toJson()).toList();
      case 'sessions': return sessions.map((a) => a.toJson()).toList();
      case 'projects': return projects.map((a) => a.toJson()).toList();
      case 'money': return money.map((a) => a.toJson()).toList();
      case 'habits': return habits.map((a) => a.toJson()).toList();
      case 'notes': return notes.map((a) => a.toJson()).toList();
      case 'quran': return Map<String, dynamic>.from(quran);
      case 'review': return Map<String, dynamic>.from(review);
    }
    return null;
  }

  void putColl(String name, Object? value) {
    final m = value is Map ? Map<String, dynamic>.from(value) : null;
    final l = value is List ? value : null;
    switch (name) {
      case 'settings': settings = Settings.fromJson(m ?? {}, Settings());
      case 'accounts': accounts = _list<Account>(l, Account.fromJson);
      case 'subjects': subjects = _list<Subject>(l, Subject.fromJson);
      case 'periods': periods = _list<Period>(l, Period.fromJson);
      case 'cells': cells = Map<String, String>.fromIterables(
          (m ?? {}).keys.map((k) => '$k'), (m ?? {}).values.map((v) => '$v'));
      case 'tasks': tasks = _list<Task>(l, Task.fromJson);
      case 'exams': exams = _list<Exam>(l, Exam.fromJson);
      case 'grades': grades = _list<Grade>(l, Grade.fromJson);
      case 'revision': revision = _list<Revision>(l, Revision.fromJson);
      case 'tutoring': tutoring = _list<Tutoring>(l, Tutoring.fromJson);
      case 'sessions': sessions = _list<Session>(l, Session.fromJson);
      case 'projects': projects = _list<Project>(l, Project.fromJson);
      case 'money': money = _list<MoneyEntry>(l, MoneyEntry.fromJson);
      case 'habits': habits = _list<Habit>(l, Habit.fromJson);
      case 'notes': notes = _list<Note>(l, Note.fromJson);
      case 'quran': quran = m ?? {'khitma': 0, 'cur': [], 'log': {}};
      case 'review': review = m ?? {'weeks': {}};
    }
  }
}

class Store extends ChangeNotifier {
  AppState s;
  Store(this.s);

  void mutate(void Function() fn) {
    fn();
    s.repair();
    notifyListeners();
    saveRequested?.call();
  }

  void Function()? saveRequested;
  void Function()? syncRequested;
}

int accountBalance(AppState s, Account a) {
  var bal = a.base;
  for (final m in s.money) {
    if (m.accountId != null && m.accountId == a.id) {
      bal += m.type == 'in' ? m.amount : -m.amount;
    }
  }
  return bal;
}

int walletTotal(AppState s) =>
    s.accounts.fold(0, (t, a) => t + accountBalance(s, a));