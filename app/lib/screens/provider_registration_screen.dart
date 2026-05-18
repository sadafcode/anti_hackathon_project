import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pinput/pinput.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/phone_auth_service.dart';
import '../services/provider_session.dart';
import 'nic_scanner_screen.dart';

class ProviderRegistrationScreen extends StatefulWidget {
  const ProviderRegistrationScreen({super.key});

  @override
  State<ProviderRegistrationScreen> createState() =>
      _ProviderRegistrationScreenState();
}

class _ProviderRegistrationScreenState
    extends State<ProviderRegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nicCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _rateBasicCtrl = TextEditingController();
  final _rateIntermediateCtrl = TextEditingController();
  final _rateComplexCtrl = TextEditingController();
  final _certCtrl = TextEditingController();

  // State
  File? _pickedPhoto;
  Uint8List? _pickedBytes; // for web (Image.file not supported on web)
  bool _useAvatar = false;
  final ImagePicker _picker = ImagePicker();

  // Avatar colors pool
  static const List<Color> _avatarColors = [
    Color(0xFF1D9E75), Color(0xFF2196F3), Color(0xFF9C27B0),
    Color(0xFFFF5722), Color(0xFF009688), Color(0xFF3F51B5),
  ];

  Color get _avatarColor {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return _avatarColors[0];
    return _avatarColors[name.codeUnitAt(0) % _avatarColors.length];
  }

  String get _initials {
    final parts = _nameCtrl.text.trim().split(' ')
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  String? _selectedArea;
  final Set<String> _selectedServices = {};
  final Set<String> _selectedTools = {};
  final Map<String, Set<String>> _availability = {};
  bool _submitting = false;
  bool _submitted = false;
  bool _nadraVerified = false;
  String _registeredProviderId = '';

  // Phone OTP state
  bool _phoneVerified = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;

  // NIC verification state
  bool _nicVerified = false;
  bool _verifyingNic = false;
  String? _nicMismatchMsg;

  late AnimationController _successController;
  late Animation<double> _successScale;

  static const List<String> _serviceTypes = [
    'Plumber',
    'Electrician',
    'AC Tech',
    'Tutor',
    'Carpenter',
    'Beautician',
    'Driver',
    'Mechanic',
  ];

  static const Map<String, List<String>> _pakistanAreas = {
    'Lahore': ['Gulberg', 'DHA Lahore Phase 1', 'DHA Lahore Phase 2', 'DHA Lahore Phase 5', 'DHA Lahore Phase 6', 'Model Town', 'Johar Town', 'Bahria Town Lahore', 'Cantt Lahore', 'Garden Town', 'Iqbal Town', 'Shadman', 'Wapda Town', 'Township', 'Faisal Town', 'Cavalry Ground', 'Allama Iqbal Town', 'Samanabad'],
    'Karachi': ['DHA Karachi', 'Clifton', 'Gulshan-e-Iqbal', 'North Nazimabad', 'Gulistan-e-Jauhar', 'Malir', 'Korangi', 'PECHS', 'Liaquatabad', 'Orangi Town', 'Saddar Karachi', 'Bahria Town Karachi', 'Nazimabad', 'Federal B Area', 'Landhi'],
    'Islamabad': ['F-6', 'F-7', 'F-8', 'F-10', 'F-11', 'G-6', 'G-7', 'G-8', 'G-9', 'G-10', 'G-11', 'G-13', 'I-8', 'I-9', 'I-10', 'E-7', 'E-11', 'DHA Islamabad', 'Bahria Town Islamabad', 'PWD', 'Gulberg Islamabad'],
    'Rawalpindi': ['Satellite Town Rawalpindi', 'Chaklala', 'Cantt Rawalpindi', 'Bahria Town Rawalpindi', 'DHA Rawalpindi', 'Sadiqabad', 'Westridge', 'Saddar Rawalpindi', 'Lalazar'],
    'Faisalabad': ['Peoples Colony', 'Jinnah Colony', 'Millat Town', 'Gulberg Faisalabad', 'Madina Town', 'Susan Road'],
    'Multan': ['Cantt Multan', 'Gulgasht Colony', 'New Multan', 'Shah Rukn-e-Alam', 'Bosan Road'],
    'Peshawar': ['Hayatabad', 'University Town', 'Cantt Peshawar', 'Saddar Peshawar', 'Ring Road Peshawar', 'Gulbahar'],
    'Quetta': ['Satellite Town Quetta', 'Cantt Quetta', 'Jinnah Town', 'Airport Road Quetta', 'Zarghoon Road'],
    'Hyderabad': ['Latifabad', 'Qasimabad', 'Hirabad', 'Cantt Hyderabad'],
    'Gujranwala': ['G.T Road Gujranwala', 'Model Town Gujranwala', 'Peoples Colony Gujranwala'],
    'Sialkot': ['Cantt Sialkot', 'Paris Road', 'Allama Iqbal Road'],
    'Abbottabad': ['Cantt Abbottabad', 'Mandian', 'Havelian Road', 'PMA Road'],
    'Gujrat': ['Cantt Gujrat', 'Model Town Gujrat'],
    'Bahawalpur': ['Model Town Bahawalpur', 'Satellite Town Bahawalpur'],
    'Sargodha': ['University Road Sargodha', 'Satellite Town Sargodha'],
    'Sukkur': ['Airport Road Sukkur', 'Rohri'],
    'Larkana': ['Cantt Larkana', 'Larkana City'],
    'Mardan': ['Cantt Mardan', 'Mardan City'],
    'Mingora': ['Swat', 'Mingora City'],
    'Dera Ghazi Khan': ['Cantt DG Khan', 'DG Khan City'],
    'Sahiwal': ['Sahiwal City', 'Chichawatni'],
    'Sheikhupura': ['Sheikhupura City', 'Muridke'],
    'Rahim Yar Khan': ['RYK City', 'Liaquatpur'],
  };

  static const List<String> _toolOptions = [
    'Multimeter', 'Drill', 'Gas Kit', 'Pipe Wrench',
    'Soldering Iron', 'Voltage Tester', 'Ladder',
    'Tool Box', 'Welding Machine', 'Air Pump',
  ];

  static const List<String> _weekDays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  static const List<String> _timeSlots = [
    '8am–12pm', '12pm–4pm', '4pm–8pm', 'Evening',
  ];

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _successScale = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _nicCtrl.dispose();
    _expCtrl.dispose();
    _rateBasicCtrl.dispose();
    _rateIntermediateCtrl.dispose();
    _rateComplexCtrl.dispose();
    _certCtrl.dispose();
    _successController.dispose();
    super.dispose();
  }

  // ── Phone OTP ──────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) { _showSnack('Phone number daalein'); return; }
    setState(() => _sendingOtp = true);
    final error = await PhoneAuthService.sendOtp(phone);
    setState(() => _sendingOtp = false);
    if (error != null) { _showSnack(error); return; }
    if (mounted) _showOtpDialog();
  }

  void _showOtpDialog() {
    final otpCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('OTP Darj Karein', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SMS gaya: ${_phoneCtrl.text.trim()}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
              ),
              const SizedBox(height: 20),
              Pinput(
                controller: otpCtrl,
                length: 6,
                autofocus: true,
                defaultPinTheme: PinTheme(
                  width: 44, height: 50,
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                focusedPinTheme: PinTheme(
                  width: 44, height: 50,
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primary, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (_verifyingOtp) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(color: AppTheme.primary),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _verifyingOtp ? null : () async {
                setS(() => _verifyingOtp = true);
                final ok = await PhoneAuthService.verifyOtp(otpCtrl.text.trim());
                if (!ctx.mounted) return;
                setS(() => _verifyingOtp = false);
                if (ok) {
                  Navigator.pop(ctx);
                  if (mounted) setState(() => _phoneVerified = true);
                  if (mounted) _showSnack('Phone verify ho gaya! ✓');
                } else {
                  _showSnack('OTP galat hai, dobara try karein');
                }
              },
              child: const Text('Verify', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── NIC Verification ───────────────────────────────────────────
  Future<void> _verifyNicFromImage(File imageFile) async {
    setState(() { _verifyingNic = true; _nicMismatchMsg = null; });
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizer = TextRecognizer();
      final result = await recognizer.processImage(inputImage);
      recognizer.close();

      final rawText = result.text.replaceAll('\n', ' ');
      final match = RegExp(r'\b\d{5}[-\s]?\d{7}[-\s]?\d\b|\b\d{13}\b')
          .firstMatch(rawText);

      if (match == null) {
        setState(() {
          _verifyingNic = false;
          _nicMismatchMsg = 'NIC card ki image mein number nahi mila. Saaf photo lein.';
        });
        return;
      }

      final raw = match.group(0)!.replaceAll(RegExp(r'[-\s]'), '');
      final fromImage = '${raw.substring(0,5)}-${raw.substring(5,12)}-${raw[12]}';
      final typed = _nicCtrl.text.trim().replaceAll(RegExp(r'[-\s]'), '');
      final typedFormatted = typed.length == 13
          ? '${typed.substring(0,5)}-${typed.substring(5,12)}-${typed[12]}'
          : _nicCtrl.text.trim();

      if (fromImage == typedFormatted) {
        setState(() { _nicVerified = true; _verifyingNic = false; });
        _showSnack('NIC verify ho gaya! Blue tick milega ✓');
      } else {
        setState(() {
          _verifyingNic = false;
          _nicMismatchMsg = 'Match nahi hua.\nImage: $fromImage\nTyped: $typedFormatted';
        });
      }
    } catch (e) {
      setState(() { _verifyingNic = false; _nicMismatchMsg = 'Error: $e'; });
    }
  }

  Future<void> _pickNicFromGallery() async {
    if (_nicCtrl.text.trim().isEmpty) {
      _showSnack('Pehle NIC number type karein'); return;
    }
    final xFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (xFile != null) await _verifyNicFromImage(File(xFile.path));
  }

  Future<void> _scanNicWithCamera() async {
    if (_nicCtrl.text.trim().isEmpty) {
      _showSnack('Pehle NIC number type karein'); return;
    }
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const NicScannerScreen()),
    );
    if (result != null && result['image'] != null) {
      await _verifyNicFromImage(result['image'] as File);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_phoneVerified) {
      _showSnack('Phone number verify karna zaroori hai');
      return;
    }
    if (_selectedServices.isEmpty) {
      _showSnack('Kam az kam ek service chunein');
      return;
    }
    if (_selectedArea == null) {
      _showSnack('Area chunein');
      return;
    }

    setState(() => _submitting = true);

    try {
      final basicRateVal = int.tryParse(_rateBasicCtrl.text.trim()) ?? 500;
      final providerData = {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'nic': _nicCtrl.text.trim(),
        'experience_years': int.tryParse(_expCtrl.text.trim()) ?? 1,
        'hourly_rate': basicRateVal,
        'rate_basic': basicRateVal,
        'rate_intermediate': int.tryParse(_rateIntermediateCtrl.text.trim()) ?? (basicRateVal * 1.4).toInt(),
        'rate_complex': int.tryParse(_rateComplexCtrl.text.trim()) ?? (basicRateVal * 2.0).toInt(),
        'certifications': _certCtrl.text.trim(),
        'service_types': _selectedServices.map((s) => s.toLowerCase()).toList(),
        'area': _selectedArea,
        'tools': _selectedTools.toList(),
      };

      final response = await ApiService.registerProvider(providerData);

      if (mounted) {
        final pid = (response['provider']['id'] as String?) ?? '';
        final pname = _nameCtrl.text.trim();
        // Persist provider ID so "Provider Hoon" button auto-detects it
        if (pid.isNotEmpty) {
          ProviderSession.save(pid, pname);
        }
        setState(() {
          _submitting = false;
          _submitted = true;
          _nadraVerified = response['provider']['blue_tick'] ?? false;
          _registeredProviderId = pid;
        });
        _successController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _showSnack('Error: $e');
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Provider Registration'),
        automaticallyImplyLeading: !_submitted && !_submitting,
      ),
      body: _submitted
          ? _buildSuccessView(context)
          : _submitting
              ? _buildLoadingView()
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Profile Photo', Icons.camera_alt_outlined),
            const SizedBox(height: 10),
            _buildPhotoUpload(),
            const SizedBox(height: 20),

            _buildSectionHeader('Basic Info', Icons.person_outline),
            const SizedBox(height: 10),
            _buildCard([
              _buildTextField(_nameCtrl, 'Pura Naam *', Icons.badge_outlined,
                  validator: _requiredValidator),
              const SizedBox(height: 12),

              // ── Phone + OTP ──────────────────────────────────────
              _buildTextField(
                _phoneCtrl,
                'Phone Number *',
                Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                readOnly: _phoneVerified,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.trim().length < 10) return 'Valid number dein';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              _phoneVerified
                  ? _buildVerifiedBadge('Phone Verified', Icons.phone_in_talk)
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _sendingOtp ? null : _sendOtp,
                        icon: _sendingOtp
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.sms_outlined, size: 16, color: Colors.white),
                        label: Text(
                          _sendingOtp ? 'SMS ja raha hai...' : 'OTP Bhejo (Zaroori)',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                      ),
                    ),
              const SizedBox(height: 12),

              // ── NIC + Scan ───────────────────────────────────────
              _buildTextField(
                _nicCtrl,
                'NIC Number (optional — blue tick)',
                Icons.credit_card_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                readOnly: _nicVerified,
                helperText: 'NIC verify karo — zyada customers book karenge',
              ),
              const SizedBox(height: 8),
              if (_nicVerified)
                _buildVerifiedBadge('NIC Verified — Blue Tick', Icons.verified)
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _verifyingNic ? null : _pickNicFromGallery,
                        icon: const Icon(Icons.upload_file_outlined, size: 15),
                        label: const Text('Photo Upload', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _verifyingNic ? null : _scanNicWithCamera,
                        icon: const Icon(Icons.document_scanner_outlined, size: 15, color: Colors.white),
                        label: const Text('📷 Auto Scan', style: TextStyle(fontSize: 12, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_verifyingNic)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
                        SizedBox(width: 8),
                        Text('NIC verify ho raha hai...', style: TextStyle(fontSize: 12, color: AppTheme.textGrey)),
                      ],
                    ),
                  ),
                if (_nicMismatchMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_outlined, size: 15, color: Colors.red.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(_nicMismatchMsg!,
                                style: TextStyle(fontSize: 11, color: Colors.red.shade700)),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                const Text(
                  '💡 Clear photo lein — NIC seedhi pakdein, blur nahi',
                  style: TextStyle(fontSize: 11, color: AppTheme.textGrey),
                ),
              ],
            ]),
            const SizedBox(height: 20),

            _buildSectionHeader('Services', Icons.build_outlined),
            const SizedBox(height: 10),
            _buildServiceSelector(),
            const SizedBox(height: 20),

            _buildSectionHeader('Location & Experience', Icons.location_on_outlined),
            const SizedBox(height: 10),
            _buildCard([
              _buildAreaDropdown(),
              const SizedBox(height: 12),
              _buildTextField(
                _expCtrl,
                'Tajurba (saal) *',
                Icons.workspace_premium_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _requiredValidator,
              ),
            ]),
            const SizedBox(height: 20),

            _buildSectionHeader('Apni Rates Likho', Icons.payments_outlined),
            const SizedBox(height: 10),
            _buildCard([
              _buildTextField(
                _rateBasicCtrl,
                'Basic Kaam (Rs.) *',
                Icons.payments_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _requiredValidator,
                helperText: 'Saaf safai, routine check — e.g. 500',
              ),
              const SizedBox(height: 12),
              _buildTextField(
                _rateIntermediateCtrl,
                'Intermediate Kaam (Rs.) *',
                Icons.payments_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _requiredValidator,
                helperText: 'Installation, wiring, repairs — e.g. 1000',
              ),
              const SizedBox(height: 12),
              _buildTextField(
                _rateComplexCtrl,
                'Complex Kaam (Rs.) *',
                Icons.payments_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _requiredValidator,
                helperText: 'Expert work, emergency — e.g. 2000',
              ),
            ]),
            const SizedBox(height: 20),

            _buildSectionHeader('Tools & Certifications', Icons.handyman_outlined,
                subtitle: 'optional'),
            const SizedBox(height: 10),
            _buildCard([
              _buildToolChips(),
              const SizedBox(height: 12),
              _buildTextField(
                _certCtrl,
                'Certifications',
                Icons.verified_outlined,
                helperText: 'misaal: AC Technician Diploma, Wiring Certificate',
              ),
            ]),
            const SizedBox(height: 20),

            _buildSectionHeader('Availability', Icons.calendar_month_outlined),
            const SizedBox(height: 10),
            _buildAvailabilityPicker(),
            const SizedBox(height: 28),

            _buildRegisterButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon,
      {String? subtitle}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 6),
          Text(
            '($subtitle)',
            style:
                const TextStyle(fontSize: 12, color: AppTheme.textGrey),
          ),
        ],
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final XFile? image =
        await _picker.pickImage(source: source, imageQuality: 80);
    if (image != null && mounted) {
      final bytes = await image.readAsBytes();
      setState(() {
        _pickedBytes = bytes;
        _pickedPhoto = kIsWeb ? null : File(image.path);
        _useAvatar = false;
      });
    }
  }

  Widget _buildPickedImage({required double size}) {
    if (_pickedBytes != null) {
      return Image.memory(_pickedBytes!, fit: BoxFit.cover, width: size, height: size);
    }
    if (_pickedPhoto != null) {
      return Image.file(_pickedPhoto!, fit: BoxFit.cover, width: size, height: size);
    }
    return const SizedBox.shrink();
  }

  bool get _hasPhoto => _pickedBytes != null || _pickedPhoto != null;

  Widget _buildPhotoUpload() {
    return Column(
      children: [
        // Preview
        _buildPhotoPreview(),
        const SizedBox(height: 16),
        // Two option buttons
        Row(
          children: [
            Expanded(
              child: _buildPhotoOptionButton(
                icon: Icons.add_a_photo_outlined,
                label: 'Photo Upload',
                sublabel: 'Camera / Gallery',
                selected: _hasPhoto,
                onTap: () => _showPickerSheet(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPhotoOptionButton(
                icon: Icons.account_circle_outlined,
                label: 'Avatar Use Karo',
                sublabel: 'Naam se automatic',
                selected: _useAvatar,
                onTap: () => setState(() {
                  _useAvatar = true;
                  _pickedPhoto = null;
                  _pickedBytes = null;
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoPreview() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hasPhoto
                  ? Colors.transparent
                  : _useAvatar
                      ? _avatarColor
                      : Colors.grey.shade100,
              border: Border.all(
                color: (_hasPhoto || _useAvatar)
                    ? AppTheme.primary
                    : Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: _hasPhoto
                ? ClipOval(child: _buildPickedImage(size: 100))
                : _useAvatar
                    ? Center(
                        child: ValueListenableBuilder(
                          valueListenable: _nameCtrl,
                          builder: (context, value, child) => Text(
                            _initials,
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    : Icon(Icons.person_outline,
                        size: 44, color: Colors.grey.shade400),
          ),
          if (_hasPhoto || _useAvatar)
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.check,
                    size: 13, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoOptionButton({
    required IconData icon,
    required String label,
    required String sublabel,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 24,
                color: selected ? AppTheme.primary : Colors.grey.shade500),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? AppTheme.primary : AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.textGrey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showPickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppTheme.primary),
                title: const Text('Camera se lo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppTheme.primary),
                title: const Text('Gallery se lo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
              if (_hasPhoto)
                ListTile(
                  leading: Icon(Icons.delete_outline,
                      color: Colors.red.shade600),
                  title: Text('Photo hatao',
                      style: TextStyle(color: Colors.red.shade600)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() { _pickedPhoto = null; _pickedBytes = null; });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerifiedBadge(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700)),
          const Spacer(),
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    String? helperText,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      readOnly: readOnly,
      style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: AppTheme.primary),
        helperText: helperText,
        helperStyle:
            const TextStyle(fontSize: 11, color: AppTheme.textGrey),
        labelStyle:
            const TextStyle(fontSize: 13, color: AppTheme.textGrey),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildServiceSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _serviceTypes.map((service) {
          final selected = _selectedServices.contains(service);
          return GestureDetector(
            onTap: () => setState(() {
              selected
                  ? _selectedServices.remove(service)
                  : _selectedServices.add(service);
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? AppTheme.primary
                      : Colors.grey.shade300,
                ),
              ),
              child: Text(
                service,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : AppTheme.textDark,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAreaDropdown() {
    return GestureDetector(
      onTap: _showAreaPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _selectedArea != null ? AppTheme.primary : Colors.grey.shade200,
            width: _selectedArea != null ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, size: 18, color: AppTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedArea ?? 'City / Area chunein *',
                style: TextStyle(
                  fontSize: 13,
                  color: _selectedArea != null ? AppTheme.textDark : AppTheme.textGrey,
                ),
              ),
            ),
            Icon(Icons.search, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _showAreaPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AreaSearchSheet(
        onSelected: (area) => setState(() => _selectedArea = area),
        selectedArea: _selectedArea,
        areas: _pakistanAreas,
      ),
    );
  }

  Widget _buildToolChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tools Available',
          style: TextStyle(fontSize: 12, color: AppTheme.textGrey),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _toolOptions.map((tool) {
            final selected = _selectedTools.contains(tool);
            return GestureDetector(
              onTap: () => setState(() {
                selected
                    ? _selectedTools.remove(tool)
                    : _selectedTools.add(tool);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primaryLight
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? AppTheme.primary
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  tool,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected
                        ? AppTheme.primary
                        : AppTheme.textGrey,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAvailabilityPicker() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Din aur time slots chunein',
            style:
                TextStyle(fontSize: 12, color: AppTheme.textGrey),
          ),
          const SizedBox(height: 12),
          ..._weekDays.map((day) {
            final daySelected = _availability.containsKey(day);
            final slots = _availability[day] ?? {};
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => setState(() {
                      if (daySelected) {
                        _availability.remove(day);
                      } else {
                        _availability[day] = {};
                      }
                    }),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: daySelected
                                ? AppTheme.primary
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: daySelected
                                  ? AppTheme.primary
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              day,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: daySelected
                                    ? Colors.white
                                    : AppTheme.textGrey,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (daySelected)
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: _timeSlots.map((slot) {
                                final slotSelected =
                                    slots.contains(slot);
                                return GestureDetector(
                                  onTap: () => setState(() {
                                    slotSelected
                                        ? slots.remove(slot)
                                        : slots.add(slot);
                                    _availability[day] = slots;
                                  }),
                                  child: AnimatedContainer(
                                    duration: const Duration(
                                        milliseconds: 180),
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4),
                                    decoration: BoxDecoration(
                                      color: slotSelected
                                          ? AppTheme.primaryLight
                                          : Colors.grey.shade100,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                        color: slotSelected
                                            ? AppTheme.primary
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      slot,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: slotSelected
                                            ? AppTheme.primary
                                            : AppTheme.textGrey,
                                        fontWeight: slotSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          )
                        else
                          const Text(
                            'Is din available nahi',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textGrey),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.how_to_reg_outlined,
            color: Colors.white, size: 20),
        label: const Text(
          'Register Karo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppTheme.primary),
          const SizedBox(height: 20),
          Text(
            _nicCtrl.text.trim().isNotEmpty
                ? 'NADRA se verify ho raha hai...'
                : 'Profile save ho rahi hai...',
            style: const TextStyle(
                fontSize: 14, color: AppTheme.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context) {
    final nicProvided = _nicCtrl.text.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ScaleTransition(
          scale: _successScale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar with optional blue tick
              Stack(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: _useAvatar ? _avatarColor : AppTheme.primaryLight,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppTheme.primary, width: 2),
                    ),
                    child: _hasPhoto
                        ? ClipOval(child: _buildPickedImage(size: 90))
                        : _useAvatar
                            ? Center(
                                child: Text(
                                  _initials,
                                  style: const TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.person,
                                size: 52, color: AppTheme.primary),
                  ),
                  if (nicProvided && _nadraVerified)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.verified,
                            size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Aap register ho gaye!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 12),

              // Blue tick status
              if (nicProvided && _nadraVerified)
                _buildStatusChip(
                  Icons.verified,
                  'NADRA Verified — Blue Tick Mil Gaya',
                  Colors.blue,
                )
              else if (nicProvided && !_nadraVerified)
                _buildStatusChip(
                  Icons.warning_amber_outlined,
                  'NIC verify nahi hua — Blue tick nahi mila',
                  Colors.orange.shade700,
                )
              else
                _buildStatusChip(
                  Icons.info_outline,
                  'NIC nahi diya — Blue tick nahi mila',
                  AppTheme.textGrey,
                ),

              const SizedBox(height: 16),
              Text(
                'Ab customers aapko book kar saktay hain.\nAapki profile ranking, booking, aur penalty system mein shaamil ho gayi hai.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textGrey),
              ),
              const SizedBox(height: 10),
              // Service summary
              Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: _selectedServices
                    .map(
                      (s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),

              // ── Provider ID card ──────────────────────────────────
              if (_registeredProviderId.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Aapka Provider ID',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _registeredProviderId,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () async {
                              final messenger =
                                  ScaffoldMessenger.of(context);
                              await ProviderSession.copyIdToClipboard(
                                  _registeredProviderId);
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Provider ID copy ho gaya!'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.copy,
                                      size: 13, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('Copy',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Yeh ID note kar lein — notifications bhi is ID se aayenge',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: AppTheme.textGrey),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.popUntil(context, (r) => r.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Home Jao',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String? _requiredValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Yeh field zaruri hai';
    return null;
  }
}

class _AreaSearchSheet extends StatefulWidget {
  final void Function(String) onSelected;
  final String? selectedArea;
  final Map<String, List<String>> areas;

  const _AreaSearchSheet({
    required this.onSelected,
    required this.selectedArea,
    required this.areas,
  });

  @override
  State<_AreaSearchSheet> createState() => _AreaSearchSheetState();
}

class _AreaSearchSheetState extends State<_AreaSearchSheet> {
  final _searchCtrl = TextEditingController();
  List<_AreaItem> _filtered = [];
  List<_AreaItem> _all = [];

  @override
  void initState() {
    super.initState();
    _all = widget.areas.entries.expand((entry) {
      final city = entry.key;
      return [
        _AreaItem(city: city, area: city, isCity: true),
        ...entry.value.map((a) => _AreaItem(city: city, area: a, isCity: false)),
      ];
    }).toList();
    _filtered = List.from(_all);
    _searchCtrl.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_all)
          : _all.where((item) =>
              item.area.toLowerCase().contains(q) ||
              item.city.toLowerCase().contains(q)).toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'City ya area likho... (Lahore, Gulberg, DHA...)',
                hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textGrey),
                prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.primary),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text('Koi area nahi mila', style: TextStyle(color: AppTheme.textGrey)),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final item = _filtered[i];
                      final isSelected = item.area == widget.selectedArea;
                      if (item.isCity) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            item.city,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      }
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: isSelected ? AppTheme.primary : Colors.grey.shade400,
                        ),
                        title: Text(
                          item.area,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? AppTheme.primary : AppTheme.textDark,
                          ),
                        ),
                        subtitle: Text(
                          item.city,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textGrey),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, size: 16, color: AppTheme.primary)
                            : null,
                        onTap: () {
                          widget.onSelected(item.area);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AreaItem {
  final String city;
  final String area;
  final bool isCity;
  const _AreaItem({required this.city, required this.area, required this.isCity});
}
