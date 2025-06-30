import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'add_delivery_page.dart';
import 'edit_delivery_page.dart';

class DeliveryListPage extends StatefulWidget {
  const DeliveryListPage({super.key});

  @override
  State<DeliveryListPage> createState() => _DeliveryListPageState();
}

class _DeliveryListPageState extends State<DeliveryListPage> {
  final _deliveryStream = FirebaseFirestore.instance.collection('deliveries').snapshots();

  Future<void> _confirmDeleteDelivery(DocumentReference deliveryRef) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Yakin ingin menghapus pengiriman ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (shouldDelete ?? false) {
      await deliveryRef.delete();
    }
  }

  void _openEditDeliveryModal(DocumentReference deliveryRef, Map<String, dynamic> deliveryData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 400,
          child: EditDeliveryModal(
            deliveryRef: deliveryRef,
            deliveryData: deliveryData,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Pengiriman'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddDeliveryPage()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _deliveryStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Terjadi kesalahan'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final deliveries = snapshot.data!.docs;

          if (deliveries.isEmpty) {
            return const Center(child: Text('Belum ada data pengiriman'));
          }

          return ListView.builder(
            itemCount: deliveries.length,
            itemBuilder: (context, index) {
              final delivery = deliveries[index];
              final data = delivery.data() as Map<String, dynamic>;

              return ListTile(
                title: Text(data['formNumber'] ?? 'No Form'),
                subtitle: Text('Tanggal: ${data['postDate'] ?? '-'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _openEditDeliveryModal(delivery.reference, data),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _confirmDeleteDelivery(delivery.reference),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
