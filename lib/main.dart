import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'receipt_list_page.dart';
// import 'add_receipt_page.dart';
import 'add_store_page.dart';
// import 'edit_receipt_page.dart';
// import 'add_supplier_page.dart';
// import 'edit_supplier_page.dart';
import 'supplier_list_page.dart';
// import 'add_warehouse_page.dart';
// import 'edit_warehouse_page.dart';
import 'warehouse_list_page.dart';
// import 'add_product_page.dart';
// import 'edit_product_page.dart';
import 'product_list_page.dart';
import 'sales_page.dart';
// import 'add_sales_page.dart';
// import 'edit_sales_page.dart';
// import 'add_delivery_page.dart';
// import 'edit_delivery_page.dart'; 
import 'delivery_list_page.dart';
import 'add_mutasi_page.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
      title: "UTS Heylen",
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white, // <- Ganti warna latar bawah
          selectedItemColor: Colors.indigo, // warna ikon yang dipilih
          unselectedItemColor: Colors.grey, // warna ikon lainnya
          elevation: 8, // menambah bayangan supaya terangkat
        ),
  textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 15)),
),

      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    const ReceiptListPage(),
    SupplierListPage(),
    WarehouseListPage(),
    ProductListPage(),
    SalesPage(),
    DeliveryListPage(),
  ];

  @override
  void initState() {
    super.initState();
    _checkStoreRef();
  }

  Future<void> _checkStoreRef() async {
    final prefs = await SharedPreferences.getInstance();
    final storeRefPath = prefs.getString('store_ref');

    if (storeRefPath == null || storeRefPath.isEmpty) {
      Future.delayed(Duration.zero, () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AddStorePage()),
        );
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Receipts'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Supplier'),
          BottomNavigationBarItem(icon: Icon(Icons.house), label: 'Warehouse'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: 'Product'),
          BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'Sales'),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Delivery'),
        ],
      ),
    );
  }
}

