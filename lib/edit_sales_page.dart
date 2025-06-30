// EDIT SALES PAGE - Mirroring AddSalesPage structure

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'store_service.dart';

class EditSalesPage extends StatefulWidget {
  final DocumentReference salesRef;

  const EditSalesPage({super.key, required this.salesRef});

  @override
  State<EditSalesPage> createState() => _EditSalesPageState();
}

class _EditSalesPageState extends State<EditSalesPage> {
  final _formKey = GlobalKey<FormState>();
  final _formNumberController = TextEditingController();
  final _formCustomerNameController = TextEditingController();
  final _formPostDateController = TextEditingController();

  DateTime? _selectedDate;

  List<DocumentSnapshot> _products = [];
  final List<_DetailItem> _details = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final salesSnap = await widget.salesRef.get();
      if (!salesSnap.exists) return;
      final salesData = salesSnap.data() as Map<String, dynamic>;

      final storeCode = await StoreService.getStoreCode();
      if (storeCode == null) return;

      final productSnap = await FirebaseFirestore.instance
          .collection('products')
          .where('kode_toko', isEqualTo: storeCode)
          .get();

      final detailsSnap = await widget.salesRef.collection('details').get();

      setState(() {
        _formNumberController.text = salesData['no_form'] ?? '';
        _formCustomerNameController.text = salesData['customer_name'] ?? '';
        final postDateStr = salesData['post_date'] ?? '';
        _formPostDateController.text = postDateStr;
        _selectedDate = postDateStr.isNotEmpty ? DateTime.tryParse(postDateStr) : null;
        _products = productSnap.docs;

        _details.clear();
        for (var doc in detailsSnap.docs) {
          final data = doc.data();
          _details.add(
            _DetailItem(
              products: _products,
              productRef: data['product_ref'],
              qty: data['qty'],
              price: data['price'],
              unitName: data['unit_name'],
              docId: doc.id,
            ),
          );
        }
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading sales data: $e');
      setState(() => _loading = false);
    }
  }

  int get itemTotal => _details.fold(0, (sum, item) => sum + item.qty);
  int get grandTotal => _details.fold(0, (sum, item) => sum + item.subtotal);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
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

  Future<void> _updateSales() async {
    if (!_formKey.currentState!.validate() || _details.isEmpty) return;

    final detailCollection = widget.salesRef.collection('details');
    final oldDetails = await detailCollection.get();
    for (var doc in oldDetails.docs) {
      final data = doc.data();
      final productRef = data['product_ref'] as DocumentReference;
      final qty = data['qty'] as int;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final productSnap = await transaction.get(productRef);
        if (!productSnap.exists) return;
        final currentStock = productSnap.get('stock') ?? 0;
        transaction.update(productRef, {'stock': currentStock + qty});
      });

      await doc.reference.delete();
    }

    final updatedData = {
      'no_form': _formNumberController.text.trim(),
      'customer_name': _formCustomerNameController.text.trim(),
      'post_date': _formPostDateController.text.trim(),
      'item_total': itemTotal,
      'grand_total': grandTotal,
      'updated_at': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : FieldValue.serverTimestamp(),
    };

    await widget.salesRef.update(updatedData);

    for (final detail in _details) {
      await detailCollection.add(detail.toMap());
      if (detail.productRef != null) {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final productSnap = await transaction.get(detail.productRef!);
          if (!productSnap.exists) return;
          final currentStock = productSnap.get('stock') ?? 0;
          transaction.update(detail.productRef!, {'stock': currentStock - detail.qty});
        });
      }
    }

    if (mounted) Navigator.pop(context);
  }

  void _addDetail() => setState(() => _details.add(_DetailItem(products: _products)));
  void _removeDetail(int index) => setState(() => _details.removeAt(index));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Penjualan')),
      body: _loading
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
                      onPressed: _updateSales,
                      child: const Text("Update Penjualan"),
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
  int qty;
  int price;
  String unitName;
  String? docId;
  final List<DocumentSnapshot> products;

  _DetailItem({
    required this.products,
    this.productRef,
    this.qty = 1,
    this.price = 0,
    this.unitName = 'unit',
    this.docId,
  });

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
