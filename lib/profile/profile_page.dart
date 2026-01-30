import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../core/supabase_client.dart';
import '../core/theme_provider.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

/// Página de Perfil do Usuário
class ProfilePage extends StatefulWidget {
  final ThemeProvider themeProvider;

  const ProfilePage({
    super.key,
    required this.themeProvider,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _profileService = ProfileService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Máscara para telefone brasileiro (celular)
  final _phoneMaskFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  UserProfile? _profile;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await _profileService.fetchCurrentProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _nameController.text = profile?.name ?? '';
          // Formata o telefone se existir
          if (profile?.phone != null && profile!.phone!.isNotEmpty) {
            _phoneMaskFormatter.formatEditUpdate(
              const TextEditingValue(text: ''),
              TextEditingValue(text: profile.phone!.replaceAll(RegExp(r'[^\d]'), '')),
            );
            _phoneController.text = _phoneMaskFormatter.getMaskedText();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar perfil: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final result = await _profileService.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (result.success && result.profile != null) {
          setState(() {
            _profile = result.profile;
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (image == null) return;

    setState(() => _isSaving = true);

    try {
      final avatarUrl = await _profileService.uploadAvatar(image.path);
      
      if (avatarUrl != null) {
        await _profileService.updateProfile(avatarUrl: avatarUrl);
        await _loadProfile();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao fazer upload da imagem'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildAvatar(),
            const SizedBox(height: 32),
            _buildEmailCard(),
            const SizedBox(height: 24),
            _buildFormFields(),
            const SizedBox(height: 32),
            _buildThemeSection(),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundImage: _profile?.avatarUrl != null
              ? NetworkImage(_profile!.avatarUrl!)
              : null,
          child: _profile?.avatarUrl == null
              ? Text(
                  _profile?.initials ?? '?',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                )
              : null,
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            onPressed: _isSaving ? null : _pickImage,
            iconSize: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Email',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            _profile?.email ?? supabase.auth.currentUser?.email ?? '',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Nome',
            prefixIcon: Icon(Icons.person),
            hintText: 'Digite seu nome',
          ),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Por favor, digite seu nome';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Telefone',
            prefixIcon: Icon(Icons.phone),
            hintText: '(00) 00000-0000',
            helperText: 'Digite apenas os números',
          ),
          keyboardType: TextInputType.phone,
          inputFormatters: [_phoneMaskFormatter],
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              // Remove a formatação para validar
              final digits = value.replaceAll(RegExp(r'[^\d]'), '');
              if (digits.length < 10 || digits.length > 11) {
                return 'Telefone inválido';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildThemeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aparência',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildThemeOption(
            'Sistema',
            'Seguir configuração do dispositivo',
            Icons.settings_suggest,
            ThemeMode.system,
          ),
          const SizedBox(height: 8),
          _buildThemeOption(
            'Claro',
            'Tema claro',
            Icons.light_mode,
            ThemeMode.light,
          ),
          const SizedBox(height: 8),
          _buildThemeOption(
            'Escuro',
            'Tema escuro',
            Icons.dark_mode,
            ThemeMode.dark,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    String title,
    String subtitle,
    IconData icon,
    ThemeMode mode,
  ) {
    final isSelected = widget.themeProvider.themeMode == mode;

    return InkWell(
      onTap: () {
        widget.themeProvider.setThemeMode(mode);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: Theme.of(context).colorScheme.primary)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : null,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: _isSaving ? null : _saveProfile,
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Salvar Alterações'),
      ),
    );
  }
}
