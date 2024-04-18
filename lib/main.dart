import 'package:flutter/material.dart';
import 'camera_screen.dart'; // Make sure this file exists with the CameraScreen widget.

void main() {
  runApp(CafeAppBluetooth());
}

class CafeAppBluetooth extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cafe App Bluetooth',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: CameraScreen(),
    );
  }
}
