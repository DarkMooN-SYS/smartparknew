import 'package:flutter/material.dart';

class HelpSection extends StatelessWidget {
  const HelpSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F37),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Тусламжийн төв',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w700,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 39),
          _buildHelpItem(
            'Холбоо барих',
            'Та HardTech.ParkSmart@gmail.com хаягаар бидэнтэй холбогдох эсвэл (976) 99237962 утсаар холбогдож болно.',
          ),
          const SizedBox(height: 21),
          _buildHelpItem(
            'Тооцооны дэлгэрэнгүй',
            'Бүртгэлийн тохиргоон дотроос тооцооны мэдээллээ шинэчилнэ үү. Тусламж авахыг хүсвэл HardTech.ParkSmart@gmail.com хаягаар манай тооцооны хэлтэстэй холбогдоно уу.',
          ),
          const SizedBox(height: 21),
          _buildHelpItem(
            'Тусламж',
            'Тусламж авахын тулд манай тусламжийн төвд зочлох эсвэл HardTech.ParkSmart@gmail.com хаягаар бидэнд имэйл илгээнэ үү. Бид таны асуултанд 24 цагийн дотор хариулах болно.',
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF242A4A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF58C6A9).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF58C6A9).withOpacity(0.8),
          ),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          iconColor: const Color(0xFF58C6A9),
          collapsedIconColor: Colors.white70,
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                content,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.5,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
