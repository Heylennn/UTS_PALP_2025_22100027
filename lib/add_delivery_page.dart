import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddDeliveryPage extends StatefulWidget {
  const AddDeliveryPage({super.key});

  @override
  State<AddDeliveryPage> createState() => _AddDeliveryPageState();
}

class _AddDeliveryPageState extends State<AddDeliveryPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _formNumberController = TextEditingController();
  DateTime? _selectedPostDate;
  final TextEditingController _postDateController = TextEditingController();

  DocumentReference? _selectedStore;
  DocumentReference? _selectedWarehouse;
  List<DocumentSnapshot> _stores = [];
  List<DocumentSnapshot> _warehouses = [];
  List<DocumentSnapshot> _products = [];

  final List<_DetailItem> _productDetails = [];

  int get itemTotal => _productDetails.fold(0, (sum, item) => sum + item.qty);
  int get grandTotal => _productDetails.fold(0, (sum, item) => sum + item.subtotal);

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
    _generateFormNumber();
  }

  Future<void> _fetchDropdownData() async {
    final prefs = await SharedPreferences.getInstance();
    final storeRefPath = prefs.getString('store_ref');
    if (storeRefPath == null) return;
    final storeRef = FirebaseFirestore.instance.doc(storeRefPath);

    final storesQuery = await FirebaseFirestore.instance.collection('stores').get();
    final stores = storesQuery.docs.where((doc) => doc.reference.path != storeRef.path).toList();

    final warehouses = await FirebaseFirestore.instance.collection('warehouses').where('store_ref', isEqualTo: storeRef).get();
    final products = await FirebaseFirestore.instance.collection('products').where('store_ref', isEqualTo: storeRef).get();

    final generatedFormNo = await _generateFormNumber();

    setState(() {
      _stores = stores;
      _warehouses = warehouses.docs;
      _products = products.docs;
      _formNumberController.text = generatedFormNo;
    });
  }

  Future<String> _generateFormNumber() async {
    final receipts = await FirebaseFirestore.instance
        .collection('deliveries')
        .orderBy('created_at', descending: true)
        .get();

    int maxNumber = 0;
    final base = 'TTJ22100034';

    for (var doc in receipts.docs) {
      final lastForm = doc['no_form'];
      final parts = lastForm.split('_');
      if (parts.length == 2) {
        final number = int.tryParse(parts[1]) ?? 0;
        if (number > maxNumber) {
          maxNumber = number;
        }
      }
    }

    final nextNumber = maxNumber + 1;
    return '${base}_$nextNumber';
  }

  Future<void> _saveDelivery() async {
    if (!_formKey.currentState!.validate() ||
        _selectedStore == null ||
        _selectedWarehouse == null ||
        _productDetails.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storeRefPath = prefs.getString('store_ref');
    final createdAt = DateTime.now();

    final deliveryRef = await FirebaseFirestore.instance.collection('deliveries').add({
      'no_form': _formNumberController.text,
      'postDate': _postDateController.text,
      'created_at': createdAt,
      'store_ref': _selectedStore,
      'warehouse_ref': _selectedWarehouse,
      'item_total': itemTotal,
      'grand_total': grandTotal,
    });

    for (var detail in _productDetails) {
      await deliveryRef.collection('details').add({
        'product_ref': detail.productRef,
        'qty': detail.qty,
        'price': detail.price,
        'subtotal': detail.subtotal,
      });
    }

    Navigator.pop(context);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedPostDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _selectedPostDate = picked;
        _postDateController.text = "${picked.toLocal()}".split(' ')[0];
      });
    }
  }

  void _addProductDetail(DocumentReference productRef, int qty, int price) {
    final subtotal = qty * price;
    setState(() {
      _productDetails.add(_DetailItem(
        productRef: productRef,
        qty: qty,
        price: price,
        subtotal: subtotal,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Pengiriman')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _formNumberController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'No Form'),
              ),
              TextFormField(
                controller: _postDateController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Tanggal'),
                onTap: () => _selectDate(context),
              ),
              DropdownButtonFormField<DocumentReference>(
                value: _selectedStore,
                items: _stores.map((store) {
                  return DropdownMenuItem(
                    value: store.reference,
                    child: Text(store['name']),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedStore = val),
                decoration: const InputDecoration(labelText: 'Toko Tujuan'),
              ),
              DropdownButtonFormField<DocumentReference>(
                value: _selectedWarehouse,
                items: _warehouses.map((wh) {
                  return DropdownMenuItem(
                    value: wh.reference,
                    child: Text(wh['name']),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedWarehouse = val),
                decoration: const InputDecoration(labelText: 'Gudang Asal'),
              ),
              const SizedBox(height: 20),
              const Text('Detail Produk'),
              ..._productDetails.map((detail) => ListTile(
                    title: Text(detail.productRef.id),
                    subtitle: Text('Qty: ${detail.qty} | Harga: ${detail.price}'),
                    trailing: Text('Subtotal: ${detail.subtotal}'),
                  )),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  if (_products.isNotEmpty) {
                    final product = _products.first;
                    _addProductDetail(product.reference, 1, 10000); // contoh hardcoded
                  }
                },
                child: const Text('Tambah Produk (contoh)'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveDelivery,
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailItem {
  final DocumentReference productRef;
  final int qty;
  final int price;
  final int subtotal;

  _DetailItem({
    required this.productRef,
    required this.qty,
    required this.price,
    required this.subtotal,
  });
}
