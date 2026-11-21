# Product Requirements Document (PRD)

## KosFinder — Authentication, Authorization & Push Notifications (Worksheet 9)

## 1. Informasi Proyek & Kredensial Backend

Dokumen ini adalah panduan eksekusi *end-to-end* untuk membangun aplikasi **KosFinder** dari awal (*fresh Flutter project* & database Supabase kosong) sesuai spesifikasi **Worksheet 9 Pemrograman Mobile**.

* **Nama Mahasiswa**: Rendi Wija Kusuma (`2415051045`)

* **Nama Project Lokal**: `kosfinder_app` / `kosfinder-app`

* **Repository GitHub**: `https://github.com/rendiwkus/kosfinder_app`

* **Branch Pengembangan Wajib**: `feature/auth-notification`

* **Status Database Awal**: **Kosong (belum ada tabel sama sekali)** — seluruh tabel (`profiles`, `kos`, `device_tokens`), trigger, dan kebijakan RLS harus dibuat dari nol menggunakan skrip SQL pada Bagian 3.

* **Konfigurasi Supabase Project Baru**:

  * **Supabase URL**: `https://zqwzpxzxnpclxhqrtzwv.supabase.co`

  * **Supabase Publishable Key**: `sb_publishable_a-fEm9bGfYN9iEVVXMgbZw_sfWrbODL`

## 2. Protokol Wajib untuk AI Coding Assistant (VS Code / Antigravity)

> **ATURAN EKSEKUSI KETAT — BACA SEBELUM MENULIS KODE:**
> Worksheet 9 mewajibkan riwayat commit Git yang bertahap sesuai fitur yang dikerjakan. **DILARANG KERAS** menggabungkan seluruh fitur menjadi satu commit besar. AI Agent wajib mematuhi alur kerja berikut:

1. **Kerjakan Berurutan per Tahap (Step 1 → Step 7)**:

   * Tulis/perbarui hanya file yang termasuk dalam cakupan tahap yang sedang aktif.

   * Pastikan kode pada tahap tersebut dapat dikompilasi bersih (`flutter analyze` tanpa error) sebelum melakukan commit.

   * Jalankan perintah `git add .`, `git commit -m "..."`, dan `git push` persis setelah menyelesaikan setiap tahap.

2. **Jangan Lompati Dependency Tahap Berikutnya**:

   * Jangan mengimpor `firebase_core` atau `firebase_messaging` pada **Tahap 1–5**, karena paket Firebase baru dipasang dan dikonfigurasi pada **Tahap 6**.

3. **Koordinasi Setup Eksternal**:

   * Sebelum menjalankan pengujian **Tahap 1**, ingatkan user untuk menjalankan SQL setup dan menonaktifkan **Confirm email** di Supabase Dashboard.

   * Sebelum menjalankan **Tahap 6**, ingatkan/bantu user menjalankan `flutterfire configure` di terminal.

4. **Keamanan Kredensial & Token**:

   * Gunakan hanya `url` dan `publishable key` di atas.

   * **JANGAN PERNAH** memasukkan `service_role` key atau token FCM ke dalam source code maupun melakukan commit ke GitHub.

## 3. Setup Awal Database Supabase (Wajib Dijalankan dari Nol)

Karena project Supabase masih kosong, buka **Supabase Dashboard (`zqwzpxzxnpclxhqrtzwv`) → SQL Editor → New Query**, lalu jalankan skrip SQL berikut secara berurutan:

### 3.1 Pengaturan Authentication (Supabase Dashboard)

1. Buka **Authentication → Providers → Email**.

2. Matikan (**Disable**) opsi **Confirm email** lalu klik **Save** (agar user yang baru mendaftar langsung memperoleh sesi aktif dan diarahkan ke `HomePage`).

### 3.2 SQL 1 — Tabel `public.profiles` & Trigger Auto-Profile

```
-- 1. Buat tabel profiles
create table if not exists public.profiles (
  id    uuid primary key references auth.users(id) on delete cascade,
  email text,
  name  text,
  role  text not null default 'seeker'
        check (role in ('seeker', 'owner', 'admin'))
);

-- 2. Aktifkan RLS pada profiles (user hanya bisa baca profil sendiri, tidak bisa update role sendiri)
alter table public.profiles enable row level security;

create policy "profiles_select_own"
  on public.profiles for select to authenticated
  using (auth.uid() = id);

-- 3. Trigger otomatis saat user baru register
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', ''),
    case
      when new.raw_user_meta_data->>'role' in ('seeker', 'owner')
        then new.raw_user_meta_data->>'role'
      else 'seeker'
    end
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

```

### 3.3 SQL 2 — Tabel `public.kos` & Kebijakan Row Level Security (RLS)

```
-- 1. Buat tabel kos
create table if not exists public.kos (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null default auth.uid()
             references auth.users(id) on delete cascade,
  name       text not null,
  address    text,
  price      integer,
  created_at timestamptz not null default now()
);

-- 2. Aktifkan RLS pada kos
alter table public.kos enable row level security;

-- Policy SELECT: semua user login boleh melihat daftar kos
create policy "kos_select_authenticated"
  on public.kos for select to authenticated
  using (true);

-- Policy INSERT: owner_id harus sama dengan user login & role harus owner atau admin
create policy "kos_insert_owner"
  on public.kos for insert to authenticated
  with check (
    auth.uid() = owner_id
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('owner', 'admin')
    )
  );

-- Policy UPDATE: hanya pemilik data kos
create policy "kos_update_own"
  on public.kos for update to authenticated
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- Policy DELETE: hanya pemilik data kos
create policy "kos_delete_own"
  on public.kos for delete to authenticated
  using (auth.uid() = owner_id);

-- Helper function & Policy khusus Admin
create or replace function public.is_admin()
returns boolean
language sql stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

create policy "kos_admin_all"
  on public.kos for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

```

### 3.4 SQL 3 — Tabel `public.device_tokens` (FCM Device Registration)

```
create table if not exists public.device_tokens (
  token      text primary key,
  user_id    uuid not null default auth.uid()
             references auth.users(id) on delete cascade,
  platform   text,
  updated_at timestamptz not null default now()
);

alter table public.device_tokens enable row level security;

create policy "tokens_select_own" on public.device_tokens
  for select to authenticated using (auth.uid() = user_id);

create policy "tokens_insert_own" on public.device_tokens
  for insert to authenticated with check (auth.uid() = user_id);

create policy "tokens_update_own" on public.device_tokens
  for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "tokens_delete_own" on public.device_tokens
  for delete to authenticated using (auth.uid() = user_id);

```

## 4. Langkah Persiapan Project & Git (Step 0)

Pastikan terminal berada di root folder project Flutter baru, lalu jalankan perintah berikut untuk memasang `supabase_flutter` dan memastikan berada di branch `feature/auth-notification`:

```
flutter pub add supabase_flutter
git status
# Jika belum berada di branch feature/auth-notification:
git checkout -b feature/auth-notification

```

## 5. Rencana Implementasi & Commit Bertahap (Step 1 – Step 7)

### STEP 1 — Authentication Flow (Register, Login & Home Awal)

* **Target File**:

  * `lib/services/auth_service.dart`

  * `lib/pages/register_page.dart`

  * `lib/pages/login_page.dart`

  * `lib/pages/home_page.dart`

  * `lib/main.dart`

#### 1.1 `lib/services/auth_service.dart`

```
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  bool get isLoggedIn => currentSession != null;

  Future<AuthResponse> register({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> logout() => _client.auth.signOut();
}

```

#### 1.2 `lib/pages/register_page.dart`

```
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _confirmC = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await AuthService.instance.register(
        email: _emailC.text.trim(),
        password: _passC.text,
      );
      if (!mounted) return;
      if (res.session != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      } else {
        _showMessage('Registrasi berhasil. Silakan cek email Anda.');
        Navigator.of(context).pop();
      }
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                  if (!v.contains('@')) return 'Format email tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passC,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password wajib diisi';
                  if (v.length < 6) return 'Minimal 6 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmC,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Konfirmasi Password'),
                validator: (v) =>
                    v != _passC.text ? 'Password tidak sama' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

```

#### 1.3 `lib/pages/login_page.dart`

```
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'home_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.login(
        email: _emailC.text.trim(),
        password: _passC.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Terjadi kesalahan. Periksa koneksi internet Anda.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login KosFinder')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Email wajib diisi'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passC,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Login'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterPage()),
                ),
                child: const Text('Belum punya akun? Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

```

#### 1.4 `lib/pages/home_page.dart` (Versi Step 1)

```
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('KosFinder')),
      body: Center(child: Text('Login sebagai: ${user?.email ?? '-'}')),
    );
  }
}

```

#### 1.5 `lib/main.dart` (Versi Step 1)

```
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://zqwzpxzxnpclxhqrtzwv.supabase.co',
    anonKey: 'sb_publishable_a-fEm9bGfYN9iEVVXMgbZw_sfWrbODL',
  );
  runApp(const KosFinderApp());
}

class KosFinderApp extends StatelessWidget {
  const KosFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KosFinder',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const LoginPage(),
    );
  }
}

```

#### Perintah Commit Step 1 (Wajib Jalankan Setelah `flutter analyze` Bersih)

```
git add .
git commit -m "feat: implement user authentication"
git push -u origin feature/auth-notification

```

### STEP 2 — Logout & Session Persistence

* **Target File**:

  * `lib/app_keys.dart` (Baru)

  * `lib/main.dart` (Update check session + `onAuthStateChange`)

  * `lib/pages/home_page.dart` (Tambah tombol Logout)

#### 2.1 `lib/app_keys.dart`

```
import 'package:flutter/material.dart';

/// Key global agar navigasi/snackbar bisa dipanggil dari luar widget
final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

```

#### 2.2 `lib/pages/home_page.dart` (Versi Step 2)

```
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('KosFinder'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.instance.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Center(child: Text('Login sebagai: ${user?.email ?? '-'}')),
    );
  }
}

```

#### 2.3 `lib/main.dart` (Versi Step 2)

```
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_keys.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://zqwzpxzxnpclxhqrtzwv.supabase.co',
    anonKey: 'sb_publishable_a-fEm9bGfYN9iEVVXMgbZw_sfWrbODL',
  );

  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    debugPrint('Auth event: ${data.event}');
    if (data.event == AuthChangeEvent.signedOut) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  });

  runApp(const KosFinderApp());
}

class KosFinderApp extends StatelessWidget {
  const KosFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KosFinder',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      home: AuthService.instance.isLoggedIn
          ? const HomePage()
          : const LoginPage(),
    );
  }
}

```

#### Perintah Commit Step 2

```
git add .
git commit -m "feat: implement authentication session and logout"
git push

```

### STEP 3 — Menambahkan Role Pengguna (`seeker`, `owner`, `admin`)

* **Target File**:

  * `lib/services/auth_service.dart` (Update `register` terima `name` & `role`)

  * `lib/pages/register_page.dart` (Tambah field `Nama` & dropdown `Daftar sebagai`)

  * `lib/services/profile_service.dart` (Baru)

  * `lib/pages/home_page.dart` (Tampilkan `Nama`, `Email`, dan `Role` dari `profiles`)

#### 3.1 `lib/services/auth_service.dart` (Versi Step 3)

```
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  bool get isLoggedIn => currentSession != null;

  Future<AuthResponse> register({
    required String email,
    required String password,
    String name = '',
    String role = 'seeker',
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'role': role},
    );
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> logout() => _client.auth.signOut();
}

```

#### 3.2 `lib/pages/register_page.dart` (Versi Step 3)

```
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _confirmC = TextEditingController();
  String _role = 'seeker';
  bool _loading = false;

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _passC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await AuthService.instance.register(
        email: _emailC.text.trim(),
        password: _passC.text,
        name: _nameC.text.trim(),
        role: _role,
      );
      if (!mounted) return;
      if (res.session != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      } else {
        _showMessage('Registrasi berhasil. Silakan cek email Anda.');
        Navigator.of(context).pop();
      }
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameC,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama wajib diisi'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Daftar sebagai'),
                items: const [
                  DropdownMenuItem(value: 'seeker', child: Text('Pencari Kos')),
                  DropdownMenuItem(value: 'owner', child: Text('Pemilik Kos')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'seeker'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                  if (!v.contains('@')) return 'Format email tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passC,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password wajib diisi';
                  if (v.length < 6) return 'Minimal 6 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmC,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Konfirmasi Password'),
                validator: (v) =>
                    v != _passC.text ? 'Password tidak sama' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

```

#### 3.3 `lib/services/profile_service.dart`

```
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  final String id;
  final String email;
  final String name;
  final String role; // 'seeker' | 'owner' | 'admin'

  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  bool get isSeeker => role == 'seeker';
  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin';

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        id: m['id'] as String,
        email: (m['email'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        role: (m['role'] ?? 'seeker') as String,
      );
}

class ProfileService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<UserProfile?> getMyProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    return data == null ? null : UserProfile.fromMap(data);
  }
}

```

#### 3.4 `lib/pages/home_page.dart` (Versi Step 3)

```
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<UserProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = ProfileService().getMyProfile();
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KosFinder'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: FutureBuilder<UserProfile?>(
        future: _profileFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return const Center(child: Text('Gagal memuat profil'));
          }
          final p = snap.data!;
          return ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Nama'),
                subtitle: Text(p.name.isEmpty ? '-' : p.name),
              ),
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Email'),
                subtitle: Text(p.email),
              ),
              ListTile(
                leading: const Icon(Icons.badge),
                title: const Text('Role'),
                subtitle: Text(p.role),
              ),
            ],
          );
        },
      ),
    );
  }
}

```

#### Perintah Commit Step 3

```
git add .
git commit -m "feat: implement user roles"
git push

```

### STEP 4 — Authorization pada UI (`RoleGuard`)

* **Target File**:

  * `lib/widgets/role_guard.dart` (Baru)

  * `lib/pages/home_page.dart` (Update tampilan menu dan tombol FAB berdasarkan role)

#### 4.1 `lib/widgets/role_guard.dart`

```
import 'package:flutter/material.dart';

class RoleGuard extends StatelessWidget {
  const RoleGuard({
    super.key,
    required this.role,
    required this.allowed,
    required this.child,
  });

  final String role;
  final List<String> allowed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return allowed.contains(role) ? child : const SizedBox.shrink();
  }
}

```

#### 4.2 `lib/pages/home_page.dart` (Versi Step 4)

```
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
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

  @override
  void initState() {
    super.initState();
    _profileFuture = ProfileService().getMyProfile();
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
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
          body: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(p.name.isEmpty ? p.email : p.name),
                subtitle: Text('${p.email} • ${p.role}'),
              ),
              const Divider(),
              const ListTile(
                leading: Icon(Icons.list),
                title: Text('Daftar Kos'),
              ),
              if (p.isOwner || p.isAdmin)
                const ListTile(
                  leading: Icon(Icons.home_work),
                  title: Text('My Kos'),
                ),
              if (p.isAdmin)
                const ListTile(
                  leading: Icon(Icons.admin_panel_settings),
                  title: Text('Kelola Data (Admin)'),
                ),
            ],
          ),
          floatingActionButton: RoleGuard(
            role: p.role,
            allowed: const ['owner', 'admin'],
            child: FloatingActionButton.extended(
              onPressed: () {
                // Akan dihubungkan ke form Tambah Kos pada Step 5
              },
              icon: const Icon(Icons.add_home),
              label: const Text('Tambah Kos'),
            ),
          ),
        );
      },
    );
  }
}

```

#### Perintah Commit Step 4

```
git add .
git commit -m "feat: implement role based interface authorization"
git push

```

### STEP 5 — Row Level Security (RLS), CRUD `KosService` & Security Testing

* **Target File**:

  * `lib/services/kos_service.dart` (Baru — CRUD dengan pengecekan baris terpengaruh RLS)

  * `lib/pages/home_page.dart` (Update — tampilkan daftar kos dari `KosService`, dialog Tambah/Edit Kos untuk `owner`/`admin`, dan tombol Edit/Delete hanya jika `kos['owner_id'] == myId`)

#### 5.1 `lib/services/kos_service.dart`

```
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KosService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _uid => _client.auth.currentUser!.id;

  Future<List<Map<String, dynamic>>> fetchAll() async {
    final data = await _client
        .from('kos')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> add({
    required String name,
    required String address,
    required int price,
  }) async {
    await _client.from('kos').insert({
      'owner_id': _uid,
      'name': name,
      'address': address,
      'price': price,
    });
  }

  /// true = berhasil, false = ditolak RLS / data tidak ditemukan
  Future<bool> update(String id, Map<String, dynamic> values) async {
    final rows =
        await _client.from('kos').update(values).eq('id', id).select();
    return rows.isNotEmpty;
  }

  /// true = berhasil, false = ditolak RLS / data tidak ditemukan
  Future<bool> delete(String id) async {
    final rows = await _client.from('kos').delete().eq('id', id).select();
    return rows.isNotEmpty;
  }

  /// Helper untuk pengujian keamanan lintas akun (Praktik 6)
  Future<void> runSecurityTest(String kosIdMilikUserA, String uuidUserA) async {
    final updated = await update(kosIdMilikUserA, {'name': 'DIUBAH USER B'});
    debugPrint(updated
        ? '[FAIL] User B berhasil mengubah data User A'
        : '[PASS] UPDATE ditolak oleh RLS');

    final deleted = await delete(kosIdMilikUserA);
    debugPrint(deleted
        ? '[FAIL] User B berhasil menghapus data User A'
        : '[PASS] DELETE ditolak oleh RLS');

    try {
      await _client.from('kos').insert({
        'owner_id': uuidUserA,
        'name': 'Kos palsu',
        'address': 'Alamat palsu',
        'price': 500000,
      });
      debugPrint('[FAIL] INSERT atas nama user lain berhasil');
    } on PostgrestException catch (e) {
      debugPrint('[PASS] INSERT ditolak: ${e.code} - ${e.message}');
    }
  }
}

```

#### 5.2 `lib/pages/home_page.dart` (Versi Step 5 — Integrasi Daftar Kos, Modal CRUD & RLS Check)

*Implementasikan daftar kos menggunakan `KosService().fetchAll()`, dialog/bottom sheet untuk menambah & mengubah kos, serta tombol Edit dan Delete pada item kos yang hanya tampil apabila `kos['owner_id'] == myId` (atau `p.isAdmin`). Pastikan menampilkan `SnackBar` jika operasi ditolak oleh RLS (`false`).*

#### Perintah Commit Step 5

```
git add .
git commit -m "security: implement row level security policies"
git push

```

### STEP 6 — Konfigurasi Firebase Cloud Messaging (FCM)

* **Langkah Terminal (Wajib Dijalankan Sebelum Coding Step 6)**:

  ```
  flutter pub add firebase_core firebase_messaging
  flutterfire configure
  
  ```

* **Target File**:

  * `lib/firebase_options.dart` (Dihasilkan otomatis oleh `flutterfire configure`)

  * `android/app/src/main/AndroidManifest.xml` (Tambahkan izin notifikasi Android 13+)

  * `lib/main.dart` (Tambahkan `Firebase.initializeApp`)

#### 6.1 `android/app/src/main/AndroidManifest.xml`

Tambahkan tepat di dalam tag `<manifest>`, di atas tag `<application>`:

```
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

```

#### 6.2 `lib/main.dart` (Versi Step 6)

```
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_keys.dart';
import 'firebase_options.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Supabase.initialize(
    url: 'https://zqwzpxzxnpclxhqrtzwv.supabase.co',
    anonKey: 'sb_publishable_a-fEm9bGfYN9iEVVXMgbZw_sfWrbODL',
  );

  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    debugPrint('Auth event: ${data.event}');
    if (data.event == AuthChangeEvent.signedOut) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  });

  runApp(const KosFinderApp());
}

class KosFinderApp extends StatelessWidget {
  const KosFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KosFinder',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      home: AuthService.instance.isLoggedIn
          ? const HomePage()
          : const LoginPage(),
    );
  }
}

```

#### Perintah Commit Step 6

```
git add .
git commit -m "chore: configure firebase cloud messaging"
git push

```

### STEP 7 — Notification Permission, FCM Token, Receiver & Deep Link (Bonus)

* **Target File**:

  * `lib/pages/kos_detail_page.dart` (Baru — halaman tujuan saat notifikasi diklik)

  * `lib/services/notification_service.dart` (Baru — permission, FCM token, simpan token ke `device_tokens`, foreground listener, background handler, dan tap handler)

  * `lib/main.dart` (Daftarkan `FirebaseMessaging.onBackgroundMessage`)

  * `lib/pages/home_page.dart` (Panggil `NotificationService.instance.init()` dan `setupInteractedMessage()` di `initState`)

#### 7.1 `lib/pages/kos_detail_page.dart`

```
import 'package:flutter/material.dart';

class KosDetailPage extends StatelessWidget {
  const KosDetailPage({super.key, required this.kosId});

  final String kosId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Kos')),
      body: Center(child: Text('Kos ID: $kosId')),
    );
  }
}

```

#### 7.2 `lib/services/notification_service.dart`

```
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_keys.dart';
import '../firebase_options.dart';
import '../pages/kos_detail_page.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('[BACKGROUND] ${message.notification?.title}');
  debugPrint('[BACKGROUND] ${message.notification?.body}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<AuthorizationStatus> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('Notification permission: ${settings.authorizationStatus.name}');
    return settings.authorizationStatus;
  }

  Future<String?> getToken() async {
    final token = await _messaging.getToken();
    debugPrint('FCM Token: $token');
    return token;
  }

  void listenTokenRefresh(void Function(String token) onRefresh) {
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM Token diperbarui');
      onRefresh(newToken);
    });
  }

  Future<void> saveTokenToSupabase(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await Supabase.instance.client.from('device_tokens').upsert({
      'token': token,
      'user_id': user.id,
      'platform': defaultTargetPlatform.name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> init() async {
    await requestPermission();
    final token = await getToken();
    if (token != null) await saveTokenToSupabase(token);
    listenTokenRefresh(saveTokenToSupabase);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FOREGROUND] Notification received');
      debugPrint('title: ${message.notification?.title}');
      debugPrint('body : ${message.notification?.body}');
      debugPrint('data : ${message.data}');

      final title = message.notification?.title ?? 'Notifikasi';
      final body = message.notification?.body ?? '';
      messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('$title\n$body')),
      );
    });
  }

  Future<void> setupInteractedMessage() async {
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleTap(initial);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
  }

  void _handleTap(RemoteMessage message) {
    final kosId = message.data['kos_id'];
    if (kosId == null) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => KosDetailPage(kosId: kosId.toString()),
      ),
    );
  }
}

```

#### 7.3 `lib/main.dart` (Versi Final Step 7)

```
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_keys.dart';
import 'firebase_options.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await Supabase.initialize(
    url: 'https://zqwzpxzxnpclxhqrtzwv.supabase.co',
    anonKey: 'sb_publishable_a-fEm9bGfYN9iEVVXMgbZw_sfWrbODL',
  );

  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    debugPrint('Auth event: ${data.event}');
    if (data.event == AuthChangeEvent.signedOut) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  });

  runApp(const KosFinderApp());
}

class KosFinderApp extends StatelessWidget {
  const KosFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KosFinder',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      home: AuthService.instance.isLoggedIn
          ? const HomePage()
          : const LoginPage(),
    );
  }
}

```

#### 7.4 Pemanggilan di `lib/pages/home_page.dart` (`initState`)

```
@override
void initState() {
  super.initState();
  _profileFuture = ProfileService().getMyProfile();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await NotificationService.instance.init();
    await NotificationService.instance.setupInteractedMessage();
  });
}

```

#### Perintah Commit Step 7 (Commit Akhir Fungsional)

```
git add .
git commit -m "feat: implement push notification with FCM"
git push

```

## 6. Prompt Eksekusi Siap Pakai untuk AI Agent (VS Code / Antigravity)

Salin dan tempelkan prompt berikut ke chat AI Agent Anda:

```
Baca file PRD.md secara menyeluruh. Project Flutter dan database Supabase ini masih benar-benar baru dan kosong.
Tugas Anda adalah mengeksekusi pembangunan aplikasi KosFinder secara BERURUTAN dari Step 1 hingga Step 7 sesuai PRD.md:
- Pastikan Anda membuat/memperbarui file HANYA untuk satu step pada satu waktu.
- Jalankan `flutter analyze` pada setiap akhir step untuk memastikan tidak ada error kompilasi.
- Setelah setiap step selesai dan bersih, langsung jalankan perintah `git add .`, `git commit -m "..."`, dan `git push` yang tercantum pada step tersebut sebelum melangkah ke step berikutnya.
- Jangan menggabungkan beberapa step ke dalam satu commit.

Mulai sekarang dengan memeriksa pubspec.yaml, memasang `supabase_flutter` jika belum ada, dan mengerjakan STEP 1 terlebih dahulu.

```