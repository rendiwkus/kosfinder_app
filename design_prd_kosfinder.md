# Design Product Requirements Document (`DESIGN_PRD.md`)

## KosFinder — UI/UX Design System & Visual Architecture

## 1. Tujuan, Konteks & Selaras Teknis

Dokumen ini adalah spesifikasi desain antarmuka (*UI/UX Design Blueprint*) untuk aplikasi mobile **KosFinder** (`kosfinder_app`). Dokumen ini melengkapi `PRD.md` (spesifikasi fungsional Worksheet 9) dan dirancang khusus untuk dieksekusi oleh AI Coding Assistant yang memiliki skill **`ui-ux-pro-max`** dan **`taste-skill`**.

* **Target Platform**: Mobile (Android / Flutter Material 3)

* **Repository & Branch**: `https://github.com/rendiwkus/kosfinder_app` (Branch wajib: `feature/auth-notification`)

* **Kredensial Backend (Wajib Dipertahankan)**:

  * Supabase URL: `https://zqwzpxzxnpclxhqrtzwv.supabase.co`

  * Supabase Publishable Key: `sb_publishable_a-fEm9bGfYN9iEVVXMgbZw_sfWrbODL`

  * Firebase Core & FCM: `DefaultFirebaseOptions.currentPlatform`

* **Arah Estetika (*Aesthetic Direction*)**: **Modern Warm Hospitality & Trust (PropTech Mobile)** — bersih, lapang, hangat, dan kredibel layaknya platform pencarian hunian modern, dengan hierarki tipografi tegas serta indikator peran (*role*) yang sangat jelas untuk penggunaan nyata maupun bukti dokumentasi praktikum.

## 2. Guardrails untuk AI Agent (`ui-ux-pro-max` & `taste-skill`)

> **ATURAN WAJIB SEBELUM MENGUBAH TAMPILAN:**
> Gunakan kapabilitas **`ui-ux-pro-max`** dan **`taste-skill`** untuk meningkatkan kualitas visual, proporsi ruang (*spatial rhythm*), tipografi, dan *micro-interactions*, **DENGAN SYARAT MUTLAK BERIKUT**:

1. **Zero Regression pada Logika Backend & Security**:

   * **DILARANG** mengubah atau menghapus inisialisasi `Firebase.initializeApp`, `FirebaseMessaging.onBackgroundMessage`, `Supabase.initialize` (URL & Publishable Key), `navigatorKey`, maupun `messengerKey` di `lib/main.dart`.

   * **DILARANG** mengubah logika RLS check (`rows.isNotEmpty`), `AuthService`, `ProfileService`, `KosService`, maupun `NotificationService` (kecuali mempercantik tampilan `SnackBar` foreground pada `NotificationService`).

   * Pertahankan seluruh pesan validasi form persis seperti di `PRD.md` (`Nama wajib diisi`, `Email wajib diisi`, `Format email tidak valid`, `Password wajib diisi`, `Minimal 6 karakter`, `Password tidak sama`) karena diuji pada skenario pengujian.

2. **Visibilitas Wajib untuk Bukti Praktikum (Screenshot Evidence)**:

   * Pada `HomePage`, informasi **Nama**, **Email**, dan **Role** (`seeker` / `owner` / `admin`) **wajib tampil langsung di layar utama** (jangan disembunyikan di dalam Drawer atau tab terpisah).

   * Tombol **Logout** wajib terlihat jelas di header kanan atas `HomePage`.

   * Tombol **Tambah Kos** wajib tetap dibungkus widget `RoleGuard(role: p.role, allowed: const ['owner', 'admin'], ...)`.

   * Tombol **Edit** dan **Hapus** pada setiap kartu kos hanya boleh tampil apabila `kos['owner_id'] == myId` (atau `p.isAdmin`).

3. **Standar Kualitas `taste-skill` (Anti-Generic AI Slop)**:

   * **Spatial Rhythm (8pt Grid)**: Gunakan kelipatan `4, 8, 12, 16, 20, 24, 32` secara konsisten. Berikan ruang bernapas (*whitespace*) yang lega di sekitar elemen.

   * **Surface & Border Discipline**: Hindari bayangan (*elevation*) hitam pekat. Gunakan permukaan putih bersih (`#FFFFFF`) di atas kanvas abu-abu hangat lembut (`#F8FAFC`) dengan garis tepi tipis `1px` (`#E2E8F0`) dan bayangan ambient sangat halus (`Colors.black.withValues(alpha: 0.04)`).

   * **No Unstyled `ListTile` for Property Cards**: Seluruh item kos wajib dirender menggunakan komponen khusus `KosCard`, bukan `ListTile` standar.

   * **No Extra Bloated Packages**: Gunakan fitur native Flutter Material 3 (`ThemeData`, `ColorScheme`, `FontFeature.tabularFigures()`, `AnimatedContainer`) tanpa menambah package eksternal yang berisiko konflik versi.

## 3. Design System & Visual Tokens (`lib/theme/app_theme.dart`)

Buat berkas `lib/theme/app_theme.dart` sebagai sumber kebenaran tunggal (*Single Source of Truth*) untuk seluruh warna, tipografi, radius sudut, dan tema widget aplikasi.

### 3.1 Sistem Warna (*Color Tokens*)

```
class AppColors {
  // Primary Brand — Deep Indigo Slate (Trust & Professionalism)
  static const Color primary = Color(0xFF1E1B4B);        // Indigo 950
  static const Color primaryAccent = Color(0xFF4338CA);  // Indigo 700 (Interactive CTA & Focus)
  static const Color primarySoft = Color(0xFFEEF2FF);    // Indigo 50 (Active container)

  // Secondary Accent — Warm Amber (Hospitality & Price Highlight)
  static const Color amber = Color(0xFFD97706);          // Amber 600
  static const Color amberSoft = Color(0xFFFEF3C7);      // Amber 100

  // Neutral Surfaces & Borders
  static const Color background = Color(0xFFF8FAFC);     // Slate 50 (Main scaffold canvas)
  static const Color surface = Color(0xFFFFFFFF);        // Pure White (Cards & Modals)
  static const Color surfaceInput = Color(0xFFF1F5F9);   // Slate 100 (TextFormField fill)
  static const Color border = Color(0xFFE2E8F0);         // Slate 200 (1px subtle border)

  // Text Hierarchy
  static const Color textPrimary = Color(0xFF0F172A);    // Slate 900
  static const Color textSecondary = Color(0xFF475569);  // Slate 600
  static const Color textMuted = Color(0xFF94A3B8);      // Slate 400

  // Semantic & Role Colors
  static const Color seekerBg = Color(0xFFEFF6FF);       // Blue 50
  static const Color seekerFg = Color(0xFF1D4ED8);       // Blue 700

  static const Color ownerBg = Color(0xFFECFDF5);        // Emerald 50
  static const Color ownerFg = Color(0xFF047857);        // Emerald 700

  static const Color adminBg = Color(0xFFF5F3FF);        // Violet 50
  static const Color adminFg = Color(0xFF6D28D9);        // Violet 700

  static const Color danger = Color(0xFFDC2626);         // Red 600
  static const Color dangerSoft = Color(0xFFFEF2F2);     // Red 50
}

```

### 3.2 Skala Tipografi & Pemformatan Angka

* **Page Header Title**: `24px`, `FontWeight.w700`, `letterSpacing: -0.5`, warna `textPrimary`

* **Section Heading**: `17px`, `FontWeight.w700`, `letterSpacing: -0.3`, warna `textPrimary`

* **Property Card Title**: `16px`, `FontWeight.w600`, warna `textPrimary`

* **Price Display**: `16px`, `FontWeight.w700`, warna `primaryAccent`, gunakan `fontFeatures: [FontFeature.tabularFigures()]` dan format pemisah ribuan titik (contoh: `Rp 850.000 / bln`).

* **Body / Address**: `14px`, `FontWeight.w400`, `height: 1.45`, warna `textSecondary`

* **Role Pill Label**: `11px`, `FontWeight.w700`, `letterSpacing: 0.6`, Uppercase

### 3.3 Radius, Spacing & Ukuran Kontrol

* **Horizontal Screen Margin**: `20.0`

* **Card Border Radius**: `16.0` (`BorderRadius.circular(16)`)

* **Input & Button Border Radius**: `12.0` (`BorderRadius.circular(12)`)

* **Modal Bottom Sheet Top Radius**: `24.0`

* **Minimum CTA Button Height**: `52.0` (*touch-friendly*)

## 4. Arsitektur Komponen & Spesifikasi Per Halaman

### 4.1 Komponen Reusable (`lib/widgets/`)

1. **`lib/widgets/role_badge.dart`**:

   * Pill badge (`StadiumBorder`) dengan padding horizontal `10`, vertikal `5`, border `1px` sesuai warna role, ikon kecil `14px`, dan label jelas:

     * `'seeker'` → Ikon `Icons.search_rounded`, Teks: `PENCARI KOS • SEEKER`, warna `seekerBg` / `seekerFg`

     * `'owner'` → Ikon `Icons.home_work_rounded`, Teks: `PEMILIK KOS • OWNER`, warna `ownerBg` / `ownerFg`

     * `'admin'` → Ikon `Icons.admin_panel_settings_rounded`, Teks: `ADMIN SYSTEM`, warna `adminBg` / `adminFg`

2. **`lib/widgets/kos_card.dart`**:

   * Kartu properti modern dengan latar `AppColors.surface`, `BorderRadius.circular(16)`, border `1px solid AppColors.border`, dan bayangan halus.

   * **Struktur Bagian Atas Card**:

     * Area visual header setinggi `96px` berlatar gradasi lembut (`primarySoft` ke `#E0E7FF`) dengan ikon arsitektur `Icons.apartment_rounded` berukuran `36px` warna `primaryAccent`.

     * Di pojok kiri atas header: Badge status kepemilikan **`Kos Anda`** (warna `ownerBg` / `ownerFg`) apabila `isMine == true`.

     * Di pojok kanan bawah header: Tag harga melayang berlatar putih bersih bertuliskan **`Rp <harga_terformat> / bln`**.

   * **Struktur Bagian Tengah Card (Info)**:

     * Nama Kos (`16px Bold`, `maxLines: 1`, `overflow: TextOverflow.ellipsis`).

     * Baris alamat dengan ikon `Icons.location_on_outlined` (`16px`, `textMuted`) + teks alamat (`13.5px`, `textSecondary`, `maxLines: 2`).

   * **Struktur Bagian Bawah Card (Owner/Admin Actions)**:

     * Ditampilkan **hanya jika `isMine == true || isAdmin == true`**.

     * Garis pemisah `Divider(height: 1, color: AppColors.border)` diikuti baris dua tombol seimbang (`Expanded`):

       * Tombol **Edit**: Soft Indigo (`primarySoft` bg, `primaryAccent` text/icon `Icons.edit_outlined`).

       * Tombol **Hapus**: Soft Red (`dangerSoft` bg, `danger` text/icon `Icons.delete_outline_rounded`).

### 4.2 Halaman Login (`lib/pages/login_page.dart`)

* **Tata Letak**: `SafeArea` + `Center` + `SingleChildScrollView(padding: EdgeInsets.all(24))`.

* **Brand Header**:

  * Kontainer ikon `64x64` (`borderRadius: 18`, latar `primarySoft`, ikon `Icons.home_work_rounded` warna `primaryAccent` ukuran `32`).

  * Judul **`KosFinder`** (`26px Bold`) dan subjudul *"Masuk untuk mencari hunian nyaman atau mengelola properti kos Anda."*

* **Form Login**:

  * Input `Email` dengan `prefixIcon: Icons.email_outlined`.

  * Input `Password` dengan `prefixIcon: Icons.lock_outline_rounded` dan tombol mata (`IconButton`) untuk toggle `_obscurePassword`.

  * Tombol `Login` lebar penuh (`height: 52`) dengan `CircularProgressIndicator` putih `20x20` saat `_loading == true`.

  * Footer navigasi: Teks *"Belum punya akun?"* + tombol teks **`Daftar Sekarang`** menuju `RegisterPage`.

### 4.3 Halaman Register (`lib/pages/register_page.dart`)

* **Pemilih Peran Interaktif (*Role Selector Cards*)**:

  * Ganti dropdown standar menjadi **2 Kartu Pilihan Berdampingan** (`Row` dengan `Expanded` dan `AnimatedContainer` durasi `200ms`) yang mengikat variabel `_role` (`'seeker'` atau `'owner'`):

    * **Kartu 1 (`'seeker'`)**: Ikon `Icons.person_search_rounded`, Judul **`Pencari Kos`**, Subjudul *"Cari & lihat detail kos"*.

    * **Kartu 2 (`'owner'`)**: Ikon `Icons.real_estate_agent_rounded`, Judul **`Pemilik Kos`**, Subjudul *"Pasarkan & kelola kos"*.

  * Kartu aktif memiliki border `2px` warna `primaryAccent`, latar `primarySoft`, dan ikon `Icons.check_circle_rounded` di sudut kanan atas.

* **Form Input**:

  * `Nama Lengkap`, `Email`, `Password` (dengan toggle visibility), `Konfirmasi Password` (dengan toggle visibility), dan tombol CTA **`Daftar Akun`** (`height: 52`).

### 4.4 Halaman Utama (`lib/pages/home_page.dart`)

* **AppBar Bersih**:

  * Judul **`KosFinder`** (`20px Bold`) dengan tombol **Logout** (`IconButton` dengan container lembut di sudut kanan atas) yang memunculkan `AlertDialog` konfirmasi sebelum memanggil `AuthService.instance.logout()`.

* **User Identity & Role Card (Wajib Terlihat di Atas)**:

  * Card putih berborder `1px` dengan layout horizontal:

    * Avatar lingkaran `48x48` berlatar `primaryAccent` dengan huruf inisial nama/email pengguna berwarna putih.

    * Kolom tengah berisi **Nama** (`16px Bold`), **Email** (`13px` `textSecondary`), dan komponen **`RoleBadge`** di bawahnya.

* **Kontrol Kontekstual Berbasis Role**:

  * **Untuk `seeker`**: Search bar modern (*pill/rounded 12px*) dengan ikon `Icons.search_rounded` untuk memfilter daftar kos secara real-time berdasarkan nama atau alamat.

  * **Untuk `owner`**: Baris filter chip cepat (**`Semua Kos`** vs **`Kos Saya`**) serta penghitung jumlah kos milik sendiri.

  * **Untuk `admin`**: Banner informasi beraksen violet bertuliskan **`Mode Administrator • Kelola Seluruh Data Kos`**.

* **Daftar Properti Kos & Pull-to-Refresh**:

  * Bungkus daftar dengan `RefreshIndicator` yang memanggil ulang `KosService().fetchAll()`.

  * Tampilkan daftar `KosCard` dengan jarak antar kartu `16px`.

  * **Empty State**: Jika daftar kosong, tampilkan ikon `Icons.holiday_village_outlined` ukuran `56px` warna `textMuted`, judul *"Belum ada data kos"*, dan deskripsi singkat.

* **Modal Bottom Sheet Tambah & Edit Kos**:

  * Saat tombol **`Tambah Kos`** (di dalam `RoleGuard`) atau tombol **`Edit`** pada `KosCard` ditekan, tampilkan `showModalBottomSheet` (`isScrollControlled: true`, `shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24)))`) dengan *drag handle* kecil di tengah atas.

  * Berisi input `Nama Kos`, `Alamat Lengkap`, `Harga Sewa per Bulan (Rp)`, dan tombol simpan.

  * Jika `KosService().update()` atau `delete()` mengembalikan `false` (ditolak RLS), tampilkan `SnackBar` merah bertuliskan *"Operasi ditolak oleh Row Level Security (RLS)"*.

### 4.5 Halaman Detail Kos (`lib/pages/kos_detail_page.dart`)

* Dibuka ketika pengguna menekan item `KosCard` maupun ketika notifikasi push FCM dengan custom data `kos_id` ditekan (*Bonus Deep Link*).

* Menampilkan:

  * Banner visual properti di bagian atas.

  * Badge `KOS ID: <kosId>` (penting untuk verifikasi pengujian deep link notifikasi).

  * Informasi detail kos (mengambil data dari Supabase berdasarkan `kosId` jika tersedia di database, dengan fallback tampilan aman apabila `kosId` berasal dari payload uji coba).

### 4.6 Tampilan Notifikasi Foreground (`lib/services/notification_service.dart`)

* Perbarui tampilan `SnackBar` pada `FirebaseMessaging.onMessage.listen` menggunakan `messengerKey.currentState?.showSnackBar(...)` dengan desain melayang (*floating toast banner*):

  * `behavior: SnackBarBehavior.floating`

  * `margin: const EdgeInsets.all(16)`

  * `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))`

  * `backgroundColor: AppColors.textPrimary` (`#0F172A`)

  * Konten berisi `Row` dengan ikon `Icons.notifications_active_rounded` warna `AppColors.amber`, diikuti `Column` berisi **Title** (`Bold`, putih) dan **Body** (`13px`, abu-abu terang).

## 5. Struktur Direktori Akhir (Fungsional + Visual)

```
lib/
├── main.dart
├── app_keys.dart
├── firebase_options.dart
├── theme/
│   └── app_theme.dart          # [BARU] Design tokens & Material 3 ThemeData
├── services/
│   ├── auth_service.dart
│   ├── profile_service.dart
│   ├── kos_service.dart
│   └── notification_service.dart
├── widgets/
│   ├── role_guard.dart
│   ├── role_badge.dart         # [BARU] Semantic pill badge untuk role user
│   └── kos_card.dart           # [BARU] Kartu properti kos modern + tombol aksi owner
└── pages/
    ├── login_page.dart         # [REDESIGN] Clean hospitality login screen
    ├── register_page.dart      # [REDESIGN] Register screen + interactive role cards
    ├── home_page.dart          # [REDESIGN] Profile card, filter/search, KosCard feed & modal CRUD
    └── kos_detail_page.dart    # [REDESIGN] Property detail & FCM deep link target

```

## 6. Prompt Eksekusi Siap Pakai untuk AI Agent (VS Code / Antigravity)

Setelah seluruh 7 tahap fungsional pada `PRD.md` selesai dan di-commit, salin dan tempelkan prompt berikut ke chat AI Agent Anda:

```
Gunakan skill ui-ux-pro-max dan taste-skill yang terpasang. Baca file PRD.md dan DESIGN_PRD.md secara menyeluruh, lalu periksa seluruh file di dalam folder lib/ saat ini.

Tugas Anda adalah menerapkan visual polish dan peningkatan UI/UX secara menyeluruh pada aplikasi KosFinder sesuai spesifikasi di DESIGN_PRD.md tanpa merusak satu pun logika Supabase Auth, RLS, KosService, maupun Firebase Cloud Messaging yang sudah berjalan:
1. Buat lib/theme/app_theme.dart berisi AppColors, skala tipografi, dan Material 3 ThemeData, lalu pasang di lib/main.dart (pertahankan URL dan Publishable Key Supabase serta konfigurasi Firebase yang sudah ada).
2. Buat komponen lib/widgets/role_badge.dart dan lib/widgets/kos_card.dart.
3. Redesign lib/pages/login_page.dart dan lib/pages/register_page.dart (terapkan interactive Role Selector Cards untuk seeker/owner dan toggle show/hide password, pertahankan pesan validasi form).
4. Redesign lib/pages/home_page.dart agar menampilkan User Identity & Role Card (Nama, Email, RoleBadge), search/filter bar berbasis role, daftar KosCard dengan tombol Edit/Delete khusus pemiliknya, modal bottom sheet untuk Tambah/Edit Kos, serta tombol Tambah Kos yang dibungkus RoleGuard.
5. Perbarui lib/pages/kos_detail_page.dart dan desain floating SnackBar notifikasi foreground pada lib/services/notification_service.dart.

Setelah selesai, jalankan `flutter analyze` untuk memastikan tidak ada error atau warning kritis.

```

## 7. Perintah Git Commit untuk Perubahan UI/UX

Setelah hasil redesign diverifikasi dengan `flutter analyze` dan dijalankan pada emulator/perangkat (`flutter run`), simpan perubahan ke branch `feature/auth-notification` dengan perintah berikut:

### Opsi A — Commit Bertahap per Lapisan UI (Direkomendasikan)

1. **Commit Design System & Reusable Widgets**:

   ```
   git add lib/theme/ lib/widgets/ lib/main.dart
   git commit -m "style: add KosFinder design system, theme tokens, and reusable UI widgets"
   git push
   
   ```

2. **Commit Redesign Halaman Authentication**:

   ```
   git add lib/pages/login_page.dart lib/pages/register_page.dart
   git commit -m "style: redesign login and register screens with interactive role cards"
   git push
   
   ```

3. **Commit Redesign Dashboard Home, Detail Kos & Foreground Notification**:

   ```
   git add lib/pages/home_page.dart lib/pages/kos_detail_page.dart lib/services/notification_service.dart DESIGN_PRD.md
   git commit -m "style: polish home dashboard, kos cards, detail page, and notification banner"
   git push
   
   ```

### Opsi B — Satu Commit Gabungan Khusus UI/UX Polish

```
git add .
git commit -m "style: enhance UI/UX design system across auth, home, and kos pages"
git push

```