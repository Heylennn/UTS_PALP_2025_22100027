import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddStorePage extends StatefulWidget {
  const AddStorePage({super.key});

  @override
  _AddStorePageState createState() => _AddStorePageState();
}

class _AddStorePageState extends State<AddStorePage> {
  final _formKey = GlobalKey<FormState>();
  List<QueryDocumentSnapshot> _stores = [];
  QueryDocumentSnapshot? _selectedStore;

  @override
  void initState() {
    super.initState();
    _fetchStores();
  }

  Future<void> _fetchStores() async {
    final snapshot = await FirebaseFirestore.instance.collection('stores').get();
    setState(() {
      _stores = snapshot.docs;
    });
  }

  void _saveStore() async {
    if (_formKey.currentState!.validate() && _selectedStore != null) {
      final prefs = await SharedPreferences.getInstance();
      final code = _selectedStore!['code'];
      final name = _selectedStore!['name'];
      final storeRef = _selectedStore!.reference;

      await prefs.setString('code', code);
      await prefs.setString('name', name);
      await prefs.setString('store_ref', storeRef.path);

      if (mounted) Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih toko terlebih dahulu.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pilih Toko")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _stores.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<QueryDocumentSnapshot>(
                      value: _selectedStore,
                      items: _stores.map((doc) {
                        final code = doc['code'];
                        final name = doc['name'];
                        return DropdownMenuItem(
                          value: doc,
                          child: Text("$code - $name"),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedStore = value;
                        });
                      },
                      decoration: const InputDecoration(labelText: "Pilih Toko"),
                      validator: (value) =>
                          value == null ? 'Toko harus dipilih' : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveStore,
                      child: const Text('Simpan Toko'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}