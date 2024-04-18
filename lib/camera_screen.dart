import 'package:esc_pos_utils/esc_pos_utils.dart' as pos;
import 'package:esc_pos_printer/esc_pos_printer.dart' as esc_printer;
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart' hide PosPrintResult; // Hide the PosPrintResult from esc_pos_bluetooth
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'dart:typed_data';
import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart' hide PosPrintResult;
import 'package:esc_pos_utils/esc_pos_utils.dart';




// Then, you would use esc_pos_utils.PosPrintResult when referring to the PosPrintResult from esc_pos_utils.





class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}
class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIdx = 0;
  String _countDownText = '';
  bool _isRearCameraSelected = true;
  PrinterBluetoothManager printerManager = PrinterBluetoothManager();
  BluetoothDevice? yourPrinterDevice; // Correctly declare the variable

  late PrinterBluetooth selectedPrinter; // Define the selectedPrinter variable

  @override
  void initState() {
    super.initState();
    _initCameras();
    _initPrinter();
  }
  Future<void> _initPrinter() async {
    printerManager.startScan(Duration(seconds: 4));
    // Optionally handle the result of the scan to list and select a printer
  }




  Future<void> _getPrinterDevice() async {
    List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
    // Handle the null case correctly
    BluetoothDevice? device = devices.firstWhere(
          (d) => d.name == "Your_Printer_Name",
      orElse: () => BluetoothDevice(name: 'none', address: '00:00:00:00:00:00'), // Provide a default device
    );
    setState(() {
      yourPrinterDevice = device;
    });
  }

  Future<void> _initCameras() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _controller = CameraController(
        _cameras![_selectedCameraIdx],
        ResolutionPreset.high,
      );
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {});
    }
  }

  void _onCapturePressed() async {
    if (_controller != null && !_controller!.value.isTakingPicture) {
      _startCountDown();
    }
  }

  Future<void> _startCountDown() async {
    for (int i = 3; i > 0; i--) {
      await Future.delayed(Duration(seconds: 1));
      setState(() {
        _countDownText = '$i';
      });
    }
    setState(() {
      _countDownText = 'Smile!';
    });
    await Future.delayed(Duration(seconds: 1));

    try {
      await _controller!.setFlashMode(FlashMode.off);
      final XFile capturedImage = await _controller!.takePicture();
      setState(() {
        _countDownText = '';
      });

      final Directory tempDir = await getTemporaryDirectory();
      final File tempImageFile = File('${tempDir.path}/${DateTime.now().toIso8601String()}.jpg');

      await capturedImage.saveTo(tempImageFile.path);

      if (yourPrinterDevice != null) {
        await printReceipt(tempImageFile);
      } else {
        print("Printer device not selected.");
      }

      await tempImageFile.delete();
    } catch (e) {
      print(e);
    }
  }

  Future<void> printReceipt(File imageFile) async {
    if (selectedPrinter == null) {  // Replace 'selectedPrinter' with relevant variable
      print("No printer selected.");
      return;
    }

    // Assuming 'printerManager' is a correctly initialized instance of PrinterBluetoothManager
    printerManager.selectPrinter(selectedPrinter);

    // Load the printing profile
    final profile = await CapabilityProfile.load();
    final ticket = pos.Ticket(pos.PaperSize.mm80, profile); // From 'esc_pos_utils' //There is the error here.

    // Add content to the ticket
    final Uint8List bytes = await imageFile.readAsBytes();
    ticket.imageRaster(bytes);

    ticket.text(
      'Thanks for the visit, visit us again!',
      styles: pos.PosStyles(align: PosAlign.center),
      linesAfter: 1,
    );

    ticket.cut();

    // Print the ticket
    final PosPrintResult result = await printerManager.printTicket(ticket.bytes);

    print('Print result: ${result.msg}');
  }



  void _onSwitchCamera() {
    if (_cameras == null || _cameras!.isEmpty) {
      return;
    }
    _selectedCameraIdx = (_selectedCameraIdx + 1) % _cameras!.length;
    _isRearCameraSelected = !_isRearCameraSelected;
    _initCameraController(_cameras![_selectedCameraIdx]);
  }

  void _initCameraController(CameraDescription cameraDescription) async {
    if (_controller != null) {
      await _controller!.dispose();
    }
    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller!.addListener(() {
      if (mounted) setState(() {});
      if (_controller!.value.hasError) {
        print('Camera error ${_controller!.value.errorDescription}');
      }
    });

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take a Photo'),
        actions: <Widget>[
          IconButton(
            icon: Icon(_isRearCameraSelected ? Icons.camera_front : Icons.camera_rear),
            onPressed: _onSwitchCamera,
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(child: CameraPreview(_controller!)),
          if (_countDownText.isNotEmpty)
            Positioned.fill(
              child: Center(
                child: Text(
                  _countDownText,
                  style: TextStyle(
                    fontSize: 48,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 24.0,
            child: FloatingActionButton(
              onPressed: _onCapturePressed,
              child: Icon(Icons.camera_rounded),
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
