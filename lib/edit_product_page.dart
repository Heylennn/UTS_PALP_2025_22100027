import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProductPage extends StatefulWidget {
  final DocumentReference productRef;
  final Map<String, dynamic> productData;

  const EditProductPage({
    super.key,
    required this.productRef,
    required this.productData,
  });

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _jumlahController;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.productData['name'] ?? '');
    _jumlahController =
        TextEditingController(text: widget.productData['jumlah']?.toString() ?? '0');
  }

  Future<void> _updateProduct() async {
    if (_formKey.currentState!.validate()) {
      await widget.productRef.update({
        'name': _nameController.text.trim(),
        'jumlah': int.tryParse(_jumlahController.text) ?? 0,
      });

      if (mounted) Navigator.pop(context, 'updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Produk')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Produk'),
                validator: (value) =>
                    value!.isEmpty ? 'Nama produk tidak boleh kosong' : null,
              ),
              TextFormField(
                controller: _jumlahController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Jumlah'),
                validator: (value) =>
                    value!.isEmpty ? 'Jumlah tidak boleh kosong' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateProduct,
                child: const Text('Update'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
