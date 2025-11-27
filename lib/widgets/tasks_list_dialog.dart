import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../utils/time_utils.dart';

class TasksListDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    return Dialog(
      child: Container(
        width: 800,
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Icon(Icons.list, color: Colors.purple), SizedBox(width: 8), Text('All Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]), IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context))]),
            SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: state.allTasks.length,
                separatorBuilder: (_, __) => SizedBox(height: 8),
                itemBuilder: (_, idx) {
                  final t = state.allTasks[idx];
                  final isCurrent = state.currentTask != null && state.currentTask!.id == t.id;
                  final workedSeconds = t.workPeriods.fold<int>(0, (prev, p) {
                    if (p.endTime != null) return prev + p.endTime!.difference(p.startTime).inSeconds;
                    return prev + DateTime.now().difference(p.startTime).inSeconds;
                  });
                  return Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: isCurrent ? Colors.blue[50] : Colors.white, border: Border.all(color: isCurrent ? Colors.blue : Colors.grey[200]!)),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              if (!isCurrent && t.status != 'completed') {
                                Provider.of<AppState>(context, listen: false).switchToTask(t);
                                Navigator.pop(context);
                              }
                            },
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Text(t.description.isNotEmpty ? t.description : 'Task ${idx + 1}', style: TextStyle(fontWeight: FontWeight.bold)),
                                if (isCurrent) Padding(padding: EdgeInsets.only(left: 8), child: Chip(label: Text('Current', style: TextStyle(color: Colors.white)), backgroundColor: Colors.blue)),
                                if (t.category.isNotEmpty) Padding(padding: EdgeInsets.only(left: 8), child: Chip(label: Text(t.category), backgroundColor: Colors.purple[50]))
                              ]),
                              if (t.tags.isNotEmpty) Wrap(spacing: 6, children: t.tags.map((tg) => Chip(label: Text('#$tg'))).toList()),
                              SizedBox(height: 6),
                              Text('Started: ${formatDateTimeLong(t.startTime)}', style: TextStyle(color: Colors.grey[600])),
                            ]),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Chip(label: Text(t.status), backgroundColor: t.status == 'completed' ? Colors.blue[50] : t.status == 'idle' ? Colors.orange[50] : Colors.green[50]),
                            SizedBox(height: 6),
                            Text(formatTime(workedSeconds)),
                            SizedBox(height: 6),
                            Row(children: [
                              IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: () {
                                showDialog(context: context, builder: (_) {
                                  return AlertDialog(
                                    title: Text('Delete Task'),
                                    content: Text('Are you sure you want to delete this task? This action cannot be undone.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
                                      ElevatedButton(onPressed: () {
                                        Provider.of<AppState>(context, listen: false).deleteTask(t.id);
                                        Navigator.pop(context);
                                        Navigator.pop(context);
                                      }, child: Text('Delete'))
                                    ],
                                  );
                                });
                              }),
                            ])
                          ],
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
