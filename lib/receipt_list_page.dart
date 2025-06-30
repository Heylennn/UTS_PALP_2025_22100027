import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_receipt_page.dart';
import 'edit_receipt_page.dart';

class ReceiptListPage extends StatefulWidget {
  const ReceiptListPage({super.key});

  @override
  State<ReceiptListPage> createState() => _ReceiptListPageState();
}

class _ReceiptListPageState extends State<ReceiptListPage> {
  DocumentReference? _storeRef;
  List<DocumentSnapshot> _allReceipts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReceiptsForStore();
  }

  Future<void> _loadReceiptsForStore() async {
    final prefs = await SharedPreferences.getInstance();
    final storeRefPath = prefs.getString('store_ref');
    if (storeRefPath == null || storeRefPath.isEmpty) return;

    final storeRef = FirebaseFirestore.instance.doc(storeRefPath);
    final receiptsSnapshot = await FirebaseFirestore.instance
        .collection('purchaseGoodsReceipts')
        .where('store_ref', isEqualTo: storeRef)
        .get();

    setState(() {
      _storeRef = storeRef;
      _allReceipts = receiptsSnapshot.docs;
      _loading = false;
    });
  }

  Future<void> _confirmDeleteReceipt(DocumentReference receiptRef) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Yakin ingin menghapus receipt ini? Semua detail akan ikut terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      final detailsRef = receiptRef.collection('details');
      final detailDocs = await detailsRef.get();
      for (var doc in detailDocs.docs) {
        await doc.reference.delete();
      }

      await receiptRef.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt berhasil dihapus')),
        );
        await _loadReceiptsForStore();
      }
    }
  }

  Future<void> _editReceipt(DocumentSnapshot document, Map<String, dynamic> data) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditReceiptModal(receiptRef: document.reference, receiptData: data),
    );
    if (result == 'deleted' || result == 'updated') {
      await _loadReceiptsForStore();
    }
  }

  String formatRupiah(num number) {
    return "Rp. ${number.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => "${m[1]}.")}";
  }

  String formatTanggal(DateTime? date) {
    if (date == null) return '-';
    return "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipts')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _allReceipts.isEmpty
              ? const Center(child: Text('Tidak ada receipt.'))
              : ListView.builder(
                  itemCount: _allReceipts.length,
                  itemBuilder: (context, index) {
                    final document = _allReceipts[index];
                    final data = document.data() as Map<String, dynamic>;

                    final noForm = data['no_form'] ?? '-';
                    final grandTotal = data['grandtotal'] ?? 0;
                    final itemTotal = data['item_total'] ?? 0;
                    final createdAt = (data['created_at'] as Timestamp?)?.toDate();
                    final updatedAt = (data['updated_at'] as Timestamp?)?.toDate();

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("No. Form: $noForm", style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("Total Harga: ${formatRupiah(grandTotal)}"),
                            Text("Item: $itemTotal"),
                            Text("Tanggal Dibuat: ${formatTanggal(createdAt)}"),
                            Text("Terakhir Diperbarui: ${formatTanggal(updatedAt)}"),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.orange),
                                  onPressed: () => _editReceipt(document, data),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _confirmDeleteReceipt(document.reference),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddReceiptPage()),
          );
          if (result == 'added') {
            await _loadReceiptsForStore();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
