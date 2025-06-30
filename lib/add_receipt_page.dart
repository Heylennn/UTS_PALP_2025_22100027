import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddReceiptPage extends StatefulWidget {
  const AddReceiptPage({super.key});

  @override
  State<AddReceiptPage> createState() => _AddReceiptPageState();
}

class _AddReceiptPageState extends State<AddReceiptPage> {
  final _formKey = GlobalKey<FormState>();

  DocumentReference? _selectedSupplier;
  DocumentReference? _selectedWarehouse;
  List<DocumentSnapshot> _suppliers = [];
  List<DocumentSnapshot> _warehouses = [];
  List<DocumentSnapshot> _products = [];

  final List<_DetailItem> _productDetails = [];

  int get itemTotal => _productDetails.fold(0, (sum, item) => sum + item.qty);
  int get grandTotal => _productDetails.fold(0, (sum, item) => sum + item.subtotal);

  @override
  void initState() {
    super.initState();
    _fetchDropdownData().then((_) {
      if (_products.isNotEmpty) {
        setState(() {
          _productDetails.add(_DetailItem(
            productRef: _products.first.reference,
            price: 0,
            qty: 1,
          ));
        });
      }
    });
  }

  Future<void> _fetchDropdownData() async {
    final suppliers = await FirebaseFirestore.instance.collection('suppliers').get();
    final warehouses = await FirebaseFirestore.instance.collection('warehouses').get();
    final products = await FirebaseFirestore.instance.collection('products').get();

    setState(() {
      _suppliers = suppliers.docs;
      _warehouses = warehouses.docs;
      _products = products.docs;
    });
  }

  Future<void> _saveReceipt() async {
    if (!_formKey.currentState!.validate() ||
        _selectedSupplier == null ||
        _selectedWarehouse == null ||
        _productDetails.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storeRefPath = prefs.getString('store_ref');
    if (storeRefPath == null) return;
    final storeRef = FirebaseFirestore.instance.doc(storeRefPath);

    final receipts = await FirebaseFirestore.instance
        .collection('purchaseGoodsReceipts')
        .orderBy('created_at', descending: true)
        .get();

    final nextNumber = receipts.size + 1;
    final noForm = 'PO-${nextNumber.toString().padLeft(4, '0')}';

    final receiptData = {
      'no_form': noForm,
      'grandtotal': grandTotal,
      'item_total': itemTotal,
      'store_ref': storeRef,
      'supplier_ref': _selectedSupplier,
      'warehouse_ref': _selectedWarehouse,
      'created_at': FieldValue.serverTimestamp(),
      'post_date': null,
      'synced': false,
    };

    final receiptRef = await FirebaseFirestore.instance.collection('purchaseGoodsReceipts').add(receiptData);

    for (final item in _productDetails) {
      await FirebaseFirestore.instance.collection('purchaseGoodsReceiptDetails').add({
        'product_ref': item.productRef,
        'qty': item.qty,
        'price': item.price,
        'subtotal': item.subtotal,
        'receipt_ref': receiptRef,
      });

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final productSnapshot = await transaction.get(item.productRef);
        final currentStock = productSnapshot.get('stock') ?? 0;
        final currentJumlah = productSnapshot.get('jumlah') ?? 0;
        final newStock = currentStock + item.qty;
        final newJumlah = currentJumlah + item.qty;

        transaction.update(item.productRef, {
          'stock': newStock,
          'jumlah': newJumlah,
        });
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Receipt berhasil disimpan')),
      );
      Navigator.pop(context, 'added');
    }
  }

  void _addProductRow() {
    setState(() => _productDetails.add(_DetailItem(
          productRef: _products.first.reference,
          price: 0,
          qty: 1,
        )));
  }

  void _removeProductRow(int index) {
    setState(() => _productDetails.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Receipt')),
      body: _products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  DropdownButtonFormField<DocumentReference>(
                    decoration: const InputDecoration(labelText: 'Supplier'),
                    items: _suppliers.map((doc) => DropdownMenuItem(
                          value: doc.reference,
                          child: Text(doc['name']),
                        )).toList(),
                    onChanged: (value) => setState(() => _selectedSupplier = value),
                    validator: (val) => val == null ? 'Wajib pilih supplier' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<DocumentReference>(
                    decoration: const InputDecoration(labelText: 'Gudang'),
                    items: _warehouses.map((doc) => DropdownMenuItem(
                          value: doc.reference,
                          child: Text(doc['name']),
                        )).toList(),
                    onChanged: (value) => setState(() => _selectedWarehouse = value),
                    validator: (val) => val == null ? 'Wajib pilih gudang' : null,
                  ),
                  const SizedBox(height: 24),
                  Text("Detail Produk", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._productDetails.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<DocumentReference>(
                              value: item.productRef,
                              items: _products.map((doc) {
                                return DropdownMenuItem(
                                  value: doc.reference,
                                  child: Text(doc['name']),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => item.productRef = value);
                                }
                              },
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
                              onChanged: (val) => setState(() {
                                item.qty = int.tryParse(val) ?? 1;
                              }),
                              validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
                            ),
                            const SizedBox(height: 8),
                            Text("Subtotal: ${item.subtotal}"),
                            TextButton.icon(
                              onPressed: () => _removeProductRow(index),
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              label: const Text("Hapus Produk"),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  ElevatedButton.icon(
                    onPressed: _addProductRow,
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Produk'),
                  ),
                  const SizedBox(height: 16),
                  Text("Item Total: $itemTotal"),
                  Text("Grand Total: $grandTotal"),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saveReceipt,
                    child: const Text('Simpan Receipt'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _DetailItem {
  DocumentReference productRef;
  int qty;
  int price;
  int get subtotal => qty * price;

  _DetailItem({
    required this.productRef,
    required this.qty,
    required this.price,
  });
}
