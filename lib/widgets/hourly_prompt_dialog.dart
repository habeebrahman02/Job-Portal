import 'package:flutter/material.dart';

class HourlyPromptDialog extends StatefulWidget {
  final String initialText;
  final void Function(String) onSubmit;
  final VoidCallback onCancel;

  HourlyPromptDialog({
    this.initialText = '',
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<HourlyPromptDialog> createState() => _HourlyPromptDialogState();
}

class _HourlyPromptDialogState extends State<HourlyPromptDialog> {
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
      title: Row(children: [Icon(Icons.access_time, color: Colors.blue), SizedBox(width: 8), Text('Hourly Check-in')]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('What have you been working on this hour?'),
        SizedBox(height: 8),
        TextField(controller: _ctl, maxLines: 4, decoration: InputDecoration(hintText: 'Describe your work...')),
      ]),
      actions: [
        TextButton(onPressed: widget.onCancel, child: Text('Skip')),
        ElevatedButton(onPressed: () {
          widget.onSubmit(_ctl.text.trim());
        }, child: Text('Submit'))
      ],
    );
  }
}



















// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../main.dart';

// class HourlyPromptDialog extends StatefulWidget {
//   @override
//   State<HourlyPromptDialog> createState() => _HourlyPromptDialogState();
// }

// class _HourlyPromptDialogState extends State<HourlyPromptDialog> {
//   final _ctl = TextEditingController();

//   @override
//   Widget build(BuildContext context) {
//     final state = Provider.of<AppState>(context);
//     if (!state.showHourlyPrompt) return SizedBox.shrink();

//     return AlertDialog(
//       title: Row(children: [Icon(Icons.access_time, color: Colors.blue), SizedBox(width: 8), Text('Hourly Check-in')]),
//       content: Column(mainAxisSize: MainAxisSize.min, children: [
//         Text('What have you been working on this hour?'),
//         SizedBox(height: 8),
//         TextField(controller: _ctl, maxLines: 4, decoration: InputDecoration(hintText: 'Describe your work...')),
//       ]),
//       actions: [
//         TextButton(onPressed: () {
//           state.showHourlyPrompt = false;
//           state.notifyListeners();
//         }, child: Text('Skip')),
//         ElevatedButton(onPressed: () {
//           state.addHourlyDescription(_ctl.text.trim());
//           Navigator.pop(context);
//         }, child: Text('Submit'))
//       ],
//     );
//   }
// }
