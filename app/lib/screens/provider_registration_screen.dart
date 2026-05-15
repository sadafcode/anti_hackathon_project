import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

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
  final _rateCtrl = TextEditingController();
  final _certCtrl = TextEditingController();

  // State
  File? _pickedPhoto;
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

  late AnimationController _successController;
  late Animation<double> _successScale;

  // Mock NADRA database
  static const Map<String, bool> _nadraDb = {
    '4210112345671': true,
    '3520198765432': true,
    '6110187654321': true,
    '3520112233445': true,
    '6110198877665': true,
    '4210187654322': true,
    '3310145678901': false,
    '4220156789012': false,
  };

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

  static const List<String> _islamabadSectors = [
    'F-6', 'F-7', 'F-8', 'F-10', 'F-11',
    'G-6', 'G-7', 'G-8', 'G-9', 'G-10', 'G-11', 'G-13',
    'I-8', 'I-9', 'I-10',
    'E-7', 'E-11',
    'DHA Phase 1', 'DHA Phase 2',
    'Bahria Town', 'PWD', 'Gulberg',
  ];

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
    _rateCtrl.dispose();
    _certCtrl.dispose();
    _successController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
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
      final providerData = {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'nic': _nicCtrl.text.trim(),
        'experience_years': int.tryParse(_expCtrl.text.trim()) ?? 1,
        'hourly_rate': int.tryParse(_rateCtrl.text.trim()) ?? 500,
        'certifications': _certCtrl.text.trim(),
        'service_types': _selectedServices.toList(),
        'area': _selectedArea,
        'tools': _selectedTools.toList(),
      };

      final response = await ApiService.registerProvider(providerData);

      if (mounted) {
        setState(() {
          _submitting = false;
          _submitted = true;
          _nadraVerified = response['provider']['blue_tick'] ?? false;
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
              _buildTextField(
                _phoneCtrl,
                'Phone Number *',
                Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.trim().length < 10) return 'Valid number dein';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildTextField(
                _nicCtrl,
                'NIC Number (optional)',
                Icons.credit_card_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                helperText: 'NIC se blue tick milega — optional hai',
              ),
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
              Row(children: [
                Expanded(
                  child: _buildTextField(
                    _expCtrl,
                    'Tajurba (saal) *',
                    Icons.workspace_premium_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: _requiredValidator,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    _rateCtrl,
                    'Hourly Rate (Rs.) *',
                    Icons.payments_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: _requiredValidator,
                  ),
                ),
              ]),
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
      setState(() {
        _pickedPhoto = File(image.path);
        _useAvatar = false;
      });
    }
  }

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
                selected: _pickedPhoto != null,
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
              color: _pickedPhoto != null
                  ? Colors.transparent
                  : _useAvatar
                      ? _avatarColor
                      : Colors.grey.shade100,
              border: Border.all(
                color: (_pickedPhoto != null || _useAvatar)
                    ? AppTheme.primary
                    : Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: _pickedPhoto != null
                ? ClipOval(
                    child: Image.file(
                      _pickedPhoto!,
                      fit: BoxFit.cover,
                      width: 100,
                      height: 100,
                    ),
                  )
                : _useAvatar
                    ? Center(
                        child: ValueListenableBuilder(
                          valueListenable: _nameCtrl,
                          builder: (_, __, ___) => Text(
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
          if (_pickedPhoto != null || _useAvatar)
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
              if (_pickedPhoto != null)
                ListTile(
                  leading: Icon(Icons.delete_outline,
                      color: Colors.red.shade600),
                  title: Text('Photo hatao',
                      style: TextStyle(color: Colors.red.shade600)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _pickedPhoto = null);
                  },
                ),
            ],
          ),
        ),
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
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
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
    return DropdownButtonFormField<String>(
      value: _selectedArea,
      hint: const Text('Area / Sector chunein *',
          style: TextStyle(fontSize: 13, color: AppTheme.textGrey)),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.location_on_outlined,
            size: 18, color: AppTheme.primary),
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
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: _islamabadSectors
          .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
          .toList(),
      onChanged: (v) => setState(() => _selectedArea = v),
      validator: (v) => v == null ? 'Area chunein' : null,
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
            final slots = _availability[day] ?? {};
            final daySelected = slots.isNotEmpty;
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
                    child: _pickedPhoto != null
                        ? ClipOval(
                            child: Image.file(
                              _pickedPhoto!,
                              fit: BoxFit.cover,
                              width: 90,
                              height: 90,
                            ),
                          )
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
              const SizedBox(height: 32),
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
