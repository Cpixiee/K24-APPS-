import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:apps_k24/theme/gaps.dart';
import 'package:apps_k24/pages/login_screen.dart';
import 'package:apps_k24/services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _plateController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  int _currentStep = 1; // 1, 2, or 3
  String _selectedVehicleType = 'motor';
  String? _ktpBase64;
  String? _simBase64;
  String? _stnkBase64;
  String? _ktpFileName;
  String? _simFileName;
  String? _stnkFileName;

  // Premium design colors (White & Yellow theme)
  static const Color primaryYellow = Color(0xFFFFB300); // Warm Gold/Amber
  static const Color accentYellow = Color(0xFFFFD54F);  // Soft Yellow
  static const Color darkSlate = Color(0xFF1E2022);     // Deep text color
  static const Color inputBg = Color(0xFFF9FAFB);       // Crisp grey-white input fill

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _plateController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _pickImage(String type) async {
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      setState(() {
        if (type == 'ktp') {
          _ktpBase64 = base64Str;
          _ktpFileName = file.name;
        } else if (type == 'sim') {
          _simBase64 = base64Str;
          _simFileName = file.name;
        } else if (type == 'stnk') {
          _stnkBase64 = base64Str;
          _stnkFileName = file.name;
        }
      });
    } catch (e) {
      _showError('Gagal memilih file: $e');
    }
  }

  void _handleNext() {
    if (!_formKey.currentState!.validate()) return;

    if (_currentStep == 1) {
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      _handleRegister();
    }
  }

  Future<void> _handleRegister() async {
    if (_ktpBase64 == null || _simBase64 == null || _stnkBase64 == null) {
      _showError('Dokumen KTP, SIM, dan STNK wajib diunggah.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        plateNumber: _plateController.text.trim(),
        password: _passwordController.text,
        vehicleType: _selectedVehicleType,
        ktpUrl: _ktpBase64!,
        simUrl: _simBase64!,
        stnkUrl: _stnkBase64!,
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text(
              'Pendaftaran Berhasil',
              style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: darkSlate),
            ),
            content: const Text(
              'Akun driver Anda telah didaftarkan dan sedang menunggu proses approval berkas oleh Admin. Anda akan bisa masuk setelah disetujui.',
              style: TextStyle(fontFamily: 'Poppins', height: 1.4, fontSize: 13.5),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryYellow,
                  foregroundColor: darkSlate,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStepIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _buildStepDot(1, 'Identitas'),
          _buildStepLine(1),
          _buildStepDot(2, 'Kendaraan'),
          _buildStepLine(2),
          _buildStepDot(3, 'Berkas'),
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, String label) {
    bool isCompleted = _currentStep > step;
    bool isCurrent = _currentStep == step;
    
    return Expanded(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrent
                  ? primaryYellow
                  : (isCompleted ? darkSlate : Colors.grey.shade100),
              border: Border.all(
                color: isCurrent || isCompleted ? Colors.transparent : Colors.grey.shade300,
                width: 1.5,
              ),
              boxShadow: isCurrent ? [
                BoxShadow(
                  color: primaryYellow.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ] : null,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                  : Text(
                      '$step',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isCurrent ? darkSlate : (isCompleted ? Colors.white : Colors.grey.shade500),
                        fontFamily: 'Poppins',
                      ),
                    ),
            ),
          ),
          gapH8,
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
              color: isCurrent ? primaryYellow : (isCompleted ? darkSlate : Colors.grey.shade400),
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(int step) {
    bool isCompleted = _currentStep > step;
    return Container(
      width: 40,
      height: 3,
      decoration: BoxDecoration(
        color: isCompleted ? darkSlate : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(1.5),
      ),
      margin: const EdgeInsets.only(bottom: 20),
    );
  }

  Widget _buildDocUploadCard({
    required String title,
    required String? fileName,
    required VoidCallback onTap,
  }) {
    final bool isUploaded = fileName != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(
                color: isUploaded ? primaryYellow.withValues(alpha: 0.4) : Colors.grey.shade200,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                // Upload status icon in circular wrapper
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isUploaded ? primaryYellow.withValues(alpha: 0.12) : inputBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isUploaded ? Icons.done_all_rounded : Icons.camera_alt_outlined,
                    color: isUploaded ? primaryYellow : Colors.grey.shade500,
                    size: 20,
                  ),
                ),
                gapW16,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          color: darkSlate,
                        ),
                      ),
                      gapH4,
                      Text(
                        fileName ?? 'Ketuk untuk mengambil foto berkas',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isUploaded ? primaryYellow : Colors.grey.shade500,
                          fontWeight: isUploaded ? FontWeight.w600 : FontWeight.normal,
                          fontFamily: 'Poppins',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: inputBg,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkSlate, size: 18),
            onPressed: () {
              if (_currentStep > 1) {
                setState(() {
                  _currentStep--;
                });
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Daftar Driver",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                    color: darkSlate,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Bergabung menjadi mitra driver apotek K-24 dan dapatkan penghasilan tambahan",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontFamily: 'Poppins',
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 28),

                // Stepper Indicator
                _buildStepIndicator(),

                // Wrapping content inside white premium container card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade100, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // STEP 1: Identitas Diri
                      if (_currentStep == 1) ...[
                        // Name Field
                        const Text(
                          "Nama Lengkap",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                            color: darkSlate,
                          ),
                        ),
                        gapH8,
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: "Masukkan nama lengkap Anda",
                            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                            filled: true,
                            fillColor: inputBg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade100, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: primaryYellow, width: 2.0),
                            ),
                            prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.grey, size: 20),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nama lengkap wajib diisi';
                            }
                            return null;
                          },
                        ),
                        gapH16,

                        // Email Field
                        const Text(
                          "Email",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                            color: darkSlate,
                          ),
                        ),
                        gapH8,
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: "Masukkan alamat email Anda",
                            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                            filled: true,
                            fillColor: inputBg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade100, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: primaryYellow, width: 2.0),
                            ),
                            prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey, size: 20),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email wajib diisi';
                            }
                            final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                            if (!emailRegex.hasMatch(value)) {
                              return 'Format email tidak valid';
                            }
                            return null;
                          },
                        ),
                        gapH16,

                        // Phone Field
                        const Text(
                          "Nomor HP / WhatsApp",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                            color: darkSlate,
                          ),
                        ),
                        gapH8,
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: "Contoh: 08123456789",
                            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                            filled: true,
                            fillColor: inputBg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade100, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: primaryYellow, width: 2.0),
                            ),
                            prefixIcon: const Icon(Icons.phone_outlined, color: Colors.grey, size: 20),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nomor HP wajib diisi';
                            }
                            if (value.length < 9) {
                              return 'Nomor HP tidak valid';
                            }
                            return null;
                          },
                        ),
                      ],

                      // STEP 2: Kendaraan & Keamanan
                      if (_currentStep == 2) ...[
                        // Vehicle Type Selection (Interactive Cards instead of standard dropdown)
                        const Text(
                          "Tipe Kendaraan",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                            color: darkSlate,
                          ),
                        ),
                        gapH12,
                        Row(
                          children: [
                            // Motor Selection Card
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedVehicleType = 'motor';
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      color: _selectedVehicleType == 'motor' ? primaryYellow.withValues(alpha: 0.08) : inputBg,
                                      border: Border.all(
                                        color: _selectedVehicleType == 'motor' ? primaryYellow : Colors.grey.shade200,
                                        width: 1.8,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.two_wheeler_rounded,
                                          size: 32,
                                          color: _selectedVehicleType == 'motor' ? primaryYellow : Colors.grey,
                                        ),
                                        gapH8,
                                        Text(
                                          "Sepeda Motor",
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Poppins',
                                            color: _selectedVehicleType == 'motor' ? darkSlate : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            gapW16,
                            // Mobil Selection Card
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedVehicleType = 'mobil';
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      color: _selectedVehicleType == 'mobil' ? primaryYellow.withValues(alpha: 0.08) : inputBg,
                                      border: Border.all(
                                        color: _selectedVehicleType == 'mobil' ? primaryYellow : Colors.grey.shade200,
                                        width: 1.8,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.local_shipping_rounded,
                                          size: 32,
                                          color: _selectedVehicleType == 'mobil' ? primaryYellow : Colors.grey,
                                        ),
                                        gapH8,
                                        Text(
                                          "Mobil Box / MPV",
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Poppins',
                                            color: _selectedVehicleType == 'mobil' ? darkSlate : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        gapH20,

                        // Vehicle Plate Input
                        const Text(
                          "Nomor Pelat Kendaraan",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                            color: darkSlate,
                          ),
                        ),
                        gapH8,
                        TextFormField(
                          controller: _plateController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: "Contoh: AB 1234 CD",
                            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                            filled: true,
                            fillColor: inputBg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade100, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: primaryYellow, width: 2.0),
                            ),
                            prefixIcon: Icon(
                              _selectedVehicleType == 'motor' ? Icons.two_wheeler_rounded : Icons.local_shipping_rounded,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nomor pelat kendaraan wajib diisi';
                            }
                            return null;
                          },
                        ),
                        gapH20,

                        // Password Field
                        const Text(
                          "Kata Sandi",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                            color: darkSlate,
                          ),
                        ),
                        gapH8,
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: "Buat kata sandi minimal 6 karakter",
                            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                            filled: true,
                            fillColor: inputBg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade100, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: primaryYellow, width: 2.0),
                            ),
                            prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.grey, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.grey,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Kata sandi wajib diisi';
                            }
                            if (value.length < 6) {
                              return 'Kata sandi minimal 6 karakter';
                            }
                            return null;
                          },
                        ),
                      ],

                      // STEP 3: Upload Berkas
                      if (_currentStep == 3) ...[
                        const Text(
                          "Unggah Berkas Pendukung",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                            color: darkSlate,
                          ),
                        ),
                        gapH4,
                        const Text(
                          "Unggah foto asli dokumen persyaratan Anda:",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        gapH16,
                        _buildDocUploadCard(
                          title: 'Foto KTP Asli',
                          fileName: _ktpFileName,
                          onTap: () => _pickImage('ktp'),
                        ),
                        _buildDocUploadCard(
                          title: 'Foto SIM Aktif',
                          fileName: _simFileName,
                          onTap: () => _pickImage('sim'),
                        ),
                        _buildDocUploadCard(
                          title: 'Foto STNK Kendaraan',
                          fileName: _stnkFileName,
                          onTap: () => _pickImage('stnk'),
                        ),
                      ],
                    ],
                  ),
                ),
                gapH32,

                // Dynamic Navigation Action Buttons
                Row(
                  children: [
                    if (_currentStep > 1) ...[
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: darkSlate,
                            side: const BorderSide(color: primaryYellow, width: 1.5),
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            backgroundColor: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _currentStep--;
                            });
                          },
                          child: const Text(
                            "Kembali",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                      gapW16,
                    ],
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: const LinearGradient(
                            colors: [accentYellow, primaryYellow],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryYellow.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: darkSlate,
                            shadowColor: Colors.transparent,
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _isLoading ? null : _handleNext,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: darkSlate,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  _currentStep == 3 ? "Kirim Berkas" : "Lanjutkan",
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                gapH32,
                
                // Footer link back to Login Screen
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Sudah memiliki akun? ",
                      style: TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'Poppins'),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                      child: const Text(
                        "Masuk",
                        style: TextStyle(
                          color: primaryYellow,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
