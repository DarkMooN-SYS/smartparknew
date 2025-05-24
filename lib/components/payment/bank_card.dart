import 'package:flutter/material.dart';
import 'package:smart_parking_system/components/card/edit_card.dart';

class BankCard extends StatelessWidget {
  final String id;
  final String number;
  final String name;
  final String expiry;
  final String bank;
  final String image;
  final String cvv;
  final bool isOdd;

  const BankCard({
    super.key,
    required this.id,
    required this.number,
    required this.name,
    required this.expiry,
    required this.bank,
    required this.image,
    required this.cvv,
    required this.isOdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white24,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isOdd ? const Color(0xFF3D3C5A) : Colors.transparent,
      ),
      child: Card(
        elevation: 0,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 70,
                    child: Image.asset(image),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => EditCardPage(
                            cardId: id,
                            cardNumber: number,
                            cvv: cvv,
                            name: name,
                            expiry: expiry,
                            bank: bank,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Edit Card',
                      style: TextStyle(
                        color: Color(0xFF58C6A9),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                number,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CARD HOLDER',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EXPIRES',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        expiry,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
