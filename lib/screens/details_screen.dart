import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../utils/time_utils.dart';

class DetailsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () {
          state.currentScreen = 'dashboard';
          state.notifyListeners();
        }),
        title: Text('Task Details'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  children: [
                    _row('Task ID', state.currentTask?.id.substring(state.currentTask!.id.length - 8) ?? '-'),
                    _row('Description', state.currentTask?.description ?? '-'),
                    _row('Category', state.currentTask?.category ?? '-'),
                    _row('Tags', state.currentTask?.tags.join(', ') ?? '-'),
                    _row('Started', state.currentTask != null ? formatDateTimeLong(state.currentTask!.startTime) : '-'),
                    _row('Status', state.currentTask?.status ?? '-'),
                    _row('Total Active Time', formatTime(state.totalWorkedSeconds.toInt() + (state.isIdle ? 0 : state.elapsedSeconds))),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: Text('Work Periods', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            SizedBox(height: 8),
            Column(
              children: state.workPeriods.map((p) {
                return Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Chip(label: Text('Period')),
                          Text(formatDurationBetween(p.startTime, p.endTime)),
                        ]),
                        SizedBox(height: 8),
                        Row(children: [
                          Icon(Icons.play_arrow, color: Colors.green),
                          SizedBox(width: 8),
                          Text(formatDateTimeShort(p.startTime)),
                        ]),
                        SizedBox(height: 6),
                        p.endTime != null
                          ? Row(children: [Icon(Icons.pause, color: Colors.red), SizedBox(width: 8), Text(formatDateTimeShort(p.endTime!))])
                          : Row(children: [Icon(Icons.access_time, color: Colors.orange), SizedBox(width: 8), Text('Ongoing', style: TextStyle(color: Colors.orange))]),
                        if (p.description != null && p.description!.isNotEmpty)
                          Container(margin: EdgeInsets.only(top: 8), padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)), child: Text(p.description!)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            if (state.idlePeriods.isNotEmpty) ...[
              SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: Text('Idle Periods', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
              SizedBox(height: 8),
              Column(
                children: state.idlePeriods.map((idle) {
                  return Card(
                    color: Colors.orange[50],
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Chip(label: Text('Idle')),
                            Text(formatDurationBetween(idle.startTime, idle.endTime)),
                          ]),
                          SizedBox(height: 8),
                          Row(children: [Icon(Icons.pause, color: Colors.orange), SizedBox(width: 8), Text(formatDateTimeShort(idle.startTime))]),
                          if (idle.endTime != null) SizedBox(height: 6),
                          if (idle.endTime != null) Row(children: [Icon(Icons.play_arrow, color: Colors.green), SizedBox(width: 8), Text(formatDateTimeShort(idle.endTime!))]),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              )
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String left, String right) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(left, style: TextStyle(color: Colors.grey[700])), Flexible(child: Text(right, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold)))]),
    );
  }
}
