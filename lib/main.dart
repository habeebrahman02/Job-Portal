// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/task.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/details_screen.dart';
import 'utils/storage.dart';
import 'package:url_launcher/url_launcher.dart';

/// Toggle this to `true` while testing to use short timers (30s idle / 2m hourly).
/// Set to `false` for production (5 minutes idle / 1 hour hourly).
const bool kDebugTiming = true;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // load stored JSON (if any)
  final data = await Storage.readJson();
  runApp(
    ChangeNotifierProvider(
      // pass debug mode here for quick testing
      create: (_) => AppState.fromJson(data, debugMode: kDebugTiming),
      child: JobReportApp(),
    ),
  );
}

/// AppState with JSON persistence and lifecycle support
class AppState extends ChangeNotifier {
  // user & nav
  String userName = '';
  String userEmail = '';
  String currentScreen = 'login';

  // task & periods
  TaskModel? currentTask;
  List<TaskModel> allTasks = [];
  List<WorkPeriod> workPeriods = [];
  List<IdlePeriod> idlePeriods = [];

  // timers & flags
  bool isIdle = false;
  DateTime lastActivity = DateTime.now();
  int elapsedSeconds = 0; // current ongoing period seconds
  double totalWorkedSeconds = 0; // persisted sum for loaded task
  Timer? ticker;
  Timer? idleChecker;
  Timer? hourlyPromptTimer;

  bool showHourlyPrompt = false;

  // debug flag and derived thresholds
  final bool debugMode;
  late final int idleThresholdSeconds;
  late final Duration hourlyPromptInterval;

  /// Default constructor (not typically used when loading from storage)
  AppState({bool debugMode = false}) : debugMode = debugMode {
    // set derived thresholds based on debugMode
    idleThresholdSeconds = debugMode ? 30 : 300; // 30s for debug, 5min for prod
    hourlyPromptInterval = debugMode ? Duration(minutes: 2) : Duration(hours: 1);
    // start timers after initialization
    startTimers();
  }

  /// Construct AppState from loaded JSON map (called in main)
  AppState.fromJson(Map<String, dynamic> json, {bool debugMode = false}) : debugMode = debugMode {
    // set derived thresholds based on debugMode before anything else
    idleThresholdSeconds = debugMode ? 30 : 300;
    hourlyPromptInterval = debugMode ? Duration(minutes: 2) : Duration(hours: 1);

    try {
      if (json.containsKey('user')) {
        final u = json['user'] as Map<String, dynamic>;
        userName = u['name'] ?? '';
        userEmail = u['email'] ?? '';
      }

      if (json.containsKey('tasks')) {
        final tlist = json['tasks'] as List<dynamic>;
        allTasks = tlist
            .map((e) => TaskModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } else {
        allTasks = [];
      }

      if (json.containsKey('currentTask')) {
        currentTask = TaskModel.fromJson(
            Map<String, dynamic>.from(json['currentTask'] as Map));
        workPeriods = List<WorkPeriod>.from(currentTask!.workPeriods);
        idlePeriods = List<IdlePeriod>.from(currentTask!.idlePeriods);
        // compute totalWorkedSeconds from workPeriods
        double worked = 0;
        for (var p in workPeriods) {
          if (p.endTime != null) {
            worked += p.endTime!.difference(p.startTime).inSeconds;
          }
        }
        totalWorkedSeconds = worked;
      } else {
        currentTask = null;
        workPeriods = [];
        idlePeriods = [];
      }
    } catch (e) {
      // if parse error just start clean
      userName = '';
      userEmail = '';
      currentTask = null;
      allTasks = [];
      workPeriods = [];
      idlePeriods = [];
    }

    startTimers();
  }

  // -------------------------
  // Persistence
  // -------------------------

  Future<void> _persistAll() async {
    final map = <String, dynamic>{};
    map['user'] = {'name': userName, 'email': userEmail};
    map['tasks'] = allTasks.map((t) => t.toJson()).toList();
    if (currentTask != null) {
      map['currentTask'] = currentTask!.toJson();
    }
    await Storage.writeJson(map);
  }

  // -------------------------
  // Core app methods
  // -------------------------

  void login(String name, String email) {
    userName = name;
    userEmail = email;

    // create initial task on login
    final task = TaskModel(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      userId: email,
      startTime: DateTime.now(),
      description: 'Initial Work Session',
      workPeriods: [],
      idlePeriods: [],
      status: 'active',
    );
    final wp = WorkPeriod(
      id: 'wp_${DateTime.now().millisecondsSinceEpoch}',
      startTime: DateTime.now(),
      description: 'Session started',
    );
    task.workPeriods = [wp];

    currentTask = task;
    workPeriods = [wp];
    idlePeriods = [];
    elapsedSeconds = 0;
    totalWorkedSeconds = 0;
    isIdle = false;
    lastActivity = DateTime.now();

    // append to all tasks
    allTasks.add(task);

    currentScreen = 'dashboard';

    // persist
    _persistAll();

    startTimers();
    notifyListeners();
  }

  void startTimers() {
    stopTimers();
    ticker = Timer.periodic(Duration(seconds: 1), (_) {
      if (!isIdle && currentScreen == 'dashboard') {
        elapsedSeconds++;
        notifyListeners();
      }
    });

    idleChecker = Timer.periodic(Duration(seconds: 5), (_) {
      final idleDuration = DateTime.now().difference(lastActivity).inSeconds;
      if (idleDuration >= idleThresholdSeconds && !isIdle && currentScreen == 'dashboard') {
        // record idle
        _startIdleAt(lastActivity);
        notifyListeners();
      }
    });

    // hourly prompt
    hourlyPromptTimer = Timer.periodic(hourlyPromptInterval, (_) {
      if (currentScreen == 'dashboard' && !isIdle) {
        showHourlyPrompt = true;
        notifyListeners();
      }
    });
  }

  void stopTimers() {
    ticker?.cancel();
    idleChecker?.cancel();
    hourlyPromptTimer?.cancel();
  }

  void recordActivity() {
    lastActivity = DateTime.now();
    if (isIdle) {
      // leave isIdle true; we require user to recover via recoverFromIdle to resume
    }
    notifyListeners();
  }

  // used by idleChecker or by lifecycle when app goes to background
  void _startIdleAt(DateTime start) {
    isIdle = true;

    // close current work period if open
    if (workPeriods.isNotEmpty) {
      final last = workPeriods.last;
      if (last.endTime == null) {
        last.endTime = start;
        totalWorkedSeconds += last.endTime!.difference(last.startTime).inSeconds;
      }
    }

    final idle = IdlePeriod(
      id: 'idle_${DateTime.now().millisecondsSinceEpoch}',
      startTime: start,
    );
    idlePeriods = [...idlePeriods, idle];

    // update currentTask object
    if (currentTask != null) {
      currentTask = TaskModel(
        id: currentTask!.id,
        userId: currentTask!.userId,
        startTime: currentTask!.startTime,
        endTime: currentTask!.endTime,
        description: currentTask!.description,
        category: currentTask!.category,
        tags: currentTask!.tags,
        status: 'idle',
        workPeriods: workPeriods,
        idlePeriods: idlePeriods,
      );
    }

    _persistAll();
  }

  /// Called when user provides description after idle (sleep recovery)
  void recoverFromIdle(String description) {
    if (description.trim().isEmpty) return;

    // attach description to the last work period if exists
    if (workPeriods.isNotEmpty) {
      workPeriods.last.description = description.trim();
    }

    // close last idle
    if (idlePeriods.isNotEmpty) {
      final lastIdle = idlePeriods.last;
      if (lastIdle.endTime == null) {
        lastIdle.endTime = DateTime.now();
      }
    }

    // start new work period
    final newwp = WorkPeriod(
      id: 'wp_${DateTime.now().millisecondsSinceEpoch}',
      startTime: DateTime.now(),
      description: 'Resumed after break',
    );
    workPeriods = [...workPeriods, newwp];

    isIdle = false;
    lastActivity = DateTime.now();

    // update currentTask persisted snapshot
    if (currentTask != null) {
      currentTask = TaskModel(
        id: currentTask!.id,
        userId: currentTask!.userId,
        startTime: currentTask!.startTime,
        endTime: currentTask!.endTime,
        description: currentTask!.description,
        category: currentTask!.category,
        tags: currentTask!.tags,
        status: 'active',
        workPeriods: workPeriods,
        idlePeriods: idlePeriods,
      );
    }

    _persistAll();
    notifyListeners();
  }

  /// Called by Hourly Prompt dialog
  void addHourlyDescription(String description) {
    if (description.trim().isEmpty) return;

    if (workPeriods.isNotEmpty) {
      final last = workPeriods.last;
      if (last.endTime == null) {
        final now = DateTime.now();
        last.endTime = now;
        last.description = description.trim();
        totalWorkedSeconds += last.endTime!.difference(last.startTime).inSeconds;
      }
    }

    final newp = WorkPeriod(
      id: 'wp_${DateTime.now().millisecondsSinceEpoch}',
      startTime: DateTime.now(),
      description: 'Continuing work',
    );
    workPeriods = [...workPeriods, newp];
    showHourlyPrompt = false;

    // update currentTask object & persist
    if (currentTask != null) {
      currentTask = TaskModel(
        id: currentTask!.id,
        userId: currentTask!.userId,
        startTime: currentTask!.startTime,
        endTime: currentTask!.endTime,
        description: currentTask!.description,
        category: currentTask!.category,
        tags: currentTask!.tags,
        status: 'active',
        workPeriods: workPeriods,
        idlePeriods: idlePeriods,
      );
    }

    _persistAll();
    notifyListeners();
  }

  void createNewTask(String desc, String category, List<String> tags) {
    if (desc.trim().isEmpty) return;
    // save currentTask as completed snapshot
    saveCurrentTask();

    final task = TaskModel(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      userId: userEmail,
      startTime: DateTime.now(),
      description: desc.trim(),
      category: category,
      tags: tags,
      status: 'active',
      workPeriods: [],
      idlePeriods: [],
    );

    final wp = WorkPeriod(
      id: 'wp_${DateTime.now().millisecondsSinceEpoch}',
      startTime: DateTime.now(),
      description: 'Task started',
    );

    task.workPeriods = [wp];

    currentTask = task;
    workPeriods = [wp];
    idlePeriods = [];
    elapsedSeconds = 0;
    totalWorkedSeconds = 0;
    isIdle = false;
    lastActivity = DateTime.now();

    allTasks = [...allTasks, task];
    _persistAll();
    notifyListeners();
  }

  void saveCurrentTask() {
    if (currentTask == null) return;

    final updated = TaskModel(
      id: currentTask!.id,
      userId: currentTask!.userId,
      startTime: currentTask!.startTime,
      endTime: DateTime.now(),
      description: currentTask!.description,
      category: currentTask!.category,
      tags: currentTask!.tags,
      status: 'completed',
      workPeriods: [...workPeriods],
      idlePeriods: [...idlePeriods],
    );

    final index = allTasks.indexWhere((t) => t.id == updated.id);
    if (index != -1) {
      allTasks[index] = updated;
    } else {
      allTasks.add(updated);
    }
    currentTask = updated;
    _persistAll();
    notifyListeners();
  }

  void completeCurrentTask() {
    if (currentTask == null) return;

    if (workPeriods.isNotEmpty) {
      final last = workPeriods.last;
      if (last.endTime == null) {
        last.endTime = DateTime.now();
      }
    }

    final completed = TaskModel(
      id: currentTask!.id,
      userId: currentTask!.userId,
      startTime: currentTask!.startTime,
      endTime: DateTime.now(),
      description: currentTask!.description,
      category: currentTask!.category,
      tags: currentTask!.tags,
      status: 'completed',
      workPeriods: [...workPeriods],
      idlePeriods: [...idlePeriods],
    );

    final index = allTasks.indexWhere((t) => t.id == completed.id);
    if (index != -1) {
      allTasks[index] = completed;
    } else {
      allTasks.add(completed);
    }
    currentTask = completed;
    _persistAll();
    notifyListeners();
  }

  void switchToTask(TaskModel task) {
    saveCurrentTask();
    currentTask = task;
    workPeriods = List<WorkPeriod>.from(task.workPeriods);
    idlePeriods = List<IdlePeriod>.from(task.idlePeriods);
    double worked = 0;
    for (var p in task.workPeriods) {
      if (p.endTime != null) {
        worked += p.endTime!.difference(p.startTime).inSeconds;
      } else {
        worked += DateTime.now().difference(p.startTime).inSeconds;
      }
    }
    totalWorkedSeconds = worked;
    elapsedSeconds = 0;
    isIdle = task.status == 'idle';
    lastActivity = DateTime.now();
    if (task.status != 'completed') {
      final newPeriod = WorkPeriod(
        id: 'wp_${DateTime.now().millisecondsSinceEpoch}',
        startTime: DateTime.now(),
        description: 'Resumed task',
      );
      workPeriods = [...workPeriods, newPeriod];
    }
    _persistAll();
    notifyListeners();
  }

  void deleteTask(String id) {
    final isCurrent = currentTask != null && currentTask!.id == id;
    allTasks = allTasks.where((t) => t.id != id).toList();
    if (isCurrent) {
      if (allTasks.isNotEmpty) {
        switchToTask(allTasks.first);
      } else {
        final task = TaskModel(
          id: 'task_${DateTime.now().millisecondsSinceEpoch}',
          userId: userEmail,
          startTime: DateTime.now(),
          description: 'New Work Session',
        );
        final wp = WorkPeriod(
          id: 'wp_${DateTime.now().millisecondsSinceEpoch}',
          startTime: DateTime.now(),
          description: 'Session started',
        );
        task.workPeriods = [wp];
        currentTask = task;
        workPeriods = [wp];
        idlePeriods = [];
        elapsedSeconds = 0;
        totalWorkedSeconds = 0;
        allTasks = [task];
      }
    }
    _persistAll();
    notifyListeners();
  }

  /// Calculate final report (and persist current task)
  Map<String, dynamic> endSessionReport() {
    saveCurrentTask();

    double finalWorkTime = 0;
    for (var p in workPeriods) {
      if (p.endTime != null) {
        finalWorkTime += p.endTime!.difference(p.startTime).inSeconds;
      } else {
        finalWorkTime += DateTime.now().difference(p.startTime).inSeconds;
      }
    }
    double totalIdle = 0;
    for (var ip in idlePeriods) {
      if (ip.endTime != null) totalIdle += ip.endTime!.difference(ip.startTime).inSeconds;
    }

    final report = {
      'totalWorkedHours': (finalWorkTime / 3600.0).toStringAsFixed(2),
      'totalIdleHours': (totalIdle / 3600.0).toStringAsFixed(2),
      'workPeriods': workPeriods.length,
      'idlePeriods': idlePeriods.length,
      'totalTasks': allTasks.length,
      'date': currentTask?.startTime.toIso8601String() ?? DateTime.now().toIso8601String(),
      // include detailed work periods for emailing
      'details': currentTask?.toJson() ?? {},
    };

    return report;
  }

  /// Compose email body and open mail client with prefilled body (user sends manually)
  Future<void> sendReportEmail() async {
    final report = endSessionReport();
    final subject = Uri.encodeComponent('Work Session Report - ${report['date']}');
    final buffer = StringBuffer();
    buffer.writeln('Total Tasks: ${report['totalTasks']}');
    buffer.writeln('Total Worked Hours: ${report['totalWorkedHours']}');
    buffer.writeln('Total Idle Hours: ${report['totalIdleHours']}');
    buffer.writeln('');
    buffer.writeln('Details:');
    final details = report['details'] as Map<String, dynamic>;
    buffer.writeln(json.encode(details)); // include JSON details
    final body = Uri.encodeComponent(buffer.toString());
    final mailto = 'mailto:$userEmail?subject=$subject&body=$body';
    if (await canLaunch(mailto)) {
      await launch(mailto);
    }
  }

  void logoutAndReset() {
    stopTimers();
    userName = '';
    userEmail = '';
    currentScreen = 'login';
    currentTask = null;
    allTasks = [];
    workPeriods = [];
    idlePeriods = [];
    isIdle = false;
    elapsedSeconds = 0;
    totalWorkedSeconds = 0;
    lastActivity = DateTime.now();
    _persistAll();
    notifyListeners();
  }

  // -------------------------
  // Helpers for "today" calculations
  // -------------------------

  /// returns all tasks whose startTime is today (local)
  List<TaskModel> tasksForToday() {
    final now = DateTime.now();
    return allTasks.where((t) {
      final st = t.startTime;
      return st.year == now.year && st.month == now.month && st.day == now.day;
    }).toList();
  }

  /// total active seconds for today across all tasks (exclude idle)
  int totalActiveSecondsForToday() {
    final tasks = tasksForToday();
    int total = 0;
    for (var t in tasks) {
      for (var wp in t.workPeriods) {
        if (wp.endTime != null) {
          total += wp.endTime!.difference(wp.startTime).inSeconds;
        } else {
          total += DateTime.now().difference(wp.startTime).inSeconds;
        }
      }
      for (var ip in t.idlePeriods) {
        if (ip.endTime != null) {
          total -= ip.endTime!.difference(ip.startTime).inSeconds;
        } else {
          // if idle still ongoing - subtract until now
          total -= DateTime.now().difference(ip.startTime).inSeconds;
        }
      }
    }
    if (total < 0) total = 0;
    return total;
  }
}

class JobReportApp extends StatefulWidget {
  @override
  State<JobReportApp> createState() => _JobReportAppState();
}

/// Lifecycle watcher to detect app paused/resume (sleep recovery)
class _JobReportAppState extends State<JobReportApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final appState = Provider.of<AppState>(context, listen: false);
    if (state == AppLifecycleState.paused) {
      // user left app -> mark lastActivity timestamp
      appState.lastActivity = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // app came back: if the away time > idleThreshold -> create idle period and ask for recovery
      final away = DateTime.now().difference(appState.lastActivity).inSeconds;
      if (away >= appState.idleThresholdSeconds && appState.currentScreen == 'dashboard') {
        // start idle at the lastActivity time and set isIdle
        appState._startIdleAt(appState.lastActivity);
        // present Idle Recovery by setting isIdle flag — UI will show dialog if it checks isIdle
        // The IdleRecoveryDialog in widgets will check appState.isIdle and show prompt in UI layer
        appState.notifyListeners();
      } else {
        // otherwise update lastActivity
        appState.lastActivity = DateTime.now();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: Provider.of<AppState>(context),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Job Report',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: RootRouter(),
      ),
    );
  }
}

class RootRouter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, state, _) {
      switch (state.currentScreen) {
        case 'login':
          return LoginScreen();
        case 'dashboard':
          return DashboardScreen();
        case 'details':
          return DetailsScreen();
        default:
          return LoginScreen();
      }
    });
  }
}




























// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'models/task.dart';
// import 'screens/login_screen.dart';
// import 'screens/dashboard_screen.dart';
// import 'screens/details_screen.dart';

// void main() {
//   runApp(JobReportApp());
// }

// class AppState extends ChangeNotifier {
//   String userName = '';
//   String userEmail = '';
//   String currentScreen = 'login';
//   TaskModel? currentTask;
//   List<TaskModel> allTasks = [];
//   List<WorkPeriod> workPeriods = [];
//   List<IdlePeriod> idlePeriods = [];
//   bool isIdle = false;
//   DateTime lastActivity = DateTime.now();
//   int elapsedSeconds = 0;
//   double totalWorkedSeconds = 0;
//   Timer? ticker;
//   Timer? idleChecker;
//   Timer? hourlyPromptTimer;

//   bool showHourlyPrompt = false;

//   AppState() {
//   }

//   void login(String name, String email) {
//     userName = name;
//     userEmail = email;
//     final task = TaskModel(
//       id: 'task_${DateTime.now().millisecondsSinceEpoch}',
//       userId: email,
//       startTime: DateTime.now(),
//       description: 'Initial Work Session',
//       workPeriods: [],
//       idlePeriods: [],
//       status: 'active',
//     );
//     final wp = WorkPeriod(
//       id: 'wp_${DateTime.now().millisecondsSinceEpoch}',
//       startTime: DateTime.now(),
//       description: 'Session started',
//     );
//     task.workPeriods = [wp];
//     currentTask = task;
//     workPeriods = [wp];
//     allTasks = [task];
//     currentScreen = 'dashboard';
//     lastActivity = DateTime.now();
//     startTimers();
//     notifyListeners();
//   }

//   void startTimers() {
//     stopTimers();
//     ticker = Timer.periodic(Duration(seconds: 1), (_) {
//       if (!isIdle && currentScreen == 'dashboard') {
//         elapsedSeconds++;
//         notifyListeners();
//       }
//     });

//     idleChecker = Timer.periodic(Duration(seconds: 5), (_) {
//       final idleDuration = DateTime.now().difference(lastActivity).inSeconds;
//       if (idleDuration >= 30 && !isIdle && currentScreen == 'dashboard') {
//         goIdle();
//       }
//     });

//     hourlyPromptTimer = Timer.periodic(Duration(minutes: 2), (_) {
//       if (currentScreen == 'dashboard' && !isIdle) {
//         showHourlyPrompt = true;
//         notifyListeners();
//       }
//     });
//   }

//   void stopTimers() {
//     ticker?.cancel();
//     idleChecker?.cancel();
//     hourlyPromptTimer?.cancel();
//   }

//   void recordActivity() {
//     lastActivity = DateTime.now();
//     if (isIdle) {
//     }
//     notifyListeners();
//   }

//   void goIdle() {
//     isIdle = true;
//     if (workPeriods.isNotEmpty) {
//       final last = workPeriods.last;
//       if (last.endTime == null) {
//         last.endTime = lastActivity;
//         totalWorkedSeconds += last.endTime!.difference(last.startTime).inSeconds;
//       }
//     }
//     final idle = IdlePeriod(
//       id: 'idle_${DateTime.now().millisecondsSinceEpoch}',
//       startTime: lastActivity,
//     );
//     idlePeriods = [...idlePeriods, idle];
//     notifyListeners();
//   }

//   void recoverFromIdle(String description) {
//     if (description.trim().isEmpty) return;
//     if (workPeriods.isNotEmpty) {
//       workPeriods.last.description = description;
//     }
//     if (idlePeriods.isNotEmpty) {
//       final lastIdle = idlePeriods.last;
//       if (lastIdle.endTime == null) {
//         lastIdle.endTime = DateTime.now();
//       }
//     }
//     final nwp = WorkPeriod(
//       id: 'wp_${DateTime.now().millisecondsSinceEpoch}',
//       startTime: DateTime.now(),
//       description: 'Resumed after break',
//     );
//     workPeriods = [...workPeriods, nwp];
//     isIdle = false;
//     lastActivity = DateTime.now();
//     notifyListeners();
//   }

//   void addHourlyDescription(String description) {
//     if (description.trim().isEmpty) return;
//     if (workPeriods.isNotEmpty) {
//       final last = workPeriods.last;
//       if (last.endTime == null) {
//         final now = DateTime.now();
//         last.endTime = now;
//         last.description = description;
//         totalWorkedSeconds += last.endTime!.difference(last.startTime).inSeconds;
//       }
//     }
//     final newp = WorkPeriod(
//       id: 'wp_${DateTime.now().millisecondsSinceEpoch}',
//       startTime: DateTime.now(),
//       description: 'Continuing work',
//     );
//     workPeriods = [...workPeriods, newp];
//     showHourlyPrompt = false;
//     notifyListeners();
//   }

//   void createNewTask(String desc, String category, List<String> tags) {
//     if (desc.trim().isEmpty) return;
//     saveCurrentTask();
//     final task = TaskModel(
//       id: 'task_${DateTime.now().millisecondsSinceEpoch}',
//       userId: userEmail,
//       startTime: DateTime.now(),
//       description: desc.trim(),
//       category: category,
//       tags: tags,
//       status: 'active',
//     );
//     final wp = WorkPeriod(
//       id: 'wp_${DateTime.now().millisecondsSinceEpoch}',
//       startTime: DateTime.now(),
//       description: 'Task started',
//     );
//     task.workPeriods = [wp];
//     currentTask = task;
//     workPeriods = [wp];
//     idlePeriods = [];
//     elapsedSeconds = 0;
//     totalWorkedSeconds = 0;
//     isIdle = false;
//     lastActivity = DateTime.now();
//     allTasks = [...allTasks, task];
//     notifyListeners();
//   }

//   void saveCurrentTask() {
//     if (currentTask == null) return;
//     final updated = TaskModel(
//       id: currentTask!.id,
//       userId: currentTask!.userId,
//       startTime: currentTask!.startTime,
//       endTime: DateTime.now(),
//       description: currentTask!.description,
//       category: currentTask!.category,
//       tags: currentTask!.tags,
//       status: 'completed',
//       workPeriods: [...workPeriods],
//       idlePeriods: [...idlePeriods],
//     );
//     final index = allTasks.indexWhere((t) => t.id == updated.id);
//     if (index != -1) {
//       final copy = [...allTasks];
//       copy[index] = updated;
//       allTasks = copy;
//     } else {
//       allTasks = [...allTasks, updated];
//     } 
//     currentTask = updated;
//     notifyListeners();
//   }

//   void completeCurrentTask() {
//     if (currentTask == null) return;
//     if (workPeriods.isNotEmpty) {
//       final last = workPeriods.last;
//       if (last.endTime == null) {
//         last.endTime = DateTime.now();
//       }
//     }
//     final completed = TaskModel(
//       id: currentTask!.id,
//       userId: currentTask!.userId,
//       startTime: currentTask!.startTime,
//       endTime: DateTime.now(),
//       description: currentTask!.description,
//       category: currentTask!.category,
//       tags: currentTask!.tags,
//       status: 'completed',
//       workPeriods: [...workPeriods],
//       idlePeriods: [...idlePeriods],
//     );
//     final index = allTasks.indexWhere((t) => t.id == completed.id);
//     if (index != -1) {
//       final copy = [...allTasks];
//       copy[index] = completed;
//       allTasks = copy;
//     }
//     currentTask = completed;
//     notifyListeners();
//   }

//   void switchToTask(TaskModel task) {
//     saveCurrentTask();
//     currentTask = task;
//     workPeriods = [...task.workPeriods];
//     idlePeriods = [...task.idlePeriods];
//     double worked = 0;
//     for (var p in task.workPeriods) {
//       if (p.endTime != null) {
//         worked += p.endTime!.difference(p.startTime).inSeconds;
//       }
//     }
//     totalWorkedSeconds = worked;
//     elapsedSeconds = 0;
//     isIdle = task.status == 'idle';
//     lastActivity = DateTime.now();
//     if (task.status != 'completed') {
//       final newPeriod = WorkPeriod(
//         id: 'wp_${DateTime.now().millisecondsSinceEpoch}',
//         startTime: DateTime.now(),
//         description: 'Resumed task',
//       );
//       workPeriods = [...workPeriods, newPeriod];
//     }
//     notifyListeners();
//   }

//   void deleteTask(String id) {
//     final isCurrent = currentTask != null && currentTask!.id == id;
//     allTasks = allTasks.where((t) => t.id != id).toList();
//     if (isCurrent) {
//       if (allTasks.isNotEmpty) {
//         switchToTask(allTasks.first);
//       } else {
//         final task = TaskModel(
//           id: 'task_${DateTime.now().millisecondsSinceEpoch}',
//           userId: userEmail,
//           startTime: DateTime.now(),
//           description: 'New Work Session',
//         );
//         final wp = WorkPeriod(
//           id: 'wp_${DateTime.now().millisecondsSinceEpoch}',
//           startTime: DateTime.now(),
//           description: 'Session started',
//         );
//         task.workPeriods = [wp];
//         currentTask = task;
//         workPeriods = [wp];
//         idlePeriods = [];
//         elapsedSeconds = 0;
//         totalWorkedSeconds = 0;
//         allTasks = [task];
//       }
//     }
//     notifyListeners();
//   }

//   Map<String, dynamic> endSessionReport() {
//     saveCurrentTask();
//     double finalWorkTime = 0;
//     for (var p in workPeriods) {
//       if (p.endTime != null) {
//         finalWorkTime += p.endTime!.difference(p.startTime).inSeconds;
//       } else {
//         finalWorkTime += DateTime.now().difference(p.startTime).inSeconds;
//       }
//     }
//     double totalIdle = 0;
//     for (var ip in idlePeriods) {
//       if (ip.endTime != null) {
//         totalIdle += ip.endTime!.difference(ip.startTime).inSeconds;
//       }
//     }
//     final report = {
//       'totalWorkedHours': (finalWorkTime / 3600.0).toStringAsFixed(2),
//       'totalIdleHours': (totalIdle / 3600.0).toStringAsFixed(2),
//       'workPeriods': workPeriods.length,
//       'idlePeriods': idlePeriods.length,
//       'totalTasks': allTasks.length,
//       'date': currentTask?.startTime.toIso8601String() ?? DateTime.now().toIso8601String(),
//     };
//     return report;
//   }

//   void logoutAndReset() {
//     stopTimers();
//     userName = '';
//     userEmail = '';
//     currentScreen = 'login';
//     currentTask = null;
//     allTasks = [];
//     workPeriods = [];
//     idlePeriods = [];
//     isIdle = false;
//     elapsedSeconds = 0;
//     totalWorkedSeconds = 0;
//     lastActivity = DateTime.now();
//     notifyListeners();
//   }
// }

// class JobReportApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return ChangeNotifierProvider(
//       create: (_) => AppState(),
//       child: MaterialApp(
//         debugShowCheckedModeBanner: false,
//         title: 'Job Report',
//         theme: ThemeData(
//           primarySwatch: Colors.blue,
//         ),
//         home: RootRouter(),
//       ),
//     );
//   }
// }

// class RootRouter extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<AppState>(builder: (context, state, _) {
//       switch (state.currentScreen) {
//         case 'login':
//           return LoginScreen();
//         case 'dashboard':
//           return DashboardScreen();
//         case 'details':
//           return DetailsScreen();
//         default:
//           return LoginScreen();
//       }
//     });
//   }
// }
