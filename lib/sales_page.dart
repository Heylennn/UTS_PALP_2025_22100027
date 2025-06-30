import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'edit_sales_page.dart';
import 'add_sales_page.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  List<DocumentSnapshot> _salesList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('salesTransactions')
        .orderBy('created_at', descending: true)
        .get();

    setState(() {
      _salesList = snapshot.docs;
      _loading = false;
    });
  }

  String formatCurrency(int value) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Penjualan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _salesList.length,
              itemBuilder: (context, index) {
                final data = _salesList[index].data() as Map<String, dynamic>;
                final postDate = data['post_date'];
                final formattedDate = postDate != null && postDate is String
                    ? postDate
                    : (postDate is Timestamp
                        ? DateFormat('yyyy-MM-dd').format(postDate.toDate())
                        : '-');
                final grandTotal = data['grand_total'] ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('No Transaksi: ${data['no_form'] ?? '-'}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.orange),
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditSalesPage(
                                          salesRef: _salesList[index].reference,
                                        ),
                                      ),
                                    );
                                    _loadSales();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    await _salesList[index].reference.delete();
                                    _loadSales();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Customer: ${data['customer_name'] ?? '-'}'),
                        Text('Tanggal: $formattedDate'),
                        Text('Total Item: ${data['item_total'] ?? 0}'),
                        Text('Grand Total: Rp ${formatCurrency(grandTotal)}'),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSalesPage()),
          );
          _loadSales();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
