import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'store_service.dart';

class AddSalesPage extends StatefulWidget {
  const AddSalesPage({super.key});

  @override
  State<AddSalesPage> createState() => _AddSalesPageState();
}

class _AddSalesPageState extends State<AddSalesPage> {
  final _formKey = GlobalKey<FormState>();
  final _formNumberController = TextEditingController();
  final _formCustomerNameController = TextEditingController();
  final _formPostDateController = TextEditingController();

  DateTime? _selectedDate;

  List<DocumentSnapshot> _products = [];
  final List<_DetailItem> _details = [];

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
  }

  Future<void> _fetchDropdownData() async {
    try {
      final storeCode = await StoreService.getStoreCode();
      if (storeCode == null) return;

      final productSnap = await FirebaseFirestore.instance
          .collection('products')
          .where('kode_toko', isEqualTo: storeCode)
          .get();

      setState(() {
        _products = productSnap.docs;
      });
    } catch (e) {
      debugPrint('Error fetching dropdown data: $e');
    }
  }

  int get itemTotal => _details.fold(0, (sum, item) => sum + item.qty);
  int get grandTotal => _details.fold(0, (sum, item) => sum + item.subtotal);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _formPostDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveSales() async {
    if (!_formKey.currentState!.validate() || _details.isEmpty) return;

    final storeCode = await StoreService.getStoreCode();
    if (storeCode == null) return;

    final storeQuery = await FirebaseFirestore.instance
        .collection('stores')
        .where('code', isEqualTo: storeCode)
        .limit(1)
        .get();

    if (storeQuery.docs.isEmpty) return;
    final storeRef = storeQuery.docs.first.reference;

    final sales = {
      'no_form': _formNumberController.text.trim(),
      'customer_name': _formCustomerNameController.text.trim(),
      'item_total': itemTotal,
      'grand_total': grandTotal,
      'post_date': _formPostDateController.text.trim(),
      'created_at': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : FieldValue.serverTimestamp(),
      'store_ref': storeRef,
    };

    final salesDoc = await FirebaseFirestore.instance
        .collection('salesTransactions')
        .add(sales);

    for (final detail in _details) {
      await salesDoc.collection('details').add(detail.toMap());

      if (detail.productRef != null) {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final productSnapshot = await transaction.get(detail.productRef!);
          if (!productSnapshot.exists) return;

          final currentJumlah = productSnapshot.get('jumlah') ?? 0;
          final updatedJumlah = currentJumlah - detail.qty;

          transaction.update(detail.productRef!, {
            'jumlah': updatedJumlah,
            'stock': updatedJumlah,
          });
        });
      }
    }

    if (mounted) Navigator.pop(context);
  }

  void _addDetail() {
    setState(() => _details.add(_DetailItem(products: _products)));
  }

  void _removeDetail(int index) {
    setState(() => _details.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Penjualan')),
      body: _products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _formNumberController,
                      decoration: const InputDecoration(labelText: 'No. Form'),
                      validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _formCustomerNameController,
                      decoration: const InputDecoration(labelText: 'Nama Pelanggan'),
                      validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _formPostDateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Tanggal Faktur',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: _pickDate,
                        ),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Wajib pilih tanggal' : null,
                    ),
                    const SizedBox(height: 24),
                    const Text('Detail Produk', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._details.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<DocumentReference>(
                                value: item.productRef,
                                items: _products.map((doc) {
                                  return DropdownMenuItem(
                                    value: doc.reference,
                                    child: Text(doc['name']),
                                  );
                                }).toList(),
                                onChanged: (value) => setState(() {
                                  item.productRef = value;
                                  item.unitName = 'pcs';
                                }),
                                decoration: const InputDecoration(labelText: "Produk"),
                                validator: (value) => value == null ? 'Pilih produk' : null,
                              ),
                              TextFormField(
                                initialValue: item.price.toString(),
                                decoration: const InputDecoration(labelText: "Harga"),
                                keyboardType: TextInputType.number,
                                onChanged: (val) => setState(() {
                                  item.price = int.tryParse(val) ?? 0;
                                }),
                                validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
                              ),
                              TextFormField(
                                initialValue: item.qty.toString(),
                                decoration: const InputDecoration(labelText: "Jumlah"),
                                keyboardType: TextInputType.number,
                                onChanged: (val) => setState(() => item.qty = int.tryParse(val) ?? 1),
                                validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
                              ),
                              const SizedBox(height: 8),
                              Text("Subtotal: Rp ${item.subtotal}"),
                              Text("Satuan: ${item.unitName}"),
                              TextButton.icon(
                                onPressed: () => _removeDetail(i),
                                icon: const Icon(Icons.delete, color: Colors.red),
                                label: const Text("Hapus"),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    ElevatedButton.icon(
                      onPressed: _addDetail,
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Produk'),
                    ),
                    const SizedBox(height: 16),
                    Text("Total Item: $itemTotal"),
                    Text("Grand Total: Rp $grandTotal"),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveSales,
                      child: const Text("Simpan Penjualan"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _DetailItem {
  DocumentReference? productRef;
  int qty = 1;
  int price = 0;
  String unitName = 'unit';
  final List<DocumentSnapshot> products;

  _DetailItem({required this.products});

  int get subtotal => price * qty;

  Map<String, dynamic> toMap() {
    return {
      'product_ref': productRef,
      'qty': qty,
      'unit_name': unitName,
      'price': price,
      'subtotal': subtotal,
    };
  }
}
