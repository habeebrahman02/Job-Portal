import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class NewTaskDialog extends StatefulWidget {
  @override
  State<NewTaskDialog> createState() => _NewTaskDialogState();
}

class _NewTaskDialogState extends State<NewTaskDialog> {
  final _desc = TextEditingController();
  String _category = 'Development';
  final _tags = TextEditingController();
  final categories = ['Development', 'Meeting', 'Review', 'Documentation', 'Planning', 'Bug Fix', 'Testing', 'Research', 'Other'];
  final commonTags = ['urgent', 'client', 'frontend', 'backend', 'design', 'api', 'database', 'deployment'];

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    return AlertDialog(
      title: Row(children: [Icon(Icons.add, color: Colors.green), SizedBox(width: 8), Text('Create New Task')]),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(controller: _desc, decoration: InputDecoration(labelText: 'Task Description *')),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _category,
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
              decoration: InputDecoration(labelText: 'Category'),
            ),
            SizedBox(height: 8),
            TextField(controller: _tags, decoration: InputDecoration(labelText: 'Tags (comma-separated)')),
            SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: commonTags.map((t) {
                return ActionChip(
                  label: Text('#$t'),
                  onPressed: () {
                    final current = _tags.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                    if (!current.contains(t)) {
                      current.add(t);
                      _tags.text = current.join(', ');
                      setState(() {});
                    }
                  },
                );
              }).toList(),
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final tags = _tags.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
            Provider.of<AppState>(context, listen: false).createNewTask(_desc.text.trim(), _category, tags);
            Navigator.pop(context);
          },
          child: Text('Create Task'),
        )
      ],
    );
  }
}
