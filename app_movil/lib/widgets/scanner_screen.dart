import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        height: 400,
        child: MobileScanner(
          onDetect: (c) => Navigator.pop(context, c.barcodes.first.rawValue),
        ),
      ),
    );
  }
}
