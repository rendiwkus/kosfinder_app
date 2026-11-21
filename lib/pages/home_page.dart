import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/kos_service.dart';
import '../services/profile_service.dart';
import '../widgets/role_guard.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<UserProfile?> _profileFuture;
  late final Future<List<Map<String, dynamic>>> _kosFuture;
  final _kosService = KosService();

  @override
  void initState() {
    super.initState();
    _profileFuture = ProfileService().getMyProfile();
    _kosFuture = _kosService.fetchAll();
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _refreshKos() async {
    setState(() {
      _kosFuture = _kosService.fetchAll();
    });
  }

  void _showKosDialog({Map<String, dynamic>? kos}) {
    final isEditing = kos != null;
    final nameC = TextEditingController(text: kos?['name'] ?? '');
    final addressC = TextEditingController(text: kos?['address'] ?? '');
    final priceC = TextEditingController(text: kos?['price']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEditing ? 'Edit Kos' : 'Tambah Kos'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameC,
                decoration: const InputDecoration(labelText: 'Nama Kos'),
              ),
              TextField(
                controller: addressC,
                decoration: const InputDecoration(labelText: 'Alamat'),
              ),
              TextField(
                controller: priceC,
                decoration: const InputDecoration(labelText: 'Harga'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameC.text.trim();
              final address = addressC.text.trim();
              final price = int.tryParse(priceC.text.trim()) ?? 0;
              if (name.isEmpty || address.isEmpty || price <= 0) return;

              Navigator.pop(context);
              try {
                if (isEditing) {
                  final ok = await _kosService.update(kos['id'], {
                    'name': name,
                    'address': address,
                    'price': price,
                  });
                  if (!ok && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Edit ditolak oleh RLS')),
                    );
                  }
                } else {
                  await _kosService.add(name: name, address: address, price: price);
                }
                if (mounted) _refreshKos();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text(isEditing ? 'Simpan' : 'Tambah'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteKos(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Kos?'),
        content: const Text('Data tidak bisa dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await _kosService.delete(id);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hapus ditolak oleh RLS')),
        );
      }
      if (mounted) _refreshKos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _profileFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final p = snap.data;
        if (snap.hasError || p == null) {
          return const Scaffold(
            body: Center(child: Text('Gagal memuat profil')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('KosFinder (${p.role})'),
            actions: [
              IconButton(
                tooltip: 'Logout',
                icon: const Icon(Icons.logout),
                onPressed: _logout,
              ),
            ],
          ),
          body: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(p.name.isEmpty ? p.email : p.name),
                subtitle: Text('${p.email} • ${p.role}'),
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _kosFuture,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(child: Text('Error: ${snap.error}'));
                    }
                    final kosList = snap.data ?? [];
                    if (kosList.isEmpty) {
                      return const Center(child: Text('Belum ada data kos'));
                    }
                    return ListView.builder(
                      itemCount: kosList.length,
                      itemBuilder: (context, index) {
                        final kos = kosList[index];
                        final isOwner = kos['owner_id'] == AuthService.instance.currentUser?.id;
                        final canEdit = isOwner || p.isAdmin;
                        return ListTile(
                          title: Text(kos['name'] ?? '-'),
                          subtitle: Text('${kos['address'] ?? '-'} • Rp ${kos['price'] ?? 0}'),
                          trailing: canEdit
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _showKosDialog(kos: kos),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _deleteKos(kos['id']),
                                    ),
                                  ],
                                )
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: RoleGuard(
            role: p.role,
            allowed: const ['owner', 'admin'],
            child: FloatingActionButton.extended(
              onPressed: () => _showKosDialog(),
              icon: const Icon(Icons.add_home),
              label: const Text('Tambah Kos'),
            ),
          ),
        );
      },
    );
  }
}