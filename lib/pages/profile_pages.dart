import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:apps_k24/theme/app_colors.dart';
import 'package:apps_k24/theme/gaps.dart';
import 'package:apps_k24/services/api_service.dart';
import 'package:apps_k24/components/toast_helper.dart';
import 'package:apps_k24/components/profile_security_sheets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

// Helper method for input styling
InputDecoration _buildSettingsInputDecoration(String hint, IconData icon) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
    ),
    prefixIcon: Icon(icon, color: AppColors.primaryGreen, size: 20),
  );
}

// Global Profile Image builder supporting Base64, Asset, Network, and local File path
Widget buildProfileImage(String? path, {double size = 80, IconData fallbackIcon = Icons.person_rounded, Color fallbackColor = AppColors.secondaryBlue}) {
  if (path == null || path.isEmpty) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: fallbackColor.withOpacity(0.12),
      child: Icon(fallbackIcon, size: size * 0.54, color: fallbackColor),
    );
  }

  Widget img;
  if (path.startsWith('data:image')) {
    try {
      final base64Bytes = base64Decode(path.split(',')[1]);
      img = Image.memory(base64Bytes, fit: BoxFit.cover);
    } catch (e) {
      img = Icon(fallbackIcon, size: size * 0.54, color: fallbackColor);
    }
  } else if (path.startsWith('assets/')) {
    img = Image.asset(path, fit: BoxFit.cover);
  } else if (path.startsWith('/uploads/')) {
    final base = ApiService.baseUrl.replaceAll('/api', '');
    img = Image.network(
      '$base$path',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Icon(fallbackIcon, size: size * 0.54, color: fallbackColor),
    );
  } else if (path.startsWith('blob:') || path.startsWith('http://') || path.startsWith('https://') || kIsWeb) {
    img = Image.network(
      path,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Icon(fallbackIcon, size: size * 0.54, color: fallbackColor),
    );
  } else {
    img = Image.file(File(path), fit: BoxFit.cover);
  }

  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2), width: 1.5),
    ),
    clipBehavior: Clip.antiAlias,
    child: img,
  );
}

// -------------------------------------------------------------
// 1. PENGATURAN PROFIL PAGE
// -------------------------------------------------------------
class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _plateController = TextEditingController();
  String? _rating;
  String? _userRole;
  String? _customProfilePicPath;
  bool _isLoading = true;
  bool _isSaving = false;

  int _selectedAvatarIndex = 0;

  final List<Map<String, dynamic>> _avatars = [
    {'icon': Icons.person_rounded, 'color': AppColors.secondaryBlue, 'label': 'Default User'},
    {'icon': Icons.medical_services_rounded, 'color': AppColors.primaryGreen, 'label': 'Apoteker/Medic'},
    {'icon': Icons.two_wheeler_rounded, 'color': Colors.orange, 'label': 'Delivery Kurir'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final name = await ApiService.getName() ?? "";
      final email = await ApiService.getEmail() ?? "";
      final phone = await ApiService.getPhone() ?? "";
      final plate = await ApiService.getPlate() ?? "";
      final rating = await ApiService.getRating() ?? "5.00";
      final role = await ApiService.getRole() ?? "DRIVER";

      final prefs = await SharedPreferences.getInstance();
      final avatarIndex = prefs.getInt('user_avatar_index') ?? 0;
      final customPic = prefs.getString('user_profile_pic_path');

      setState(() {
        _nameController.text = name;
        _emailController.text = email;
        _phoneController.text = phone;
        _plateController.text = plate;
        _rating = rating;
        _userRole = role;
        _selectedAvatarIndex = avatarIndex;
        _customProfilePicPath = customPic;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Ganti Foto Profil",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                  textAlign: TextAlign.center,
                ),
                gapH20,
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F8F0),
                    child: Icon(Icons.camera_alt_rounded, color: AppColors.primaryGreen),
                  ),
                  title: const Text("Ambil dari Kamera", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Gunakan kamera asli perangkat Anda", style: TextStyle(fontSize: 11)),
                  onTap: () async {
                    debugPrint("[ImagePicker Diagnostic] Camera option tapped.");
                    final navigator = Navigator.of(context);
                    navigator.pop(); // Dismiss bottom sheet safely
                    try {
                      debugPrint("[ImagePicker Diagnostic] Calling ImagePicker().pickImage(source: camera)...");
                      final XFile? file = await ImagePicker().pickImage(
                        source: ImageSource.camera,
                        imageQuality: 80,
                      );
                      debugPrint("[ImagePicker Diagnostic] Camera picker returned. Path: ${file?.path}");
                      if (file != null && mounted) {
                        debugPrint("[ImagePicker Diagnostic] Navigating to ImageCropScreen with path: ${file.path}");
                        final resultPath = await navigator.push(
                          MaterialPageRoute(
                            builder: (context) => ImageCropScreen(
                              imagePath: file.path,
                              isAsset: false,
                            ),
                          ),
                        );
                        debugPrint("[ImagePicker Diagnostic] Returned from crop screen: $resultPath");
                        if (resultPath != null) {
                          _saveSelectedProfilePic(resultPath);
                        }
                      } else {
                        debugPrint("[ImagePicker Diagnostic] No image file picked (user cancelled or state unmounted).");
                      }
                    } catch (e, stack) {
                      debugPrint("[ImagePicker Diagnostic Error] Camera exception: $e\n$stack");
                      if (mounted) {
                        ToastHelper.show(context, message: "Gagal membuka kamera: $e", isError: true);
                      }
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE6F0FA),
                    child: Icon(Icons.photo_library_rounded, color: AppColors.secondaryBlue),
                  ),
                  title: const Text("Pilih dari Galeri", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Pilih foto asli dari galeri album Anda", style: TextStyle(fontSize: 11)),
                  onTap: () async {
                    debugPrint("[ImagePicker Diagnostic] Gallery option tapped.");
                    final navigator = Navigator.of(context);
                    navigator.pop(); // Dismiss bottom sheet safely
                    try {
                      debugPrint("[ImagePicker Diagnostic] Calling ImagePicker().pickImage(source: gallery)...");
                      final XFile? file = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 80,
                      );
                      debugPrint("[ImagePicker Diagnostic] Gallery picker returned. Path: ${file?.path}");
                      if (file != null && mounted) {
                        debugPrint("[ImagePicker Diagnostic] Navigating to ImageCropScreen with path: ${file.path}");
                        final resultPath = await navigator.push(
                          MaterialPageRoute(
                            builder: (context) => ImageCropScreen(
                              imagePath: file.path,
                              isAsset: false,
                            ),
                          ),
                        );
                        debugPrint("[ImagePicker Diagnostic] Returned from crop screen: $resultPath");
                        if (resultPath != null) {
                          _saveSelectedProfilePic(resultPath);
                        }
                      } else {
                        debugPrint("[ImagePicker Diagnostic] No gallery file picked (user cancelled or state unmounted).");
                      }
                    } catch (e, stack) {
                      debugPrint("[ImagePicker Diagnostic Error] Gallery exception: $e\n$stack");
                      if (mounted) {
                        ToastHelper.show(context, message: "Gagal membuka galeri: $e", isError: true);
                      }
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEE8E8),
                    child: Icon(Icons.face_retouching_natural_rounded, color: AppColors.accentRed),
                  ),
                  title: const Text("Pilih Avatar Karakter", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Pilih salah satu karakter default", style: TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.pop(context);
                    _showCharacterAvatarSelector();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCharacterAvatarSelector() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("Pilih Avatar Default", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_avatars.length, (index) {
              final av = _avatars[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: av['color'].withOpacity(0.12),
                  child: Icon(av['icon'], color: av['color']),
                ),
                title: Text(av['label'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                trailing: _selectedAvatarIndex == index && _customProfilePicPath == null
                    ? const Icon(Icons.check_circle, color: AppColors.primaryGreen)
                    : null,
                onTap: () async {
                  setState(() {
                    _selectedAvatarIndex = index;
                    _customProfilePicPath = null;
                  });
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('user_avatar_index', index);
                  await prefs.remove('user_profile_pic_path');
                  if (context.mounted) {
                    Navigator.pop(context);
                    ToastHelper.show(context, message: "Avatar berhasil diubah!");
                  }
                },
              );
            }),
          ),
        );
      },
    );
  }

  Future<void> _saveSelectedProfilePic(String path) async {
    setState(() {
      _customProfilePicPath = path;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile_pic_path', path);
    if (mounted) {
      ToastHelper.show(context, message: "Foto profil berhasil diperbarui!");
    }
  }

  Future<void> _handleSaveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await ApiService.updateProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        plateNumber: _plateController.text.trim(),
        profilePicture: _customProfilePicPath,
      );

      // Re-save local credentials
      final token = await ApiService.getToken() ?? "";
      final role = await ApiService.getRole() ?? "DRIVER";
      await ApiService.saveAuthData(
        token,
        _nameController.text.trim(),
        _emailController.text.trim(),
        role,
        phone: _phoneController.text.trim(),
        plate: _plateController.text.trim(),
        rating: _rating,
      );

      if (mounted) {
        ToastHelper.show(context, message: "Profil berhasil disimpan!");
        Navigator.pop(context, true); // Return success to reload parent profile
      }
    } catch (e) {
      debugPrint("[SaveProfile Action Error]: $e");
      if (mounted) {
        ToastHelper.show(context, message: e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
      );
    }

    final activeAvatar = _avatars[_selectedAvatarIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Pengaturan Profil", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkGrey,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Photo Selector Card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        _customProfilePicPath != null
                            ? buildProfileImage(_customProfilePicPath, size: 100)
                            : buildProfileImage(
                                null,
                                size: 100,
                                fallbackIcon: activeAvatar['icon'],
                                fallbackColor: activeAvatar['color'],
                              ),
                        GestureDetector(
                          onTap: _showAvatarPicker,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                    gapH12,
                    const Text(
                      "Foto Profil Pengguna",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkGrey),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "Ketuk ikon kamera untuk mengubah foto profil",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              gapH20,

              // Detail fields card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Nama Lengkap", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkGrey)),
                    gapH8,
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(fontSize: 14, color: AppColors.darkGrey),
                      decoration: _buildSettingsInputDecoration("Nama Lengkap Anda", Icons.person_outline_rounded),
                      validator: (v) => v == null || v.trim().isEmpty ? "Nama wajib diisi" : null,
                    ),
                    gapH16,

                    const Text("Email Terdaftar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkGrey)),
                    gapH8,
                    TextFormField(
                      controller: _emailController,
                      style: const TextStyle(fontSize: 14, color: AppColors.darkGrey),
                      keyboardType: TextInputType.emailAddress,
                      decoration: _buildSettingsInputDecoration("Alamat email resmi", Icons.email_outlined),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return "Email wajib diisi";
                        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                        if (!emailRegex.hasMatch(v)) return "Format email tidak valid";
                        return null;
                      },
                    ),
                    gapH16,

                    const Text("Nomor Telepon", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkGrey)),
                    gapH8,
                    TextFormField(
                      controller: _phoneController,
                      style: const TextStyle(fontSize: 14, color: AppColors.darkGrey),
                      keyboardType: TextInputType.phone,
                      decoration: _buildSettingsInputDecoration("Nomor HP aktif", Icons.phone_android_rounded),
                    ),

                    if (_userRole == 'DRIVER' || _userRole == 'MITRA') ...[
                      gapH16,
                      const Text("Plat Nomor Kendaraan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkGrey)),
                      gapH8,
                      TextFormField(
                        controller: _plateController,
                        style: const TextStyle(fontSize: 14, color: AppColors.darkGrey),
                        decoration: _buildSettingsInputDecoration("Contoh: AB 1234 CD", Icons.two_wheeler_rounded),
                      ),
                    ],

                    if (_userRole == 'DRIVER') ...[
                      gapH16,
                      const Text("Rating Pengemudi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkGrey)),
                      gapH8,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rate_rounded, color: Colors.amber, size: 20),
                            gapW12,
                            Text(
                              "${_rating ?? '5.00'} / 5.00",
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkGrey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              gapH24,

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                ),
                onPressed: _isSaving ? null : _handleSaveProfile,
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        "Simpan Perubahan",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 2. KEAMANAN AKUN PAGE
// -------------------------------------------------------------
class AccountSecurityPage extends StatelessWidget {
  const AccountSecurityPage({super.key});



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Keamanan Akun", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkGrey,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Unified settings card container (Big wrapper card with dividers)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_outline_rounded, color: AppColors.primaryGreen, size: 20),
                    ),
                    title: const Text(
                      "Ganti Kata Sandi",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkGrey, fontFamily: 'Poppins'),
                    ),
                    subtitle: const Text("Ubah kata sandi berkala untuk menjaga akun", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ChangePasswordPage())),
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 20, color: Color(0xFFEDF2F7)),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.email_outlined, color: AppColors.primaryGreen, size: 20),
                    ),
                    title: const Text(
                      "Verifikasi Alamat Email",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkGrey, fontFamily: 'Poppins'),
                    ),
                    subtitle: const Text("Pastikan email aktif untuk notifikasi keamanan", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VerifyEmailPage())),
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 20, color: Color(0xFFEDF2F7)),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.face_retouching_natural_rounded, color: AppColors.primaryGreen, size: 20),
                    ),
                    title: const Text(
                      "Verifikasi Wajah Biometrik",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkGrey, fontFamily: 'Poppins'),
                    ),
                    subtitle: const Text("Simpan data wajah di backend untuk login biometrik", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MockFaceCameraScreen(isRegisterMode: true),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 3. GANTI PASSWORD PAGE
// -------------------------------------------------------------
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSaving = false;

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await ApiService.changePassword(
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (mounted) {
        ToastHelper.show(context, message: "Kata sandi sukses diperbarui!");
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.show(context, message: e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Ganti Kata Sandi", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkGrey,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Sandi Lama", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkGrey)),
                    gapH8,
                    TextFormField(
                      controller: _oldPasswordController,
                      obscureText: true,
                      style: const TextStyle(fontSize: 14, color: AppColors.darkGrey),
                      decoration: _buildSettingsInputDecoration("Masukkan sandi lama Anda", Icons.lock_outline_rounded),
                      validator: (v) => v == null || v.isEmpty ? "Wajib diisi" : null,
                    ),
                    gapH16,

                    const Text("Sandi Baru", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkGrey)),
                    gapH8,
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: true,
                      style: const TextStyle(fontSize: 14, color: AppColors.darkGrey),
                      decoration: _buildSettingsInputDecoration("Minimal 6 karakter", Icons.lock_open_rounded),
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Wajib diisi";
                        if (v.length < 6) return "Sandi minimal 6 karakter";
                        return null;
                      },
                    ),
                    gapH16,

                    const Text("Konfirmasi Sandi Baru", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkGrey)),
                    gapH8,
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      style: const TextStyle(fontSize: 14, color: AppColors.darkGrey),
                      decoration: _buildSettingsInputDecoration("Ketik ulang sandi baru", Icons.verified_user_outlined),
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Wajib diisi";
                        if (v != _newPasswordController.text) return "Sandi baru tidak cocok";
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              gapH24,

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                ),
                onPressed: _isSaving ? null : _handleChangePassword,
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        "Simpan Kata Sandi",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 4. VERIFIKASI EMAIL PAGE
// -------------------------------------------------------------
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _isSent = false;
  bool _isLoading = false;
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Verifikasi Email", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkGrey,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
              ),
              child: Column(
                children: [
                  const Icon(Icons.mark_email_read_outlined, size: 64, color: AppColors.primaryGreen),
                  gapH16,
                  const Text(
                    "Verifikasi Alamat Email",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkGrey),
                  ),
                  gapH8,
                  const Text(
                    "Verifikasikan email Anda untuk mengaktifkan pemulihan akun otomatis.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                  ),
                  gapH24,
                  if (!_isSent) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              await Future.delayed(const Duration(seconds: 1)); // Mock email send
                              setState(() {
                                _isLoading = false;
                                _isSent = true;
                              });
                              if (mounted) {
                                ToastHelper.show(context, message: "Kode OTP dikirim ke email!");
                              }
                            },
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text("Kirim Kode Verifikasi", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ] else ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Masukkan Kode OTP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.darkGrey)),
                    ),
                    gapH8,
                    TextFormField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold, color: AppColors.darkGrey),
                      decoration: _buildSettingsInputDecoration("XXXXXX", Icons.key_rounded),
                    ),
                    gapH16,
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () async {
                              if (_codeController.text.length != 6) {
                                ToastHelper.show(context, message: "OTP harus 6 digit", isError: true);
                                return;
                              }
                              setState(() => _isLoading = true);
                              await Future.delayed(const Duration(seconds: 1)); // Mock verify
                              if (mounted) {
                                Navigator.pop(context);
                                ToastHelper.show(context, message: "Email sukses terverifikasi!");
                              }
                            },
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text("Verifikasi Sekarang", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 5. KETENTUAN LAYANAN PAGE
// -------------------------------------------------------------
class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Ketentuan Layanan", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkGrey,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Pemberitahuan Terakhir: Juni 2026",
                style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
              ),
              gapH16,
              const Text(
                "1. Akseptasi Ketentuan",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkGrey, fontFamily: 'Poppins'),
              ),
              gapH8,
              const Text(
                "Dengan mengakses dan menggunakan aplikasi mitra pengantar Apotek K-24, Anda menyatakan setuju untuk terikat dengan seluruh syarat dan ketentuan operasional yang berlaku.",
                style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
              ),
              gapH16,
              const Text(
                "2. Kewajiban Driver & Pengantar",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkGrey, fontFamily: 'Poppins'),
              ),
              gapH8,
              const Text(
                "Mitra berkewajiban menjaga kerahasiaan data resep obat pelanggan, mengantar produk medis dalam kondisi tersegel rapat, serta mematuhi protokol higienitas yang ketat sepanjang proses pengantaran.",
                style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
              ),
              gapH16,
              const Text(
                "3. Keamanan Biometrik Wajah",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkGrey, fontFamily: 'Poppins'),
              ),
              gapH8,
              const Text(
                "Verifikasi biometrik wajah digunakan untuk memastikan bahwa hanya pemilik akun sah yang dapat melakukan login dan memproses pengiriman obat-obatan sensitif. Penyalahgunaan akses biometrik akan berakibat pembekuan akun seketika.",
                style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 6. KEBIJAKAN PRIVASI PAGE
// -------------------------------------------------------------
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Kebijakan Privasi", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkGrey,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Pemberitahuan Terakhir: Juni 2026",
                style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
              ),
              gapH16,
              const Text(
                "1. Data Biometrik Wajah",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkGrey, fontFamily: 'Poppins'),
              ),
              gapH8,
              const Text(
                "Kami memproses data biometrik wajah Anda (face template) untuk tujuan keamanan login biometrik. Data ini disimpan dalam database terenkripsi di server pusat backend kami dan tidak pernah dibagikan kepada pihak ketiga manapun.",
                style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
              ),
              gapH16,
              const Text(
                "2. Riwayat Lokasi & GPS",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkGrey, fontFamily: 'Poppins'),
              ),
              gapH8,
              const Text(
                "Aplikasi ini mengumpulkan data lokasi real-time dari driver selama pengiriman obat aktif untuk keperluan tracking pesanan oleh konsumen dan sistem administrasi apotek.",
                style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
              ),
              gapH16,
              const Text(
                "3. Kontak & Enkripsi Data",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkGrey, fontFamily: 'Poppins'),
              ),
              gapH8,
              const Text(
                "Seluruh informasi profil, email, dan nomor telepon dilindungi oleh protokol keamanan SSL dan sistem enkripsi JWT standar industri untuk mencegah kebocoran data.",
                style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 7. AKTIVITAS AKUN PAGE
// -------------------------------------------------------------
class AccountActivityPage extends StatelessWidget {
  const AccountActivityPage({super.key});

  Widget _buildActivityRow({
    required IconData icon,
    required String title,
    required String desc,
    required String time,
    required String ip,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Color(0xFFF5F6F9),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primaryGreen, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkGrey),
              ),
              gapH2,
              Text(
                desc,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              gapH4,
              Row(
                children: [
                  Text(
                    time,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "IP: $ip",
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Aktivitas Akun", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkGrey,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildActivityRow(
                icon: Icons.login_rounded,
                title: "Login Akun Berhasil",
                desc: "Login terdeteksi di perangkat macOS Intel",
                time: "Hari ini, 19:42 WIB",
                ip: "182.253.140.23",
              ),
              const Divider(height: 24, color: Color(0xFFEDF2F7)),
              _buildActivityRow(
                icon: Icons.security_rounded,
                title: "Verifikasi Wajah Digunakan",
                desc: "Autentikasi login biometrik sukses",
                time: "Kemarin, 08:30 WIB",
                ip: "182.253.140.23",
              ),
              const Divider(height: 24, color: Color(0xFFEDF2F7)),
              _buildActivityRow(
                icon: Icons.password_rounded,
                title: "Perubahan Kata Sandi",
                desc: "Keamanan sandi diubah melalui sistem profil",
                time: "24 Juni 2026, 14:15 WIB",
                ip: "114.124.200.82",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 8. IMAGE CROP SCREEN
// -------------------------------------------------------------
class ImageCropScreen extends StatefulWidget {
  final String imagePath;
  final bool isAsset;

  const ImageCropScreen({
    super.key,
    required this.imagePath,
    this.isAsset = true,
  });

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  double _zoom = 1.0;
  double _rotation = 0.0;
  final TransformationController _transformationController = TransformationController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Pangkas Foto", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Interactive viewer to pan and pinch zoom
                InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: RotationTransition(
                    turns: AlwaysStoppedAnimation(_rotation / 360),
                    child: widget.isAsset
                        ? Image.asset(widget.imagePath, fit: BoxFit.contain)
                        : (kIsWeb
                            ? Image.network(widget.imagePath, fit: BoxFit.contain)
                            : Image.file(File(widget.imagePath), fit: BoxFit.contain)),
                  ),
                ),
                
                // Circle Mask Overlay
                IgnorePointer(
                  child: Stack(
                    children: [
                      ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.7),
                          BlendMode.srcOut,
                        ),
                        child: Stack(
                          children: [
                            Container(
                              color: Colors.transparent,
                            ),
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                width: 250,
                                height: 250,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Control panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            color: Colors.grey.shade900,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.rotate_left_rounded, color: Colors.white),
                      onPressed: () => setState(() => _rotation -= 90),
                    ),
                    IconButton(
                      icon: const Icon(Icons.rotate_right_rounded, color: Colors.white),
                      onPressed: () => setState(() => _rotation += 90),
                    ),
                    IconButton(
                      icon: const Icon(Icons.zoom_out_rounded, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _zoom = (_zoom - 0.2).clamp(0.5, 4.0);
                          _transformationController.value = Matrix4.identity()..scale(_zoom);
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.zoom_in_rounded, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _zoom = (_zoom + 0.2).clamp(0.5, 4.0);
                          _transformationController.value = Matrix4.identity()..scale(_zoom);
                        });
                      },
                    ),
                  ],
                ),
                gapH16,
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Batal"),
                      ),
                    ),
                    gapW16,
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        onPressed: () async {
                          if (widget.isAsset) {
                            Navigator.pop(context, widget.imagePath);
                          } else {
                            try {
                              final File file = File(widget.imagePath);
                              if (await file.exists()) {
                                final bytes = await file.readAsBytes();
                                final base64Str = base64Encode(bytes);
                                final dataUri = 'data:image/jpeg;base64,$base64Str';
                                if (context.mounted) {
                                  Navigator.pop(context, dataUri);
                                }
                              } else {
                                Navigator.pop(context, widget.imagePath);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ToastHelper.show(context, message: "Gagal menyimpan foto: $e", isError: true);
                              }
                            }
                          }
                        },
                        child: const Text("Potong & Simpan", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// 9. MOCK GALLERY PICKER SCREEN
// -------------------------------------------------------------
class MockGalleryPickerScreen extends StatelessWidget {
  const MockGalleryPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> mockPhotos = [
      'assets/images/asset-login-hero-banner-k24.png',
      'assets/images/banner2.png',
      'assets/images/banner3.png',
      'assets/images/banner4.png',
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Pilih dari Galeri", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkGrey,
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: mockPhotos.length,
        itemBuilder: (context, index) {
          final path = mockPhotos[index];
          return GestureDetector(
            onTap: () async {
              final cropped = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageCropScreen(imagePath: path, isAsset: true),
                ),
              );
              if (cropped != null && context.mounted) {
                Navigator.pop(context, cropped);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(path, fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }
}

// -------------------------------------------------------------
// 10. MOCK CAMERA PICKER SCREEN
// -------------------------------------------------------------
class MockCameraPickerScreen extends StatefulWidget {
  const MockCameraPickerScreen({super.key});

  @override
  State<MockCameraPickerScreen> createState() => _MockCameraPickerScreenState();
}

class _MockCameraPickerScreenState extends State<MockCameraPickerScreen> {
  @override
  Widget build(BuildContext context) {
    const mockCameraPath = 'assets/images/banner2.png';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(mockCameraPath, fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              ),
              child: GridPaper(
                color: Colors.white.withOpacity(0.1),
                divisions: 2,
                subdivisions: 1,
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text("Simulasi Bidik Kamera", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                gapH16,
                GestureDetector(
                  onTap: () async {
                    final cropped = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ImageCropScreen(imagePath: mockCameraPath, isAsset: true),
                      ),
                    );
                    if (cropped != null && mounted) {
                      Navigator.pop(context, cropped);
                    }
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade400, width: 4),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
