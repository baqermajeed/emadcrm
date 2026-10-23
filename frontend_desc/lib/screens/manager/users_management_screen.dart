import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/reception_tokens.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../utils/enums.dart';
import '../../utils/validators.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/staff_avatar.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key, this.bottom});

  final PreferredSizeWidget? bottom;

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final _search = TextEditingController();
  List<AppUser> _users = [];
  bool _loading = true;
  String? _error;
  UserRole? _roleFilter;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({String? search, UserRole? role}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await UserService(context.read<ApiClient>()).list(
        role: role,
        search: search,
        includeInactive: true,
      );
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل المستخدمين';
        _loading = false;
      });
    }
  }

  List<AppUser> get _filtered {
    var list = [..._users];
    list.sort((a, b) => a.fullName.compareTo(b.fullName));
    return list;
  }

  void _runServerSearch(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _load(
        role: _roleFilter,
        search: query.trim().isEmpty ? null : query.trim(),
      );
    });
  }

  Future<void> _openEditor({AppUser? user}) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _UserEditorDialog(user: user),
    );
    if (ok == true && mounted) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(user == null ? 'تم إضافة المستخدم' : 'تم تحديث المستخدم'),
        ),
      );
    }
  }

  Future<void> _toggleActive(AppUser user) async {
    final api = context.read<ApiClient>();
    try {
      await UserService(api).update(user.id, isActive: !user.isActive);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;

    return AppScaffold(
      title: 'إدارة المستخدمين',
      bottom: widget.bottom,
      actions: [
        IconButton(
          tooltip: 'تحديث',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: ReceptionTokens.confirmBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(
          'إضافة مستخدم',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _search,
                    onChanged: _runServerSearch,
                    decoration: InputDecoration(
                      hintText: 'بحث بالاسم أو اسم الدخول أو الهاتف',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: ReceptionTokens.navy.withValues(alpha: 0.12),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: ReceptionTokens.navy.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<UserRole?>(
                    key: ValueKey(_roleFilter?.api ?? 'all'),
                    initialValue: _roleFilter,
                    decoration: InputDecoration(
                      labelText: 'الدور',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('كل الأدوار'),
                      ),
                      ...UserRole.values.map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(r.label),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _roleFilter = v);
                      unawaited(
                        _load(
                          role: v,
                          search: _search.text.trim().isEmpty
                              ? null
                              : _search.text.trim(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading && _users.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _users.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            EmptyState(message: _error!),
                          ],
                        )
                      : rows.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 120),
                                EmptyState(message: 'لا يوجد مستخدمون'),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                              itemCount: rows.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final u = rows[i];
                                return _UserCard(
                                  user: u,
                                  onEdit: () => _openEditor(user: u),
                                  onToggleActive: () => _toggleActive(u),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onToggleActive,
  });

  final AppUser user;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      shadowColor: ReceptionTokens.teal.withValues(alpha: 0.2),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: ReceptionTokens.navy.withValues(alpha: 0.08),
            ),
            boxShadow: ReceptionTokens.softShadow,
          ),
          child: Row(
            children: [
              StaffAvatar(user: user, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: ReceptionTokens.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username} · ${user.role.label}',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: ReceptionTokens.navy.withValues(alpha: 0.55),
                      ),
                    ),
                    if (user.phone != null && user.phone!.isNotEmpty)
                      Text(
                        user.phone!,
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: ReceptionTokens.linkBlue,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: user.isActive
                      ? ReceptionTokens.statusGreenBg.withValues(alpha: 0.45)
                      : const Color(0xFFFFE4E6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user.isActive ? 'نشط' : 'معطّل',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: user.isActive
                        ? ReceptionTokens.statusGreenText
                        : const Color(0xFFB91C1C),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: user.isActive ? 'تعطيل' : 'تفعيل',
                onPressed: onToggleActive,
                icon: Icon(
                  user.isActive
                      ? Icons.block_rounded
                      : Icons.check_circle_outline_rounded,
                  color: ReceptionTokens.navy.withValues(alpha: 0.55),
                ),
              ),
              IconButton(
                tooltip: 'تعديل',
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit_outlined,
                  color: ReceptionTokens.confirmBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserEditorDialog extends StatefulWidget {
  const _UserEditorDialog({this.user});

  final AppUser? user;

  bool get isEditing => user != null;

  @override
  State<_UserEditorDialog> createState() => _UserEditorDialogState();
}

class _UserEditorDialogState extends State<_UserEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _username;
  late final TextEditingController _fullName;
  late final TextEditingController _phone;
  late final TextEditingController _password;
  late UserRole _role;
  late bool _isActive;
  bool _saving = false;
  bool _obscure = true;

  Uint8List? _pickedBytes;
  String? _pickedPath;
  String? _pickedName;
  bool _removeAvatar = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _username = TextEditingController(text: u?.username ?? '');
    _fullName = TextEditingController(text: u?.fullName ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
    _password = TextEditingController();
    _role = u?.role ?? UserRole.reception;
    _isActive = u?.isActive ?? true;
  }

  @override
  void dispose() {
    _username.dispose();
    _fullName.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (file == null || !mounted) return;
    final originalBytes = await file.readAsBytes();
    if (!mounted) return;
    final croppedBytes = await showDialog<Uint8List>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => _AvatarCropDialog(sourceBytes: originalBytes),
    );
    if (croppedBytes == null || !mounted) return;
    final croppedPath = await _writeTempAvatar(croppedBytes);
    if (!mounted) return;
    setState(() {
      _pickedBytes = croppedBytes;
      _pickedPath = croppedPath;
      _pickedName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.png';
      _removeAvatar = false;
    });
  }

  Future<String> _writeTempAvatar(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}\\avatar_${DateTime.now().millisecondsSinceEpoch}.png';
    final f = File(path);
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  void _clearPhoto() {
    setState(() {
      _pickedBytes = null;
      _pickedPath = null;
      _pickedName = null;
      if (widget.user?.avatarUrl != null) {
        _removeAvatar = true;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final svc = UserService(context.read<ApiClient>());
    try {
      late AppUser saved;
      if (widget.isEditing) {
        saved = await svc.update(
          widget.user!.id,
          username: _username.text,
          fullName: _fullName.text,
          phone: _phone.text,
          role: _role,
          password: _password.text.trim().isEmpty ? null : _password.text,
          isActive: _isActive,
          clearAvatar: _removeAvatar && _pickedPath == null,
        );
      } else {
        saved = await svc.create(
          username: _username.text,
          password: _password.text,
          fullName: _fullName.text,
          role: _role,
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          isActive: _isActive,
        );
      }

      if (_pickedPath != null && _pickedName != null) {
        saved = await svc.uploadAvatar(
          saved.id,
          _pickedPath!,
          _pickedName!,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشلت العملية')),
      );
    }
  }

  Widget _buildPhotoPicker() {
    final existingUrl =
        (!_removeAvatar && _pickedBytes == null) ? widget.user?.avatarNetworkUrl : null;
    final hasPhoto = _pickedBytes != null || existingUrl != null;

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 46,
              backgroundColor: ReceptionTokens.plusBg,
              backgroundImage: _pickedBytes != null
                  ? MemoryImage(_pickedBytes!)
                  : existingUrl != null
                      ? CachedNetworkImageProvider(existingUrl)
                      : null,
              child: !hasPhoto
                  ? const Icon(
                      Icons.person_rounded,
                      size: 44,
                      color: ReceptionTokens.navy,
                    )
                  : null,
            ),
            Material(
              color: ReceptionTokens.confirmBlue,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _saving ? null : _pickPhoto,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          hasPhoto ? 'تغيير صورة الموظف' : 'إضافة صورة الموظف',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: ReceptionTokens.navy.withValues(alpha: 0.7),
          ),
        ),
        if (hasPhoto)
          TextButton(
            onPressed: _saving ? null : _clearPhoto,
            child: Text(
              'إزالة الصورة',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700,
                color: const Color(0xFFB91C1C),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width.clamp(320.0, 520.0);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: maxW,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.isEditing
                            ? Icons.manage_accounts_rounded
                            : Icons.person_add_alt_1_rounded,
                        color: ReceptionTokens.confirmBlue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.isEditing ? 'تعديل مستخدم' : 'إضافة مستخدم جديد',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: ReceptionTokens.navy,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildPhotoPicker(),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _fullName,
                    inputFormatters: [PersonNameInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'الاسم الكامل',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: AppValidators.personName,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _username,
                    decoration: const InputDecoration(
                      labelText: 'اسم الدخول',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.length < 3) return '٣ أحرف على الأقل';
                      if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(t)) {
                        return 'أحرف إنجليزية وأرقام فقط';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [IraqPhoneInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      hintText: '07xxxxxxxxx',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) =>
                        AppValidators.phone(v, required: false),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<UserRole>(
                    key: ValueKey(_role),
                    initialValue: _role,
                    decoration: const InputDecoration(
                      labelText: 'الدور',
                      prefixIcon: Icon(Icons.work_outline_rounded),
                    ),
                    items: UserRole.values
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.label),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _role = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: widget.isEditing
                          ? 'كلمة مرور جديدة (اختياري)'
                          : 'كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (v) {
                      final t = v ?? '';
                      if (!widget.isEditing && t.length < 4) {
                        return '٤ أحرف على الأقل';
                      }
                      if (widget.isEditing && t.isNotEmpty && t.length < 4) {
                        return '٤ أحرف على الأقل';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'الحساب نشط',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                    ),
                    value: _isActive,
                    activeThumbColor: ReceptionTokens.confirmBlue,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: ReceptionTokens.confirmBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            widget.isEditing ? 'حفظ التعديلات' : 'إنشاء المستخدم',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarCropDialog extends StatefulWidget {
  const _AvatarCropDialog({required this.sourceBytes});

  final Uint8List sourceBytes;

  @override
  State<_AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<_AvatarCropDialog> {
  static const double _cropSize = 280;
  final TransformationController _transform = TransformationController();
  final GlobalKey _captureKey = GlobalKey();

  ui.Image? _decoded;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  @override
  void dispose() {
    _transform.dispose();
    _decoded?.dispose();
    super.dispose();
  }

  Future<void> _decodeImage() async {
    final codec = await ui.instantiateImageCodec(widget.sourceBytes);
    final frame = await codec.getNextFrame();
    _decoded = frame.image;
    if (mounted) setState(() {});
  }

  Future<void> _saveCrop() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.4);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      if (!mounted) return;
      Navigator.pop(context, data.buffer.asUint8List());
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر اقتصاص الصورة')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final decoded = _decoded;
    final theme = Theme.of(context);
    final canCrop = decoded != null && !_saving;

    Widget cropBody;
    if (decoded == null) {
      cropBody = const SizedBox(
        width: _cropSize,
        height: _cropSize,
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      final imageRatio = decoded.width / decoded.height;
      final baseWidth = imageRatio >= 1 ? _cropSize * imageRatio : _cropSize;
      final baseHeight = imageRatio >= 1 ? _cropSize : _cropSize / imageRatio;
      cropBody = RepaintBoundary(
        key: _captureKey,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: _cropSize,
            height: _cropSize,
            color: const Color(0xFFF1F5F9),
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 1,
              maxScale: 4,
              boundaryMargin: const EdgeInsets.all(240),
              child: Center(
                child: Image.memory(
                  widget.sourceBytes,
                  width: baseWidth,
                  height: baseHeight,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.crop_square_rounded, color: ReceptionTokens.confirmBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'اقتصاص الصورة 1:1',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: ReceptionTokens.navy,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              'حرّك الصورة وكبّر/صغّر حتى تضبط الإطار المربع',
              style: GoogleFonts.cairo(
                color: ReceptionTokens.navy.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            cropBody,
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canCrop ? _saveCrop : null,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  _saving ? 'جاري الحفظ...' : 'اعتماد القص',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: ReceptionTokens.confirmBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: Text(
                'إلغاء',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ReceptionTokens.navy.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
