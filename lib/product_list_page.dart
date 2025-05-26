import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_product_page.dart';
import 'edit_product_page.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  List<DocumentSnapshot> _products = [];
  bool _loading = true;
  String? _kodeToko;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final kodeToko = prefs.getString('code');

    if (kodeToko == null) return;

    final querySnapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('kode_toko', isEqualTo: kodeToko)
        .get();

    setState(() {
      _kodeToko = kodeToko;
      _products = querySnapshot.docs;
      _loading = false;
    });
  }

  Future<void> _deleteProduct(DocumentReference ref) async {
    await ref.delete();
    await _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Produk')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text('Belum ada produk.'))
              : ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final data = _products[index].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['name'] ?? '-'),
                      subtitle: Text('Jumlah: ${data['jumlah']}'),
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProductPage(
                              productRef: _products[index].reference,
                              productData: data,
                            ),
                          ),
                        );
                        if (result == 'updated') {
                          await _loadProducts();
                        }
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Hapus Produk"),
                              content: const Text("Yakin ingin menghapus produk ini?"),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text("Batal")),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text("Hapus")),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _deleteProduct(_products[index].reference);
                          }
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddProductPage()),
          );
          if (result == 'added') {
            await _loadProducts();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
