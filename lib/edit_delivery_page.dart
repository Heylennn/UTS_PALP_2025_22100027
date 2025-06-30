import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditDeliveryModal extends StatefulWidget {
  final DocumentReference deliveryRef;
  final Map<String, dynamic> deliveryData;

  const EditDeliveryModal({
    super.key,
    required this.deliveryRef,
    required this.deliveryData,
  });

  @override
  State<EditDeliveryModal> createState() => _EditDeliveryModalState();
}

class _EditDeliveryModalState extends State<EditDeliveryModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _formNumberController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  DateTime? _selectedDate;

  DocumentReference? _selectedDestinationStore;
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
    _formNumberController.text = widget.deliveryData['no_form'] ?? '';
    _selectedDestinationStore = widget.deliveryData['destination_store_ref'];
    _selectedWarehouse = widget.deliveryData['warehouse_ref'];

    if (widget.deliveryData['updated_at'] != null) {
      _selectedDate = (widget.deliveryData['updated_at'] as Timestamp).toDate();
      _dateController.text = _formatDate(_selectedDate!);
    }

    _fetchDropdownData();
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _fetchDropdownData() async {
    final prefs = await SharedPreferences.getInstance();
    final storeRefPath = prefs.getString('store_ref');
    if (storeRefPath == null) return;
    final storeRef = FirebaseFirestore.instance.doc(storeRefPath);

    final stores = await FirebaseFirestore.instance.collection('stores').get();
    final warehouses = await FirebaseFirestore.instance.collection('warehouses').where('store_ref', isEqualTo: storeRef).get();
    final products = await FirebaseFirestore.instance.collection('products').where('store_ref', isEqualTo: storeRef).get();
    final detailsSnapshot = await widget.deliveryRef.collection('details').get();

    if (!mounted) return;
    setState(() {
      _stores = stores.docs;
      _warehouses = warehouses.docs;
      _products = products.docs;
      _productDetails.clear();
      for (var doc in detailsSnapshot.docs) {
        _productDetails.add(_DetailItem.fromMap(doc.data(), _products, doc.reference));
      }
    });
  }

  void _updateDelivery() async {
    if (!_formKey.currentState!.validate() ||
        _selectedDestinationStore == null ||
        _selectedWarehouse == null ||
        _productDetails.isEmpty) {return;}

    final detailsRef = widget.deliveryRef.collection('details');
    final firestore = FirebaseFirestore.instance;

    final oldDetailsSnapshot = await detailsRef.get();
    final oldQuantities = <String, int>{};

    for (var doc in oldDetailsSnapshot.docs) {
      final data = doc.data();
      final productRef = (data['product_ref'] as DocumentReference).id;
      final qty = (data['qty'] ?? 0);
      oldQuantities[productRef] = (oldQuantities[productRef] ?? 0) + (qty as num).toInt();  
    }

    for (var doc in oldDetailsSnapshot.docs) {
      await doc.reference.delete();
    }

    final newQuantities = <String, int>{};

    for (var item in _productDetails) {
      final refId = item.productRef!.id;
      newQuantities[refId] = (newQuantities[refId] ?? 0) + item.qty;

      await item.productRef!.update({'default_price': item.price});
      await detailsRef.add(item.toMap());
    }

    for (var productRefId in {...oldQuantities.keys, ...newQuantities.keys}) {
      final oldQty = oldQuantities[productRefId] ?? 0;
      final newQty = newQuantities[productRefId] ?? 0;
      final qtyDiff = newQty - oldQty;

      final stockQuery = await firestore
          .collection('stocks')
          .where('product_ref', isEqualTo: firestore.doc('products/$productRefId'))
          .where('warehouse_ref', isEqualTo: _selectedWarehouse)
          .limit(1)
          .get();

      final productDocRef = firestore.doc('products/$productRefId');

      if (stockQuery.docs.isNotEmpty) {
        final stockDoc = stockQuery.docs.first.reference;
        await firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(stockDoc);
          final currentQty = snapshot['qty'] ?? 0;
          transaction.update(stockDoc, {'qty': currentQty - qtyDiff}); // <== SUBTRACTION
        });
      } else {
        await firestore.collection('stocks').add({
          'product_ref': firestore.doc('products/$productRefId'),
          'warehouse_ref': _selectedWarehouse,
          'qty': -qtyDiff, // <== SUBTRACTION
        });
      }
      
      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(productDocRef);
        final currentQty = snapshot['qty'] ?? 0;
        transaction.update(productDocRef, {'qty': currentQty - qtyDiff}); // <== SUBTRACTION
      });
    }

    await widget.deliveryRef.update({
      'no_form': _formNumberController.text.trim(),
      'destination_store_ref': _selectedDestinationStore,
      'warehouse_ref': _selectedWarehouse,
      'item_total': itemTotal,
      'grandtotal': grandTotal,
      'updated_at': DateTime.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Delivery berhasil diedit.")),
    );

    if (mounted) {
      Navigator.pop(context, 'updated');
    }
  }

  void _removeProductRow(int index) {
    setState(() => _productDetails.removeAt(index));
  }

  void _addProductRow() {
    setState(() => _productDetails.add(_DetailItem(products: _products)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Delivery')),
      body: _products.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _formNumberController,
                      decoration: InputDecoration(labelText: 'No. Form'),
                      validator: (value) => value!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    DropdownButtonFormField<DocumentReference>(
                      value: _selectedDestinationStore,
                      items: _stores.map((doc) {
                        return DropdownMenuItem(
                          value: doc.reference,
                          child: Text(doc['name']),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedDestinationStore = value),
                      decoration: InputDecoration(labelText: 'Tujuan Toko'),
                      validator: (value) => value == null ? 'Pilih tujuan toko' : null,
                    ),
                    DropdownButtonFormField<DocumentReference>(
                      value: _selectedWarehouse,
                      items: _warehouses.map((doc) {
                        return DropdownMenuItem(
                          value: doc.reference,
                          child: Text(doc['name']),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedWarehouse = value),
                      decoration: InputDecoration(labelText: 'Warehouse'),
                      validator: (value) => value == null ? 'Pilih warehouse' : null,
                    ),
                    SizedBox(height: 24),
                    Text("Detail Produk", style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    ..._productDetails.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
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
                                  item.unitName = value!.id == '1' ? 'pcs' : 'dus';
                                }),
                                decoration: InputDecoration(labelText: "Produk"),
                                validator: (value) => value == null ? 'Pilih produk' : null,
                              ),
                              TextFormField(
                                initialValue: item.price.toString(),
                                decoration: InputDecoration(labelText: "Harga"),
                                keyboardType: TextInputType.number,
                                onChanged: (val) => setState(() {
                                  item.price = int.tryParse(val) ?? 0;
                                }),
                                validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
                              ),
                              TextFormField(
                                initialValue: item.qty.toString(),
                                decoration: InputDecoration(labelText: "Jumlah"),
                                keyboardType: TextInputType.number,
                                onChanged: (val) => setState(() {
                                  item.qty = int.tryParse(val) ?? 1;
                                }),
                                validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
                              ),
                              SizedBox(height: 8),
                              Text("Satuan: ${item.unitName}"),
                              Text("Subtotal: ${item.subtotal}"),
                              SizedBox(height: 4),
                              TextButton.icon(
                                onPressed: () => _removeProductRow(index),
                                icon: Icon(Icons.remove_circle, color: Colors.red),
                                label: Text("Hapus Produk"),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    ElevatedButton.icon(
                      onPressed: _addProductRow,
                      icon: Icon(Icons.add),
                      label: Text('Tambah Produk'),
                    ),
                    SizedBox(height: 16),
                    Text("Item Total: $itemTotal"),
                    Text("Grand Total: $grandTotal"),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _updateDelivery,
                      child: Text('Update Delivery'),
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
  int price;
  int qty;
  String unitName;
  final List<DocumentSnapshot> products;
  final DocumentReference? docRef;

  _DetailItem({
    this.productRef,
    this.price = 0,
    this.qty = 1,
    this.unitName = 'unit',
    required this.products,
    this.docRef,
  });

  factory _DetailItem.fromMap(Map<String, dynamic> data, List<DocumentSnapshot> products, DocumentReference ref) {
    return _DetailItem(
      productRef: data['product_ref'],
      price: data['price'],
      qty: data['qty'],
      unitName: data['unit_name'] ?? 'unit',
      products: products,
      docRef: ref,
    );
  }

  int get subtotal => price * qty;

  Map<String, dynamic> toMap() {
    return {
      'product_ref': productRef,
      'price': price,
      'qty': qty,
      'unit_name': unitName,
      'subtotal': subtotal,
    };
  }
}