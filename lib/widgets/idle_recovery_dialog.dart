import 'package:flutter/material.dart';

class IdleRecoveryDialog extends StatefulWidget {
  final String initialText;
  final void Function(String) onSubmit;
  final VoidCallback onCancel;

  IdleRecoveryDialog({
    this.initialText = '',
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<IdleRecoveryDialog> createState() => _IdleRecoveryDialogState();
}

class _IdleRecoveryDialogState extends State<IdleRecoveryDialog> {
  late TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [Icon(Icons.pause_circle_filled, color: Colors.orange), SizedBox(width: 8), Text('System was Idle')]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Your system was idle. What were you working on before the break?'),
        SizedBox(height: 8),
        TextField(controller: _ctl, maxLines: 4, decoration: InputDecoration(hintText: 'Describe your work...')),
      ]),
      actions: [
        TextButton(onPressed: widget.onCancel, child: Text('Ignore')),
        ElevatedButton(onPressed: () {
          widget.onSubmit(_ctl.text.trim());
        }, child: Text('Resume Work'))
      ],
    );
  }
}



















// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../main.dart';

// class IdleRecoveryDialog extends StatefulWidget {
//   @override
//   State<IdleRecoveryDialog> createState() => _IdleRecoveryDialogState();
// }

// class _IdleRecoveryDialogState extends State<IdleRecoveryDialog> {
//   final _ctl = TextEditingController();

//   @override
//   Widget build(BuildContext context) {
//     final state = Provider.of<AppState>(context);
//     if (!state.isIdle) return SizedBox.shrink();

//     return AlertDialog(
//       title: Row(children: [Icon(Icons.pause_circle_filled, color: Colors.orange), SizedBox(width: 8), Text('System was Idle')]),
//       content: Column(mainAxisSize: MainAxisSize.min, children: [
//         Text('Your system was idle for more than 30 seconds. What were you working on before the break?'),
//         SizedBox(height: 8),
//         TextField(controller: _ctl, maxLines: 4, decoration: InputDecoration(hintText: 'Describe your work...')),
//       ]),
//       actions: [
//         TextButton(onPressed: () {
//           Navigator.pop(context);
//         }, child: Text('Ignore')),
//         ElevatedButton(onPressed: () {
//           state.recoverFromIdle(_ctl.text.trim());
//           Navigator.pop(context);
//         }, child: Text('Resume Work'))
//       ],
//     );
//   }
// }
