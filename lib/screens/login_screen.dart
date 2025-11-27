import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();

  String? _nameError;
  String? _emailError;

  // simple email regex (covers typical addresses, not exhaustive)
  final _emailRegExp = RegExp(r"^[\w\.-]+@[\w\.-]+\.\w{2,}$");

  @override
  void initState() {
    super.initState();

    _nameCtl.addListener(() {
      _validateName(_nameCtl.text);
      setState(() {});
    });
    _emailCtl.addListener(() {
      _validateEmail(_emailCtl.text);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    super.dispose();
  }

  void _validateName(String value) {
    final v = value.trim();
    if (v.isEmpty) {
      _nameError = 'Name is required';
    } else if (v.length < 2) {
      _nameError = 'Enter at least 2 characters';
    } else {
      _nameError = null;
    }
  }

  void _validateEmail(String value) {
    final v = value.trim();
    if (v.isEmpty) {
      _emailError = 'Email is required';
    } else if (!_emailRegExp.hasMatch(v)) {
      _emailError = 'Enter a valid email address';
    } else {
      _emailError = null;
    }
  }

  bool get _isFormValid {
    return (_nameError == null) && (_emailError == null) && _nameCtl.text.trim().isNotEmpty && _emailCtl.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF60A5FA), Color(0xFF1E40AF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Card(
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.work_outline, size: 56, color: Colors.blue),
                    SizedBox(height: 12),
                    Text(
                      'Job Report App',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Track your daily tasks and work hours',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    SizedBox(height: 16),

                    // Name field
                    TextField(
                      controller: _nameCtl,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.person),
                        labelText: 'Full Name',
                        errorText: _nameError,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    SizedBox(height: 8),

                    // Email field
                    TextField(
                      controller: _emailCtl,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.email),
                        labelText: 'Email',
                        errorText: _emailError,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                    ),
                    SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isFormValid
                            ? () {
                                // final validation run before submitting
                                _validateName(_nameCtl.text);
                                _validateEmail(_emailCtl.text);
                                if (_isFormValid) {
                                  state.login(
                                    _nameCtl.text.trim(),
                                    _emailCtl.text.trim(),
                                  );
                                } else {
                                  setState(() {});
                                }
                              }
                            : null,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('Start Work Session'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



















// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../main.dart';

// class LoginScreen extends StatefulWidget {
//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }

// class _LoginScreenState extends State<LoginScreen> {
//   final _nameCtl = TextEditingController();
//   final _emailCtl = TextEditingController();

//   @override
//   void initState() {
//     super.initState();

//     _nameCtl.addListener(() => setState(() {}));
//     _emailCtl.addListener(() => setState(() {}));
//   }

//   @override
//   void dispose() {
//     _nameCtl.dispose();
//     _emailCtl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final state = Provider.of<AppState>(context, listen: false);

//     return Scaffold(
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Color(0xFF60A5FA), Color(0xFF1E40AF)],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//         ),
//         child: Center(
//           child: Card(
//             margin: EdgeInsets.all(16),
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
//             child: Padding(
//               padding: EdgeInsets.all(20),
//               child: SizedBox(
//                 width: 420,
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(Icons.work_outline, size: 56, color: Colors.blue),
//                     SizedBox(height: 12),
//                     Text(
//                       'Job Report App',
//                       style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue[800]),
//                     ),
//                     SizedBox(height: 8),
//                     Text(
//                       'Track your daily tasks and work hours',
//                       style: TextStyle(color: Colors.grey[700]),
//                     ),
//                     SizedBox(height: 16),

//                     TextField(
//                       controller: _nameCtl,
//                       decoration: InputDecoration(prefixIcon: Icon(Icons.person), labelText: 'Full Name'),
//                     ),
//                     SizedBox(height: 8),

//                     TextField(
//                       controller: _emailCtl,
//                       decoration: InputDecoration(prefixIcon: Icon(Icons.email), labelText: 'Email'),
//                       keyboardType: TextInputType.emailAddress,
//                     ),
//                     SizedBox(height: 12),

//                     SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton(
//                         onPressed: _nameCtl.text.trim().isNotEmpty &&
//                                 _emailCtl.text.trim().isNotEmpty
//                             ? () {
//                                 state.login(
//                                   _nameCtl.text.trim(),
//                                   _emailCtl.text.trim(),
//                                 );
//                               }
//                             : null,
//                         child: Padding(
//                           padding: EdgeInsets.symmetric(vertical: 14),
//                           child: Text('Start Work Session'),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }



























// // lib/screens/login_screen.dart
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../main.dart';

// class LoginScreen extends StatefulWidget {
//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }

// class _LoginScreenState extends State<LoginScreen> {
//   final _nameCtl = TextEditingController();
//   final _emailCtl = TextEditingController();

//   @override
//   void dispose() {
//     _nameCtl.dispose();
//     _emailCtl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final state = Provider.of<AppState>(context, listen: false);

//     return Scaffold(
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(colors: [Color(0xFF60A5FA), Color(0xFF1E40AF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
//         ),
//         child: Center(
//           child: Card(
//             margin: EdgeInsets.all(16),
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
//             child: Padding(
//               padding: EdgeInsets.all(20),
//               child: SizedBox(
//                 width: 420,
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(Icons.work_outline, size: 56, color: Colors.blue),
//                     SizedBox(height: 12),
//                     Text('Job Report App', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue[800])),
//                     SizedBox(height: 8),
//                     Text('Track your daily tasks and work hours', style: TextStyle(color: Colors.grey[700])),
//                     SizedBox(height: 16),
//                     TextField(
//                       controller: _nameCtl,
//                       decoration: InputDecoration(prefixIcon: Icon(Icons.person), labelText: 'Full Name'),
//                     ),
//                     SizedBox(height: 8),
//                     TextField(
//                       controller: _emailCtl,
//                       decoration: InputDecoration(prefixIcon: Icon(Icons.email), labelText: 'Email'),
//                       keyboardType: TextInputType.emailAddress,
//                     ),
//                     SizedBox(height: 12),
//                     SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton(
//                         onPressed: _nameCtl.text.trim().isNotEmpty && _emailCtl.text.trim().isNotEmpty
//                           ? () {
//                               state.login(_nameCtl.text.trim(), _emailCtl.text.trim());
//                             }
//                           : null,
//                         child: Padding(
//                           padding: EdgeInsets.symmetric(vertical: 14),
//                           child: Text('Start Work Session'),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
