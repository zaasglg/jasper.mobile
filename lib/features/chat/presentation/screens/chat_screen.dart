import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Мессенджер',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: const Center(child: Text('Мессенджер')),
    );
  }
}
