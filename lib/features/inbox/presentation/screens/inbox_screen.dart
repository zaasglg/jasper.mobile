import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Инбокс',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: const Center(child: Text('Инбокс')),
    );
  }
}
