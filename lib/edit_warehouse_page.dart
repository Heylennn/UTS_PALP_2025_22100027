import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditWarehousePage extends StatefulWidget {
  final String warehouseId;

  const EditWarehousePage({required this.warehouseId, super.key});

  @override
  State<EditWarehousePage> createState() => _EditWarehousePageState();
}

class _EditWarehousePageState extends State<EditWarehousePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadWarehouseData();
  }

  Future<void> _loadWarehouseData() async {
    final doc = await FirebaseFirestore.instance
        .collection('warehouses')
        .doc(widget.warehouseId)
        .get();
    if (doc.exists) {
      _nameController.text = doc.data()!['name'];
    }
  }

  Future<void> _updateWarehouse() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final data = {
      'name': _nameController.text,
    };

    await FirebaseFirestore.instance
        .collection('warehouses')
        .doc(widget.warehouseId)
        .update(data);

    if (mounted) Navigator.pop(context, 'updated');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Gudang')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Gudang'),
                validator: (value) =>
                    value!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : _updateWarehouse,
                child: const Text('Perbarui'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
