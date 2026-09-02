import 'package:flutter/material.dart';
import '../i18n.dart';
import '../main.dart';
import '../models.dart';

class EntryField {
  final String name;
  final String label;
  final String type; // text | number | date | select
  final String? initial;
  final String? hint;
  final List<String> options;
  EntryField(this.name,
      {required this.label,
      this.type = 'text',
      this.initial,
      this.hint,
      this.options = const []});
}

// Returns a map of submitted values, or null on cancel.
Future<Map<String, Object?>?> showEntryDialog(
    BuildContext context, String title, List<EntryField> fields,
    {Object? Function()? validate}) {
  return showDialog<Map<String, Object?>>(
    context: context,
    builder: (_) => _EntryDialog(title: title, fields: fields),
  );
}

class _EntryDialog extends StatefulWidget {
  final String title;
  final List<EntryField> fields;
  const _EntryDialog({required this.title, required this.fields});

  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  final _c = <String, TextEditingController>{};
  late final Map<String, String> _sel;

  @override
  void initState() {
    super.initState();
    _sel = {};
    for (final f in widget.fields) {
      if (f.type == 'date' || f.type == 'select') {
        _sel[f.name] = f.initial ?? (f.options.isNotEmpty ? f.options.first : '');
      } else {
        _c[f.name] = TextEditingController(text: f.initial ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(String name) async {
    final cur = _sel[name];
    final d = await showDatePicker(
      context: context,
      initialDate: cur != null && cur.isNotEmpty ? dateOf(cur) : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null) setState(() => _sel[name] = isoOf(d));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.fields.map((f) {
            if (f.type == 'select') {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  value: _sel[f.name],
                  decoration: InputDecoration(labelText: f.label),
                  items: f.options
                      .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                      .toList(),
                  onChanged: (v) => setState(() => _sel[f.name] = v ?? ''),
                ),
              );
            }
            if (f.type == 'date') {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _pickDate(f.name),
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: f.label),
                    child: Text(_sel[f.name] ?? ''),
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _c[f.name],
                maxLength: 500,
                keyboardType: f.type == 'number'
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                decoration: InputDecoration(labelText: f.label, hintText: f.hint),
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(t('cancel'))),
        FilledButton(
          onPressed: () {
            final out = <String, Object?>{};
            for (final f in widget.fields) {
              if (f.type == 'select' || f.type == 'date') {
                out[f.name] = _sel[f.name];
              } else {
                out[f.name] = _c[f.name]!.text.trim();
              }
            }
            Navigator.pop(context, out);
          },
          child: Text(t('save')),
        ),
      ],
    );
  }
}

Future<String?> pickSubjectSheet(BuildContext context, AppState s) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(t('subject'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          ListTile(
            leading: const Icon(Icons.block, color: kMuted),
            title: Text(t('clear')),
            onTap: () => Navigator.pop(context, ''),
          ),
          ...s.subjects.map((sx) => ListTile(
                title: Text('${sx.name} (x${sx.coeff})'),
                onTap: () => Navigator.pop(context, sx.id),
              )),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}