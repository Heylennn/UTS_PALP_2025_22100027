import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddMutasiPage extends StatefulWidget {
  const AddMutasiPage({super.key});

  @override
  State<AddMutasiPage> createState() => _AddMutasiPageState();
}

class _AddMutasiPageState extends State<AddMutasiPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController quantityController = TextEditingController();

  List<DocumentSnapshot> _warehouses = [];
  List<DocumentSnapshot> _products = [];

  DocumentReference? fromWarehouse;
  DocumentReference? toWarehouse;
  DocumentReference? selectedItem;

  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    await _fetchDropdownData();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchDropdownData() async {
    final firestore = FirebaseFirestore.instance;

    final prefs = await SharedPreferences.getInstance();
    final storeId = prefs.getString('selected_store');
    final List<DocumentSnapshot> warehouses = [];
    final List<DocumentSnapshot> products = [];

    // Fetch warehouses under the same store
    final warehouseQuery = await firestore
        .collection('warehouses')
        .where('store_ref', isEqualTo: firestore.doc('stores/$storeId'))
        .get();
    warehouses.addAll(warehouseQuery.docs);

    // Fetch products (all) – adjust the filter as you need
    final productQuery = await firestore.collection('products').get();
    products.addAll(productQuery.docs);

    if (mounted) {
      setState(() {
        _warehouses = warehouses;
        _products = products;
      });
    }
  }

  Future<void> submitMutation() async {
    if (!_formKey.currentState!.validate() ||
        selectedItem == null ||
        fromWarehouse == null ||
        toWarehouse == null) {
      _showSnackBar('Mohon lengkapi semua isian');
      return;
    }

    if (fromWarehouse == toWarehouse) {
      _showSnackBar('Gudang asal dan tujuan tidak boleh sama');
      return;
    }

    final qty = int.tryParse(quantityController.text);
    if (qty == null || qty <= 0) {
      _showSnackBar('Jumlah tidak valid');
      return;
    }

    setState(() => _submitting = true);

    try {
      final firestore = FirebaseFirestore.instance;

      final fromStockQuery = await firestore
          .collection('stocks')
          .where('product_ref', isEqualTo: selectedItem)
          .where('warehouse_ref', isEqualTo: fromWarehouse)
          .limit(1)
          .get();

      final toStockQuery = await firestore
          .collection('stocks')
          .where('product_ref', isEqualTo: selectedItem)
          .where('warehouse_ref', isEqualTo: toWarehouse)
          .limit(1)
          .get();

      await firestore.runTransaction((transaction) async {
        // FROM WAREHOUSE
        if (fromStockQuery.docs.isEmpty) {
          throw Exception('Stok di gudang asal tidak ditemukan');
        }
        final fromDoc = fromStockQuery.docs.first;
        final fromQty = (fromDoc['qty'] as int) - qty;
        if (fromQty < 0) {
          throw Exception('Stok di gudang asal tidak mencukupi');
        }
        transaction.update(fromDoc.reference, {'qty': fromQty});

        // TO WAREHOUSE
        if (toStockQuery.docs.isNotEmpty) {
          final toDoc = toStockQuery.docs.first;
          final toQty = (toDoc['qty'] as int) + qty;
          transaction.update(toDoc.reference, {'qty': toQty});
        } else {
          final newStockRef = firestore.collection('stocks').doc();
          transaction.set(newStockRef, {
            'product_ref': selectedItem,
            'warehouse_ref': toWarehouse,
            'qty': qty,
          });
        }

        // Log mutation (optional – adjust fields as necessary)
        final mutationRef = firestore.collection('warehouse_mutations').doc();
        transaction.set(mutationRef, {
          'product_ref': selectedItem,
          'qty': qty,
          'from_warehouse': fromWarehouse,
          'to_warehouse': toWarehouse,
          'created_at': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        Navigator.pop(context, 'mutated');
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDCEFFF), // pastelBlue fallback
      appBar: AppBar(title: const Text('Mutasi Barang')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // PRODUCT DROPDOWN
                    DropdownButtonFormField<DocumentReference>(
                      decoration: const InputDecoration(
                        labelText: 'Produk',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedItem,
                      items: _products
                          .map((doc) => DropdownMenuItem(
                                value: doc.reference,
                                child: Text(doc['name'] ?? '–'),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => selectedItem = val),
                      validator: (val) => val == null ? 'Pilih produk' : null,
                    ),
                    const SizedBox(height: 16),

                    // FROM WAREHOUSE DROPDOWN
                    DropdownButtonFormField<DocumentReference>(
                      decoration: const InputDecoration(
                        labelText: 'Gudang Asal',
                        border: OutlineInputBorder(),
                      ),
                      value: fromWarehouse,
                      items: _warehouses
                          .map((doc) => DropdownMenuItem(
                                value: doc.reference,
                                child: Text(doc['name'] ?? '–'),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => fromWarehouse = val),
                      validator: (val) => val == null ? 'Pilih gudang asal' : null,
                    ),
                    const SizedBox(height: 16),

                    // TO WAREHOUSE DROPDOWN
                    DropdownButtonFormField<DocumentReference>(
                      decoration: const InputDecoration(
                        labelText: 'Gudang Tujuan',
                        border: OutlineInputBorder(),
                      ),
                      value: toWarehouse,
                      items: _warehouses
                          .map((doc) => DropdownMenuItem(
                                value: doc.reference,
                                child: Text(doc['name'] ?? '–'),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => toWarehouse = val),
                      validator: (val) => val == null ? 'Pilih gudang tujuan' : null,
                    ),
                    const SizedBox(height: 16),

                    // QUANTITY
                    TextFormField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Jumlah',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Masukkan jumlah';
                        }
                        final n = int.tryParse(value);
                        if (n == null || n <= 0) {
                          return 'Jumlah tidak valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // SUBMIT BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : submitMutation,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _submitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Kirim Mutasi'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
