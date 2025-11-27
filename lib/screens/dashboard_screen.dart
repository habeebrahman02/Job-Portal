import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../utils/time_utils.dart';
import '../widgets/new_task_dialog.dart';
import '../widgets/tasks_list_dialog.dart';
import '../widgets/hourly_prompt_dialog.dart';
import '../widgets/idle_recovery_dialog.dart';

class DashboardScreen extends StatefulWidget {
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String jobDescription = '';

  // Guards so we don't open the same dialog repeatedly
  bool _hourlyDialogShown = false;
  bool _idleDialogShown = false;

  Future<void> _showSleepRecoveryDialog(BuildContext context, {String initialText = ''}) async {
    final appState = Provider.of<AppState>(context, listen: false);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return IdleRecoveryDialog(
          initialText: initialText,
          onSubmit: (text) {
            appState.recoverFromIdle(text);
            appState.isIdle = false;
            appState.notifyListeners();
            Navigator.of(ctx).pop();
          },
          onCancel: () {
            // If user chooses to ignore, we still clear the isIdle flag (or keep it, depending on policy).
            // We'll clear it here to allow resuming without description.
            appState.isIdle = false;
            appState.notifyListeners();
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  Future<void> _showHourlyPromptDialog(BuildContext context, {String initialText = ''}) async {
    final appState = Provider.of<AppState>(context, listen: false);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return HourlyPromptDialog(
          initialText: initialText,
          onSubmit: (text) {
            appState.addHourlyDescription(text);
            Navigator.of(ctx).pop();
          },
          onCancel: () {
            appState.showHourlyPrompt = false;
            appState.notifyListeners();
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    // compute displayed total time for the day (exclude idle)
    final displayedSeconds = state.totalActiveSecondsForToday();
    final idleSeconds = state.tasksForToday().fold<int>(0, (prev, t) {
      final ips = t.idlePeriods;
      int local = 0;
      for (var ip in ips) {
        if (ip.endTime != null) {
          local += ip.endTime!.difference(ip.startTime).inSeconds;
        } else {
          // ongoing idle counts until now
          local += DateTime.now().difference(ip.startTime).inSeconds;
        }
      }
      return prev + local;
    });

    // Automatic dialog presentation after frame renders (safe)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Hourly prompt
      if (state.showHourlyPrompt && !_hourlyDialogShown && !state.isIdle && state.currentScreen == 'dashboard') {
        _hourlyDialogShown = true;
        _showHourlyPromptDialog(context).then((_) {
          // dialog closed - reset guard and flag
          _hourlyDialogShown = false;
          if (state.showHourlyPrompt) {
            state.showHourlyPrompt = false;
            state.notifyListeners();
          }
        });
      }

      // Idle recovery
      if (state.isIdle && !_idleDialogShown && state.currentScreen == 'dashboard') {
        _idleDialogShown = true;
        _showSleepRecoveryDialog(context).then((_) {
          // dialog closed - reset guard
          _idleDialogShown = false;
        });
      }
    });

    return GestureDetector(
      onTap: state.recordActivity,
      onPanDown: (_) => state.recordActivity(),
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Job Report'),
              Text(state.userName, style: TextStyle(fontSize: 12)),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () => showDialog(context: context, builder: (_) => TasksListDialog()),
              icon: Icon(Icons.list, color: Colors.purple),
              label: Text('All Tasks', style: TextStyle(color: Colors.purple)),
            ),
            IconButton(
              onPressed: () => showDialog(context: context, builder: (_) => NewTaskDialog()),
              icon: Icon(Icons.add, color: Colors.green),
            ),
            IconButton(
              onPressed: () {
                state.showHourlyPrompt = true;
                state.notifyListeners();
              },
              icon: Icon(Icons.timer, color: Colors.blue),
            ),

            // Recover from Sleep button in AppBar (manual trigger)
            IconButton(
              tooltip: 'Recover from Sleep',
              onPressed: () => _showSleepRecoveryDialog(context),
              icon: Icon(Icons.restore, color: Colors.orange),
            ),

            IconButton(
              onPressed: () {
                final report = state.endSessionReport();
                showDialog(
                  context: context,
                  builder: (_) {
                    return AlertDialog(
                      title: Text('Work Session Report'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _reportRow('Total Tasks', report['totalTasks'].toString()),
                          _reportRow('Total Worked', '${report['totalWorkedHours']} hours'),
                          _reportRow('Idle Time', '${report['totalIdleHours']} hours'),
                          _reportRow('Work Periods', report['workPeriods'].toString()),
                          _reportRow('Idle Periods', report['idlePeriods'].toString()),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            // send email (opens mail client)
                            await state.sendReportEmail();
                            // then logout & reset
                            state.logoutAndReset();
                          },
                          child: Text('Send & Logout'),
                        ),
                      ],
                    );
                  },
                );
              },
              icon: Icon(Icons.logout, color: Colors.red),
            )
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(12),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Text('Total Work Time Today', style: TextStyle(fontSize: 16, color: Colors.grey[800])),
                      SizedBox(height: 12),
                      Text(formatTime(displayedSeconds), style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: state.isIdle ? Colors.orange : Colors.green, shape: BoxShape.circle)),
                          SizedBox(width: 8),
                          Text(state.isIdle ? 'Idle' : 'Active', style: TextStyle(fontWeight: FontWeight.w600, color: state.isIdle ? Colors.orange[800] : Colors.green[800])),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.work_outline, size: 28, color: Colors.blue),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(state.currentTask?.description ?? 'No description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                SizedBox(height: 6),
                                if (state.currentTask?.category != null)
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      Chip(label: Text(state.currentTask!.category), backgroundColor: Colors.purple[50]),
                                      ...?state.currentTask!.tags.map((t) => Chip(label: Text('#$t'), backgroundColor: Colors.grey[100]))
                                    ],
                                  )
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: state.currentTask?.status == 'completed' ? Colors.blue[50] : state.isIdle ? Colors.orange[50] : Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              state.currentTask?.status == 'completed' ? 'Completed' : state.isIdle ? 'Idle' : 'Active',
                              style: TextStyle(fontWeight: FontWeight.bold, color: state.currentTask?.status == 'completed' ? Colors.blue[700] : state.isIdle ? Colors.orange[700] : Colors.green[700]),
                            ),
                          )
                        ],
                      ),
                      Divider(height: 18),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 18),
                          SizedBox(width: 6),
                          Text('Started:'),
                          SizedBox(width: 8),
                          Text(state.currentTask != null ? formatDateTimeShort(state.currentTask!.startTime) : '-'),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.play_circle_fill, size: 18),
                          SizedBox(width: 6),
                          Text('Work Periods: ${state.workPeriods.length}'),
                          SizedBox(width: 16),
                          Icon(Icons.pause_circle_filled, size: 18),
                          SizedBox(width: 6),
                          Text('Idle Periods: ${state.idlePeriods.length}'),
                        ],
                      ),
                      SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          state.currentScreen = 'details';
                          state.notifyListeners();
                        },
                        icon: Icon(Icons.visibility),
                        label: Text('View Details'),
                        style: ElevatedButton.styleFrom(minimumSize: Size.fromHeight(44)),
                      ),
                      if (state.currentTask?.status != 'completed')
                        SizedBox(height: 8),
                      if (state.currentTask?.status != 'completed')
                        ElevatedButton.icon(
                          onPressed: () {
                            state.completeCurrentTask();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task marked as completed! ✓')));
                          },
                          icon: Icon(Icons.check_circle),
                          label: Text('Mark as Completed'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: Size.fromHeight(44)),
                        )
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _statCard('Active Time', formatTime(displayedSeconds), Icons.check_circle, Colors.green)),
                  SizedBox(width: 8),
                  Expanded(child: _statCard('Idle Time', formatTime(idleSeconds), Icons.pause_circle_filled, Colors.orange)),
                ],
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(width: 4, color: Colors.blue))),
                child: Row(
                  children: [
                    Expanded(child: Text('💡 Tip: Create multiple tasks and the system tracks activity automatically - idle after 5 minutes.', style: TextStyle(color: Colors.blue[800]))),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Recover FAB when idle
        floatingActionButton: state.isIdle
            ? FloatingActionButton.extended(
                onPressed: () => _showSleepRecoveryDialog(context),
                icon: Icon(Icons.restore),
                label: Text('Recover'),
                backgroundColor: Colors.orange,
              )
            : SizedBox.shrink(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _reportRow(String a, String b) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(a), Text(b, style: TextStyle(fontWeight: FontWeight.bold))]),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(title, style: TextStyle(color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }
}





















// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../main.dart';
// import '../utils/time_utils.dart';
// import '../widgets/new_task_dialog.dart';
// import '../widgets/tasks_list_dialog.dart';
// import '../widgets/hourly_prompt_dialog.dart';
// import '../widgets/idle_recovery_dialog.dart';

// class DashboardScreen extends StatefulWidget {
//   @override
//   State<DashboardScreen> createState() => _DashboardScreenState();
// }

// class _DashboardScreenState extends State<DashboardScreen> {
//   String jobDescription = '';

//   Future<void> _showSleepRecoveryDialog(BuildContext context) async {
//     final TextEditingController _ctl = TextEditingController();
//     final appState = Provider.of<AppState>(context, listen: false);

//     await showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (ctx) {
//         return AlertDialog(
//           title: Row(
//             children: [
//               Icon(Icons.restore, color: Colors.orange),
//               SizedBox(width: 8),
//               Text('Recover from Sleep / Idle'),
//             ],
//           ),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 'You returned after inactivity. What were you doing before the break?',
//                 style: TextStyle(fontSize: 14),
//               ),
//               SizedBox(height: 12),
//               TextField(
//                 controller: _ctl,
//                 maxLines: 4,
//                 autofocus: true,
//                 decoration: InputDecoration(
//                   hintText: 'Describe your work before the break...',
//                   border: OutlineInputBorder(),
//                 ),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(ctx).pop(); // cancel
//               },
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 final text = _ctl.text.trim();
//                 if (text.isNotEmpty) {
//                   appState.recoverFromIdle(text);
//                   Navigator.of(ctx).pop();
//                 } else {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Please enter a description to resume.')),
//                   );
//                 }
//               },
//               child: Text('Resume Work'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final state = Provider.of<AppState>(context);

//     // compute displayed total time
//     final displayedSeconds = state.totalWorkedSeconds.toInt() + (state.isIdle ? 0 : state.elapsedSeconds);
//     final idleSeconds = state.idlePeriods.fold<int>(0, (prev, ip) {
//       if (ip.endTime != null) return prev + ip.endTime!.difference(ip.startTime).inSeconds;
//       return prev;
//     });

//     return GestureDetector(
//       onTap: state.recordActivity,
//       onPanDown: (_) => state.recordActivity(),
//       child: Scaffold(
//         appBar: AppBar(
//           title: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text('Job Report'),
//               Text(state.userName, style: TextStyle(fontSize: 12)),
//             ],
//           ),
//           actions: [
//             TextButton.icon(
//               onPressed: () => showDialog(context: context, builder: (_) => TasksListDialog()),
//               icon: Icon(Icons.list, color: Colors.purple),
//               label: Text('All Tasks', style: TextStyle(color: Colors.purple)),
//             ),
//             IconButton(
//               onPressed: () => showDialog(context: context, builder: (_) => NewTaskDialog()),
//               icon: Icon(Icons.add, color: Colors.green),
//             ),
//             IconButton(
//               onPressed: () {
//                 state.showHourlyPrompt = true;
//                 state.notifyListeners();
//               },
//               icon: Icon(Icons.timer, color: Colors.blue),
//             ),

//             // NEW: Recover from Sleep button in AppBar
//             IconButton(
//               tooltip: 'Recover from Sleep',
//               onPressed: () => _showSleepRecoveryDialog(context),
//               icon: Icon(Icons.restore, color: Colors.orange),
//             ),

//             IconButton(
//               onPressed: () {
//                 final report = state.endSessionReport();
//                 showDialog(
//                   context: context,
//                   builder: (_) {
//                     return AlertDialog(
//                       title: Text('Work Session Report'),
//                       content: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           _reportRow('Total Tasks', report['totalTasks'].toString()),
//                           _reportRow('Total Worked', '${report['totalWorkedHours']} hours'),
//                           _reportRow('Idle Time', '${report['totalIdleHours']} hours'),
//                           _reportRow('Work Periods', report['workPeriods'].toString()),
//                           _reportRow('Idle Periods', report['idlePeriods'].toString()),
//                         ],
//                       ),
//                       actions: [
//                         TextButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
//                         ElevatedButton(
//                           onPressed: () {
//                             Navigator.pop(context);
//                             state.logoutAndReset();
//                           },
//                           child: Text('Close & Logout'),
//                         ),
//                       ],
//                     );
//                   },
//                 );
//               },
//               icon: Icon(Icons.logout, color: Colors.red),
//             )
//           ],
//         ),
//         body: SingleChildScrollView(
//           padding: EdgeInsets.all(12),
//           child: Column(
//             children: [
//               Card(
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 child: Padding(
//                   padding: EdgeInsets.all(18),
//                   child: Column(
//                     children: [
//                       Text('Total Work Time Today', style: TextStyle(fontSize: 16, color: Colors.grey[800])),
//                       SizedBox(height: 12),
//                       Text(formatTime(displayedSeconds), style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blue[800])),
//                       SizedBox(height: 8),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Container(width: 10, height: 10, decoration: BoxDecoration(color: state.isIdle ? Colors.orange : Colors.green, shape: BoxShape.circle)),
//                           SizedBox(width: 8),
//                           Text(state.isIdle ? 'Idle' : 'Active', style: TextStyle(fontWeight: FontWeight.w600, color: state.isIdle ? Colors.orange[800] : Colors.green[800])),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               SizedBox(height: 12),
//               Card(
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 child: Padding(
//                   padding: EdgeInsets.all(14),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Icon(Icons.work_outline, size: 28, color: Colors.blue),
//                           SizedBox(width: 10),
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(state.currentTask?.description ?? 'No description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//                                 SizedBox(height: 6),
//                                 if (state.currentTask?.category != null)
//                                   Wrap(
//                                     spacing: 6,
//                                     children: [
//                                       Chip(label: Text(state.currentTask!.category), backgroundColor: Colors.purple[50]),
//                                       ...?state.currentTask!.tags.map((t) => Chip(label: Text('#$t'), backgroundColor: Colors.grey[100]))
//                                     ],
//                                   )
//                               ],
//                             ),
//                           ),
//                           Container(
//                             padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                             decoration: BoxDecoration(
//                               color: state.currentTask?.status == 'completed' ? Colors.blue[50] : state.isIdle ? Colors.orange[50] : Colors.green[50],
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             child: Text(
//                               state.currentTask?.status == 'completed' ? 'Completed' : state.isIdle ? 'Idle' : 'Active',
//                               style: TextStyle(fontWeight: FontWeight.bold, color: state.currentTask?.status == 'completed' ? Colors.blue[700] : state.isIdle ? Colors.orange[700] : Colors.green[700]),
//                             ),
//                           )
//                         ],
//                       ),
//                       Divider(height: 18),
//                       Row(
//                         children: [
//                           Icon(Icons.access_time, size: 18),
//                           SizedBox(width: 6),
//                           Text('Started:'),
//                           SizedBox(width: 8),
//                           Text(state.currentTask != null ? formatDateTimeShort(state.currentTask!.startTime) : '-'),
//                         ],
//                       ),
//                       SizedBox(height: 8),
//                       Row(
//                         children: [
//                           Icon(Icons.play_circle_fill, size: 18),
//                           SizedBox(width: 6),
//                           Text('Work Periods: ${state.workPeriods.length}'),
//                           SizedBox(width: 16),
//                           Icon(Icons.pause_circle_filled, size: 18),
//                           SizedBox(width: 6),
//                           Text('Idle Periods: ${state.idlePeriods.length}'),
//                         ],
//                       ),
//                       SizedBox(height: 12),
//                       ElevatedButton.icon(
//                         onPressed: () {
//                           state.currentScreen = 'details';
//                           state.notifyListeners();
//                         },
//                         icon: Icon(Icons.visibility),
//                         label: Text('View Details'),
//                         style: ElevatedButton.styleFrom(minimumSize: Size.fromHeight(44)),
//                       ),
//                       if (state.currentTask?.status != 'completed')
//                         SizedBox(height: 8),
//                       if (state.currentTask?.status != 'completed')
//                         ElevatedButton.icon(
//                           onPressed: () {
//                             state.completeCurrentTask();
//                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task marked as completed! ✓')));
//                           },
//                           icon: Icon(Icons.check_circle),
//                           label: Text('Mark as Completed'),
//                           style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: Size.fromHeight(44)),
//                         )
//                     ],
//                   ),
//                 ),
//               ),
//               SizedBox(height: 12),
//               Row(
//                 children: [
//                   Expanded(child: _statCard('Active Time', formatTime(displayedSeconds), Icons.check_circle, Colors.green)),
//                   SizedBox(width: 8),
//                   Expanded(child: _statCard('Idle Time', formatTime(idleSeconds), Icons.pause_circle_filled, Colors.orange)),
//                 ],
//               ),
//               SizedBox(height: 12),
//               Container(
//                 padding: EdgeInsets.all(12),
//                 decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(width: 4, color: Colors.blue))),
//                 child: Row(
//                   children: [
//                     Expanded(child: Text('💡 Tip: Create multiple tasks and the system tracks activity automatically - idle after 30s (demo).', style: TextStyle(color: Colors.blue[800]))),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//         // dialogs
//         floatingActionButton: state.isIdle
//             ? FloatingActionButton.extended(
//                 onPressed: () => _showSleepRecoveryDialog(context),
//                 icon: Icon(Icons.restore),
//                 label: Text('Recover'),
//                 backgroundColor: Colors.orange,
//               )
//             : SizedBox.shrink(),
//         floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
//       ),
//     );
//   }

//   Widget _reportRow(String a, String b) {
//     return Padding(
//       padding: EdgeInsets.symmetric(vertical: 6),
//       child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(a), Text(b, style: TextStyle(fontWeight: FontWeight.bold))]),
//     );
//   }

//   Widget _statCard(String title, String value, IconData icon, Color color) {
//     return Card(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: EdgeInsets.all(14),
//         child: Column(
//           children: [
//             Icon(icon, size: 32, color: color),
//             SizedBox(height: 8),
//             Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//             SizedBox(height: 4),
//             Text(title, style: TextStyle(color: Colors.grey[700])),
//           ],
//         ),
//       ),
//     );
//   }
// }





























// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../main.dart';
// import '../utils/time_utils.dart';
// import '../widgets/new_task_dialog.dart';
// import '../widgets/tasks_list_dialog.dart';
// import '../widgets/hourly_prompt_dialog.dart';
// import '../widgets/idle_recovery_dialog.dart';

// class DashboardScreen extends StatefulWidget {
//   @override
//   State<DashboardScreen> createState() => _DashboardScreenState();
// }

// class _DashboardScreenState extends State<DashboardScreen> {
//   String jobDescription = '';

//   @override
//   Widget build(BuildContext context) {
//     final state = Provider.of<AppState>(context);

//     // compute displayed total time
//     final displayedSeconds = state.totalWorkedSeconds.toInt() + (state.isIdle ? 0 : state.elapsedSeconds);
//     final idleSeconds = state.idlePeriods.fold<int>(0, (prev, ip) {
//       if (ip.endTime != null) return prev + ip.endTime!.difference(ip.startTime).inSeconds;
//       return prev;
//     });

//     return GestureDetector(
//       onTap: state.recordActivity,
//       onPanDown: (_) => state.recordActivity(),
//       child: Scaffold(
//         appBar: AppBar(
//           title: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text('Job Report'),
//               Text(state.userName, style: TextStyle(fontSize: 12)),
//             ],
//           ),
//           actions: [
//             TextButton.icon(
//               onPressed: () => showDialog(context: context, builder: (_) => TasksListDialog()),
//               icon: Icon(Icons.list, color: Colors.purple),
//               label: Text('All Tasks', style: TextStyle(color: Colors.purple)),
//             ),
//             IconButton(
//               onPressed: () => showDialog(context: context, builder: (_) => NewTaskDialog()),
//               icon: Icon(Icons.add, color: Colors.green),
//             ),
//             IconButton(
//               onPressed: () {
//                 state.showHourlyPrompt = true;
//                 state.notifyListeners();
//               },
//               icon: Icon(Icons.timer, color: Colors.blue),
//             ),
//             IconButton(
//               onPressed: () {
//                 final report = state.endSessionReport();
//                 showDialog(
//                   context: context,
//                   builder: (_) {
//                     return AlertDialog(
//                       title: Text('Work Session Report'),
//                       content: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           _reportRow('Total Tasks', report['totalTasks'].toString()),
//                           _reportRow('Total Worked', '${report['totalWorkedHours']} hours'),
//                           _reportRow('Idle Time', '${report['totalIdleHours']} hours'),
//                           _reportRow('Work Periods', report['workPeriods'].toString()),
//                           _reportRow('Idle Periods', report['idlePeriods'].toString()),
//                         ],
//                       ),
//                       actions: [
//                         TextButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
//                         ElevatedButton(
//                           onPressed: () {
//                             Navigator.pop(context);
//                             state.logoutAndReset();
//                           },
//                           child: Text('Close & Logout'),
//                         ),
//                       ],
//                     );
//                   },
//                 );
//               },
//               icon: Icon(Icons.logout, color: Colors.red),
//             )
//           ],
//         ),
//         body: SingleChildScrollView(
//           padding: EdgeInsets.all(12),
//           child: Column(
//             children: [
//               Card(
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 child: Padding(
//                   padding: EdgeInsets.all(18),
//                   child: Column(
//                     children: [
//                       Text('Total Work Time Today', style: TextStyle(fontSize: 16, color: Colors.grey[800])),
//                       SizedBox(height: 12),
//                       Text(formatTime(displayedSeconds), style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blue[800])),
//                       SizedBox(height: 8),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Container(width: 10, height: 10, decoration: BoxDecoration(color: state.isIdle ? Colors.orange : Colors.green, shape: BoxShape.circle)),
//                           SizedBox(width: 8),
//                           Text(state.isIdle ? 'Idle' : 'Active', style: TextStyle(fontWeight: FontWeight.w600, color: state.isIdle ? Colors.orange[800] : Colors.green[800])),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               SizedBox(height: 12),
//               Card(
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 child: Padding(
//                   padding: EdgeInsets.all(14),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Icon(Icons.work_outline, size: 28, color: Colors.blue),
//                           SizedBox(width: 10),
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(state.currentTask?.description ?? 'No description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//                                 SizedBox(height: 6),
//                                 if (state.currentTask?.category != null)
//                                   Wrap(
//                                     spacing: 6,
//                                     children: [
//                                       Chip(label: Text(state.currentTask!.category), backgroundColor: Colors.purple[50]),
//                                       ...?state.currentTask!.tags.map((t) => Chip(label: Text('#$t'), backgroundColor: Colors.grey[100]))
//                                     ],
//                                   )
//                               ],
//                             ),
//                           ),
//                           Container(
//                             padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                             decoration: BoxDecoration(
//                               color: state.currentTask?.status == 'completed' ? Colors.blue[50] : state.isIdle ? Colors.orange[50] : Colors.green[50],
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             child: Text(
//                               state.currentTask?.status == 'completed' ? 'Completed' : state.isIdle ? 'Idle' : 'Active',
//                               style: TextStyle(fontWeight: FontWeight.bold, color: state.currentTask?.status == 'completed' ? Colors.blue[700] : state.isIdle ? Colors.orange[700] : Colors.green[700]),
//                             ),
//                           )
//                         ],
//                       ),
//                       Divider(height: 18),
//                       Row(
//                         children: [
//                           Icon(Icons.access_time, size: 18),
//                           SizedBox(width: 6),
//                           Text('Started:'),
//                           SizedBox(width: 8),
//                           Text(state.currentTask != null ? formatDateTimeShort(state.currentTask!.startTime) : '-'),
//                         ],
//                       ),
//                       SizedBox(height: 8),
//                       Row(
//                         children: [
//                           Icon(Icons.play_circle_fill, size: 18),
//                           SizedBox(width: 6),
//                           Text('Work Periods: ${state.workPeriods.length}'),
//                           SizedBox(width: 16),
//                           Icon(Icons.pause_circle_filled, size: 18),
//                           SizedBox(width: 6),
//                           Text('Idle Periods: ${state.idlePeriods.length}'),
//                         ],
//                       ),
//                       SizedBox(height: 12),
//                       ElevatedButton.icon(
//                         onPressed: () {
//                           state.currentScreen = 'details';
//                           state.notifyListeners();
//                         },
//                         icon: Icon(Icons.visibility),
//                         label: Text('View Details'),
//                         style: ElevatedButton.styleFrom(minimumSize: Size.fromHeight(44)),
//                       ),
//                       if (state.currentTask?.status != 'completed')
//                         SizedBox(height: 8),
//                       if (state.currentTask?.status != 'completed')
//                         ElevatedButton.icon(
//                           onPressed: () {
//                             state.completeCurrentTask();
//                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task marked as completed! ✓')));
//                           },
//                           icon: Icon(Icons.check_circle),
//                           label: Text('Mark as Completed'),
//                           style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: Size.fromHeight(44)),
//                         )
//                     ],
//                   ),
//                 ),
//               ),
//               SizedBox(height: 12),
//               Row(
//                 children: [
//                   Expanded(child: _statCard('Active Time', formatTime(displayedSeconds), Icons.check_circle, Colors.green)),
//                   SizedBox(width: 8),
//                   Expanded(child: _statCard('Idle Time', formatTime(idleSeconds), Icons.pause_circle_filled, Colors.orange)),
//                 ],
//               ),
//               SizedBox(height: 12),
//               Container(
//                 padding: EdgeInsets.all(12),
//                 decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(width: 4, color: Colors.blue))),
//                 child: Row(
//                   children: [
//                     Expanded(child: Text('💡 Tip: Create multiple tasks and the system tracks activity automatically - idle after 30s (demo).', style: TextStyle(color: Colors.blue[800]))),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//         // dialogs
//         floatingActionButton: SizedBox.shrink(),
//       ),
//     );
//   }

//   Widget _reportRow(String a, String b) {
//     return Padding(
//       padding: EdgeInsets.symmetric(vertical: 6),
//       child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(a), Text(b, style: TextStyle(fontWeight: FontWeight.bold))]),
//     );
//   }

//   Widget _statCard(String title, String value, IconData icon, Color color) {
//     return Card(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: EdgeInsets.all(14),
//         child: Column(
//           children: [
//             Icon(icon, size: 32, color: color),
//             SizedBox(height: 8),
//             Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//             SizedBox(height: 4),
//             Text(title, style: TextStyle(color: Colors.grey[700])),
//           ],
//         ),
//       ),
//     );
//   }
// }
