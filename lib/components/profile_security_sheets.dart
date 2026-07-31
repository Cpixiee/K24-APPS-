import 'dart:async';
import 'package:flutter/material.dart';
import 'package:apps_k24/theme/app_colors.dart';
import 'package:apps_k24/theme/gaps.dart';
import 'package:apps_k24/services/api_service.dart';
import 'package:apps_k24/components/toast_helper.dart';

class ProfileSecuritySheets {
  // -------------------------------------------------------------
  // 1. KETENTUAN LAYANAN SHEET
  // -------------------------------------------------------------
  static void showTerms(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  gapH20,
                  const Text(
                    "Ketentuan Layanan",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGrey,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  gapH12,
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: const [
                        Text(
                          "Pemberitahuan Terakhir: Juni 2026",
                          style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                        gapH16,
                        Text(
                          "1. Akseptasi Ketentuan",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkGrey),
                        ),
                        gapH4,
                        Text(
                          "Dengan mengakses dan menggunakan aplikasi mitra pengantar Apotek K-24, Anda menyatakan setuju untuk terikat dengan seluruh syarat dan ketentuan operasional yang berlaku.",
                          style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
                        ),
                        gapH16,
                        Text(
                          "2. Kewajiban Driver & Pengantar",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkGrey),
                        ),
                        gapH4,
                        Text(
                          "Mitra berkewajiban menjaga kerahasiaan data resep obat pelanggan, mengantar produk medis dalam kondisi tersegel rapat, serta mematuhi protokol higienitas yang ketat sepanjang proses pengantaran.",
                          style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
                        ),
                        gapH16,
                        Text(
                          "3. Keamanan Biometrik Wajah",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkGrey),
                        ),
                        gapH4,
                        Text(
                          "Verifikasi biometrik wajah digunakan untuk memastikan bahwa hanya pemilik akun sah yang dapat melakukan login dan memproses pengiriman obat-obatan sensitif. Penyalahgunaan akses biometrik akan berakibat pembekuan akun seketika.",
                          style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
                        ),
                        gapH24,
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // 2. KEBIJAKAN PRIVASI SHEET
  // -------------------------------------------------------------
  static void showPrivacy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  gapH20,
                  const Text(
                    "Kebijakan Privasi",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGrey,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  gapH12,
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: const [
                        Text(
                          "Pemberitahuan Terakhir: Juni 2026",
                          style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                        gapH16,
                        Text(
                          "1. Data Biometrik Wajah",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkGrey),
                        ),
                        gapH4,
                        Text(
                          "Kami memproses data biometrik wajah Anda (face template) untuk tujuan keamanan login biometrik. Data ini disimpan dalam database terenkripsi di server pusat backend kami dan tidak pernah dibagikan kepada pihak ketiga manapun.",
                          style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
                        ),
                        gapH16,
                        Text(
                          "2. Riwayat Lokasi & GPS",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkGrey),
                        ),
                        gapH4,
                        Text(
                          "Aplikasi ini mengumpulkan data lokasi real-time dari driver selama pengiriman obat aktif untuk keperluan tracking pesanan oleh konsumen dan sistem administrasi apotek.",
                          style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
                        ),
                        gapH16,
                        Text(
                          "3. Kontak & Enkripsi Data",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkGrey),
                        ),
                        gapH4,
                        Text(
                          "Seluruh informasi profil, email, dan nomor telepon dilindungi oleh protokol keamanan SSL dan sistem enkripsi JWT standar industri untuk mencegah kebocoran data.",
                          style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
                        ),
                        gapH24,
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // 3. AKTIVITAS AKUN SHEET
  // -------------------------------------------------------------
  static void showActivity(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  gapH20,
                  const Text(
                    "Aktivitas Akun Terbaru",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGrey,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  gapH12,
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        _buildActivityItem(
                          icon: Icons.login_rounded,
                          title: "Login Akun Berhasil",
                          desc: "Login terdeteksi di perangkat macOS Intel",
                          time: "Hari ini, 19:42 WIB",
                          ip: "182.253.140.23",
                        ),
                        const Divider(height: 24),
                        _buildActivityItem(
                          icon: Icons.security_rounded,
                          title: "Verifikasi Wajah Digunakan",
                          desc: "Autentikasi login biometrik sukses",
                          time: "Kemarin, 08:30 WIB",
                          ip: "182.253.140.23",
                        ),
                        const Divider(height: 24),
                        _buildActivityItem(
                          icon: Icons.password_rounded,
                          title: "Perubahan Kata Sandi",
                          desc: "Keamanan sandi diubah melalui sistem profil",
                          time: "24 Juni 2026, 14:15 WIB",
                          ip: "114.124.200.82",
                        ),
                        gapH16,
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildActivityItem({
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
          decoration: BoxDecoration(
            color: AppColors.lightGrey,
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

  // -------------------------------------------------------------
  // 4. KEAMANAN AKUN MENU (Ganti Password, Verifikasi Email, Wajah)
  // -------------------------------------------------------------
  static void showSecurityMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              gapH20,
              const Text(
                "Keamanan Akun",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGrey,
                  fontFamily: 'Poppins',
                ),
              ),
              gapH16,
              
              // Ganti Password Tile
              _buildSecurityOption(
                context,
                icon: Icons.lock_outline_rounded,
                title: "Ganti Kata Sandi",
                subtitle: "Ubah kata sandi secara berkala untuk menjaga akun",
                onTap: () {
                  Navigator.pop(context); // Close sheet
                  _showChangePasswordSheet(context);
                },
              ),
              const Divider(height: 12),
              
              // Verifikasi Email Tile
              _buildSecurityOption(
                context,
                icon: Icons.email_outlined,
                title: "Verifikasi Alamat Email",
                subtitle: "Pastikan email Anda aktif untuk notifikasi keamanan",
                onTap: () {
                  Navigator.pop(context);
                  _showVerifyEmailSheet(context);
                },
              ),
              const Divider(height: 12),
              
              // Verifikasi Wajah Tile (FACE BIOMETRICS)
              _buildSecurityOption(
                context,
                icon: Icons.face_retouching_natural_rounded,
                title: "Verifikasi Wajah Biometrik",
                subtitle: "Simpan data wajah di backend untuk login instan & aman",
                onTap: () {
                  Navigator.pop(context);
                  _showFaceVerificationSheet(context);
                },
              ),
              gapH24,
            ],
          ),
        );
      },
    );
  }

  static Widget _buildSecurityOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primaryGreen, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkGrey, fontFamily: 'Poppins'),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 10.5, color: Colors.grey),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18),
      onTap: onTap,
    );
  }

  // -------------------------------------------------------------
  // SUB-SHEET: GANTI PASSWORD FORM
  // -------------------------------------------------------------
  static void _showChangePasswordSheet(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    gapH20,
                    const Text(
                      "Ganti Kata Sandi",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGrey,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    gapH16,
                    
                    // Old Password
                    const Text("Sandi Lama", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    gapH8,
                    TextFormField(
                      controller: oldPasswordController,
                      obscureText: true,
                      decoration: _buildInputDecoration("Masukkan sandi lama Anda"),
                      validator: (v) => v == null || v.isEmpty ? "Wajib diisi" : null,
                    ),
                    gapH12,
                    
                    // New Password
                    const Text("Sandi Baru", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    gapH8,
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: _buildInputDecoration("Minimal 6 karakter"),
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Wajib diisi";
                        if (v.length < 6) return "Sandi minimal 6 karakter";
                        return null;
                      },
                    ),
                    gapH12,

                    // Confirm New Password
                    const Text("Konfirmasi Sandi Baru", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    gapH8,
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: _buildInputDecoration("Ketik ulang sandi baru"),
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Wajib diisi";
                        if (v != newPasswordController.text) return "Sandi baru tidak cocok";
                        return null;
                      },
                    ),
                    gapH24,

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setState(() => isLoading = true);
                              try {
                                await ApiService.changePassword(
                                  oldPassword: oldPasswordController.text,
                                  newPassword: newPasswordController.text,
                                );
                                if (context.mounted) {
                                  Navigator.pop(context); // Close sheet
                                  ToastHelper.show(context, message: "Kata sandi sukses diperbarui!");
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ToastHelper.show(context, message: e.toString(), isError: true);
                                }
                              } finally {
                                setState(() => isLoading = false);
                              }
                            },
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text("Simpan Sandi Baru", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // SUB-SHEET: VERIFIKASI EMAIL
  // -------------------------------------------------------------
  static void _showVerifyEmailSheet(BuildContext context) {
    bool isSent = false;
    bool isLoading = false;
    final codeController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  gapH20,
                  const Text(
                    "Verifikasi Alamat Email",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGrey,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  gapH12,
                  const Text(
                    "Verifikasi alamat email Anda untuk pemulihan akun otomatis jika Anda lupa kata sandi.",
                    style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
                  ),
                  gapH16,
                  
                  if (!isSent) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              setState(() => isLoading = true);
                              await Future.delayed(const Duration(seconds: 1)); // Mock email send
                              setState(() {
                                isLoading = false;
                                isSent = true;
                              });
                              if (context.mounted) {
                                ToastHelper.show(context, message: "Kode OTP dikirim ke email!");
                              }
                            },
                      icon: isLoading 
                          ? Container()
                          : const Icon(Icons.send_rounded, size: 18),
                      label: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text("Kirim Kode Verifikasi", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ] else ...[
                    const Text("Masukkan Kode OTP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    gapH8,
                    TextFormField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold),
                      decoration: _buildInputDecoration("XXXXXX"),
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
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (codeController.text.length != 6) {
                                ToastHelper.show(context, message: "OTP harus 6 digit", isError: true);
                                return;
                              }
                              setState(() => isLoading = true);
                              await Future.delayed(const Duration(seconds: 1)); // Mock verify
                              if (context.mounted) {
                                Navigator.pop(context);
                                ToastHelper.show(context, message: "Email sukses terverifikasi!");
                              }
                            },
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text("Verifikasi Sekarang", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                  gapH12,
                ],
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // SUB-SHEET: FACE VERIFICATION (BIOMETRICS SCANNER MOCK)
  // -------------------------------------------------------------
  static void _showFaceVerificationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              gapH20,
              const Text(
                "Autentikasi Wajah Biometrik",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGrey,
                  fontFamily: 'Poppins',
                ),
              ),
              gapH12,
              const Text(
                "Daftarkan data wajah Anda untuk mempermudah login biometrik tanpa mengetik kata sandi di lain waktu.",
                style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
              ),
              gapH20,

              // Camera Icon Preview Mock
              Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3), width: 3),
                  ),
                  child: const Icon(
                    Icons.face_retouching_natural_rounded,
                    color: AppColors.primaryGreen,
                    size: 64,
                  ),
                ),
              ),
              gapH24,

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: () {
                  Navigator.pop(context); // Close sheet
                  // Navigate to Face Capture simulation screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MockFaceCameraScreen(isRegisterMode: true),
                    ),
                  );
                },
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text("Mulai Pemindaian Wajah", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              gapH12,
            ],
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------
  static InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
      filled: true,
      fillColor: AppColors.lightGrey,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}

// -------------------------------------------------------------
// 5. MOCK FACE CAMERA SCANNER COMPONENT (Interactive Simulation)
// -------------------------------------------------------------
class MockFaceCameraScreen extends StatefulWidget {
  final bool isRegisterMode;
  final String? usernameForLogin;

  const MockFaceCameraScreen({
    super.key,
    required this.isRegisterMode,
    this.usernameForLogin,
  });

  @override
  State<MockFaceCameraScreen> createState() => _MockFaceCameraScreenState();
}

class _MockFaceCameraScreenState extends State<MockFaceCameraScreen> with SingleTickerProviderStateMixin {
  late AnimationController _scannerController;
  late Animation<double> _scannerAnimation;
  bool _isProcessing = false;
  String _scanningText = "Posisikan wajah Anda di dalam lingkaran";

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scannerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scannerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _processFaceScan(bool isFaceValid) async {
    setState(() {
      _isProcessing = true;
      _scanningText = "Menganalisis fitur wajah...";
    });

    // Simulated scanning time
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    if (widget.isRegisterMode) {
      // REGISTRATION MODE
      try {
        final faceSig = isFaceValid ? "face_valid_sig" : "face_invalid_sig";
        await ApiService.registerFace(faceSig);

        if (mounted) {
          Navigator.pop(context); // Exit camera screen
          ToastHelper.show(context, message: "Data wajah sukses tersimpan di database!");
        }
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _scanningText = "Pendaftaran wajah gagal. Coba lagi.";
        });
        ToastHelper.show(context, message: e.toString(), isError: true);
      }
    } else {
      // LOGIN MODE
      if (widget.usernameForLogin == null) return;
      try {
        final faceSig = isFaceValid ? "face_valid_sig" : "face_invalid_sig";
        await ApiService.loginWithFace(
          username: widget.usernameForLogin!,
          faceData: faceSig,
        );

        if (mounted) {
          // Push appropriate logged in route
          final role = await ApiService.getRole();
          if (!mounted) return;
          
          Navigator.pop(context); // Close camera screen
          
          // Switch to dashboard depending on role
          // Since the screen pushing logic is in login_screen, we use pop with true or push replacement
          Navigator.pop(context, true); // Return success flag to login screen to handle navigation
        }
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _scanningText = "Wajah tidak dikenali. Silakan coba lagi.";
        });
        ToastHelper.show(context, message: e.toString(), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Stack(
          children: [
            // Dark Camera Backdrop Mock
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.85),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white24,
                  size: 280,
                ),
              ),
            ),

            // Top Guidance
            Positioned(
              top: 24,
              left: 24,
              right: 24,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        widget.isRegisterMode ? "Pendaftaran Wajah" : "Login Verifikasi Wajah",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(width: 48), // Spacer
                    ],
                  ),
                  gapH24,
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _scanningText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            // Scanning Ring & Beam Animation overlay
            Center(
              child: SizedBox(
                width: 250,
                height: 250,
                child: Stack(
                  children: [
                    // Green Glowing Circular scanner frame
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isProcessing ? Colors.blueAccent : AppColors.primaryGreen,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isProcessing ? Colors.blueAccent : AppColors.primaryGreen).withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                    ),

                    // Laser Scanning Bar
                    if (!_isProcessing)
                      AnimatedBuilder(
                        animation: _scannerAnimation,
                        builder: (context, child) {
                          final topOffset = _scannerAnimation.value * 230 + 10;
                          return Positioned(
                            top: topOffset,
                            left: 20,
                            right: 20,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryGreen.withOpacity(0.8),
                                    blurRadius: 8,
                                    spreadRadius: 1.5,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    else
                      const Center(
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: CircularProgressIndicator(
                            color: Colors.blueAccent,
                            strokeWidth: 4,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom Buttons (Simulate Valid / Invalid face input)
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "SIMULASI VERIFIKASI WAJAH",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white30,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  gapH16,
                  Row(
                    children: [
                      // Choice 1: Valid Match (Success)
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _isProcessing ? null : () => _processFaceScan(true),
                          icon: const Icon(Icons.face_rounded),
                          label: const Text(
                            "Wajah Valid",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Choice 2: Mismatch (Fail)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent, width: 1.5),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _isProcessing ? null : () => _processFaceScan(false),
                          icon: const Icon(Icons.face_unlock_outlined),
                          label: const Text(
                            "Wajah Orang Lain",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
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
