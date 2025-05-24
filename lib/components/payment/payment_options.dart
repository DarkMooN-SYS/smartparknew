import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_parking_system/components/common/common_functions.dart';
import 'package:smart_parking_system/components/common/custom_widgets.dart';
import 'package:smart_parking_system/components/common/toast.dart';
import 'package:smart_parking_system/components/payment/add_card.dart';
import 'package:smart_parking_system/components/payment/bank_card.dart';

class PaymentMethodPage extends StatefulWidget {
  const PaymentMethodPage({super.key});

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  int creditAmount = 0;
  List<Map<String, String>> cards = [];
  bool _isFetching = true;

  @override
  void initState() {
    super.initState();
    _fetchCards();
    _fetchCreditAmount();
  }

  Future<void> _fetchCards() async {
    setState(() {
      _isFetching = true;
    });
    User? user = FirebaseAuth.instance.currentUser;

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('cards')
          .where('userId', isEqualTo: user?.uid)
          .get();

      final List<Map<String, String>> fetchedCards = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        String cardNumber = data['cardNumber'] ?? '';

        fetchedCards.add({
          'id': doc.id,
          'bank': data['bank'] ?? '',
          'number':
              '**** **** **** ${cardNumber.isNotEmpty ? cardNumber.substring(cardNumber.length - 4) : '0000'}',
          'cardNumber': data['cardNumber'] ?? '',
          'cvv': data['cvv'] ?? '',
          'name': data['holderName'] ?? '',
          'expiry': data['expiry'] ?? '',
          'image': 'assets/${data['cardType']}.png',
        });
      }

      setState(() {
        cards = fetchedCards;
      });
    } catch (e) {
      //print('Error fetching cards: $e');
    }
    setState(() {
      _isFetching = false;
    });
  }

  Future<void> _fetchCreditAmount() async {
    setState(() {
      _isFetching = true;
    });
    User? user = FirebaseAuth.instance.currentUser;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .get();

      final data = userDoc.data() as Map<String, dynamic>;
      setState(() {
        creditAmount = data['balance']?.toInt() ?? 0;
      });
    } catch (e) {
      // hhe
    }
    setState(() {
      _isFetching = false;
    });
  }

  Future<void> _showTopUpDialog() async {
    double? topUpAmount;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF35344A),
          title: const Text('Top Up', style: TextStyle(color: Colors.white)),
          content: TextField(
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter amount',
              hintStyle: TextStyle(color: Colors.grey),
            ),
            onChanged: (value) {
              topUpAmount = double.tryParse(value);
            },
          ),
          actions: [
            TextButton(
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.tealAccent)),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
            TextButton(
              child: const Text('Top Up',
                  style: TextStyle(color: Colors.tealAccent)),
              onPressed: () async {
                if (isValidString(topUpAmount.toString(), r'^\d+(\.\d+)?$')) {
                  User? user = FirebaseAuth.instance.currentUser;
                  setState(() {
                    creditAmount += (topUpAmount ?? 0).toInt();
                  });

                  // Update credit amount in Firestore
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user?.uid)
                        .update({'balance': creditAmount});
                  } catch (e) {
                    // hhe
                  }

                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                } else {
                  showToast(message: "Invalid Amount : $topUpAmount");
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF35344A),
      body: _isFetching
          ? loadingWidget()
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'Balance',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF58C6A9),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF35344A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white24,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet,
                                  color: Colors.white),
                              const SizedBox(width: 20),
                              Text(
                                'MNT ${creditAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF58C6A9),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: ElevatedButton(
                              onPressed: _showTopUpDialog,
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.black,
                                backgroundColor: Colors.tealAccent,
                              ),
                              child: const Text('Top Up'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'Credits & Debit Cards',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF58C6A9),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        for (var card in cards)
                          Column(
                            spacing: 20.0,
                            children: [
                              BankCard(
                                id: card['id']!,
                                number: card['number']!,
                                name: card['name']!,
                                expiry: card['expiry']!,
                                bank: card['bank']!,
                                image: card['image']!,
                                cvv: card['cvv']!,
                                isOdd: cards.indexOf(card) % 2 == 1,
                              ),
                            ],
                          ),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF35344A),
                            border: Border.all(
                              color: Colors.white24,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          height: 100,
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add,
                                color: Color(0xFF58C6A9),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => Scaffold(
                                        appBar: const CustomAppBar(
                                          title: 'Add New Card',
                                        ),
                                        body: const AddCardPage(),
                                      ),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Add New Card',
                                  style: TextStyle(
                                      color: Color(0xFF58C6A9), fontSize: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
