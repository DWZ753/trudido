// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2026 Dominik Müller
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/note_folder_repository.dart';
import '../models/note_folder.dart';
import '../services/biometric_auth_service.dart';
import '../services/vault_password_service.dart';
import '../services/vault_auth_service.dart';
import '../widgets/common/common.dart';

const int _defaultNoteFolderColor = 0xFF2196F3;
const int _defaultVaultFolderColor = 0xFFFFC107;
const List<int> _noteFolderColorPalette = [
  0xFF2196F3, // Blue
  0xFF4CAF50, // Green
  0xFFFF9800, // Orange
  0xFFF44336, // Red
  0xFF9C27B0, // Purple
  0xFF00BCD4, // Cyan
  0xFF795548, // Brown
  0xFF607D8B, // Blue Grey
  0xFFE91E63, // Pink
  0xFFFFC107, // Amber
];

/// Folder management screen specifically for Notes (with vault support)
class NotesFolderManagementScreen extends ConsumerStatefulWidget {
  const NotesFolderManagementScreen({super.key});

  @override
  ConsumerState<NotesFolderManagementScreen> createState() =>
      _NotesFolderManagementScreenState();
}

class _NotesFolderManagementScreenState
    extends ConsumerState<NotesFolderManagementScreen> {
  Widget _buildFolderColorPicker({
    required BuildContext context,
    required int selectedColor,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('文件夹颜色', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _noteFolderColorPalette.map((value) {
            final isSelected = value == selectedColor;
            return ExpressiveGestureDetector(
              onTap: () => onChanged(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Color(value),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: isSelected ? 2.5 : 1,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: Color(value).computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(noteFoldersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('笔记文件夹'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: foldersAsync.when(
        data: (folders) {
          if (folders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无文件夹',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('创建文件夹来整理您的笔记'),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showCreateFolderDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('创建文件夹'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: folders.length,
            itemBuilder: (context, index) {
              final folder = folders[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(
                    folder.isVault ? Icons.lock : Icons.folder,
                    color: Color(folder.color),
                    size: 32,
                  ),
                  title: Text(
                    folder.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (folder.description != null &&
                          folder.description!.isNotEmpty)
                        Text(folder.description!),
                      if (folder.isVault)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock,
                                size: 14,
                                color: Color(folder.color),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '加密保险箱',
                                style: TextStyle(
                                  color: Color(folder.color),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExpressiveIconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditFolderDialog(folder),
                        tooltip: '编辑文件夹',
                      ),
                      ExpressiveIconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteFolder(folder),
                        tooltip: '删除文件夹',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text('加载文件夹失败'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.refresh(noteFoldersProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: ExpressiveFloatingActionButton(
        onPressed: () => _showCreateFolderDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCreateFolderDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isVault = false;
    int selectedColor = _defaultNoteFolderColor;

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('创建笔记文件夹'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '文件夹名称',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入文件夹名称';
                      }
                      return null;
                    },
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: '描述（可选）',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  _buildFolderColorPicker(
                    context: context,
                    selectedColor: selectedColor,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedColor = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('加密保险箱文件夹'),
                    subtitle: const Text(
                      '笔记将使用 AES-256 加密',
                      style: TextStyle(fontSize: 12),
                    ),
                    secondary: Icon(
                      isVault ? Icons.lock : Icons.lock_open,
                      color: isVault ? Colors.amber : null,
                    ),
                    value: isVault,
                    onChanged: (value) {
                      setDialogState(() {
                        final nextIsVault = value ?? false;
                        if (nextIsVault &&
                            selectedColor == _defaultNoteFolderColor) {
                          selectedColor = _defaultVaultFolderColor;
                        } else if (!nextIsVault &&
                            selectedColor == _defaultVaultFolderColor) {
                          selectedColor = _defaultNoteFolderColor;
                        }
                        isVault = nextIsVault;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ExpressiveTextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  final description = descriptionController.text.trim();
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  // If vault, setup password and biometric preferences
                  String? vaultPassword;
                  bool useBiometric = true;

                  if (isVault) {
                    // Show password setup dialog
                    final passwordResult = await _showPasswordSetupDialog(
                      context,
                      name,
                    );

                    if (passwordResult == null) {
                      return; // User cancelled
                    }

                    vaultPassword = passwordResult['password'] as String;
                    useBiometric = passwordResult['useBiometric'] as bool;
                  }

                  // Create the folder first
                  final result = await ref
                      .read(noteFoldersProvider.notifier)
                      .createFolder(
                        name: name,
                        description: description.isEmpty ? null : description,
                        isVault: isVault,
                        hasPassword: isVault && vaultPassword != null,
                        useBiometric: useBiometric,
                        color: selectedColor,
                      );

                  if (mounted) {
                    if (result != null) {
                      // Store the password if vault
                      if (isVault && vaultPassword != null) {
                        await VaultPasswordService.setVaultPassword(
                          result.id,
                          vaultPassword,
                        );
                      }

                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('文件夹"$name"已成功创建'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            '创建文件夹失败，名称可能已存在。',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditFolderDialog(NoteFolder folder) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: folder.name);
    final descriptionController = TextEditingController(
      text: folder.description ?? '',
    );
    int selectedColor = folder.color;

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('编辑文件夹'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '文件夹名称',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入文件夹名称';
                      }
                      return null;
                    },
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: '描述（可选）',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  _buildFolderColorPicker(
                    context: context,
                    selectedColor: selectedColor,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedColor = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Show vault status but don't allow editing
                  if (folder.isVault)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(folder.color).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Color(folder.color)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock,
                            color: Color(folder.color),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '加密保险箱文件夹 - 创建后无法禁用加密',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(folder.color),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            ExpressiveTextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  final description = descriptionController.text.trim();
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  final updated = folder.copyWith(
                    name: name,
                    description: description.isEmpty ? null : description,
                    color: selectedColor,
                    // Keep existing vault status - cannot be changed
                  );

                  final result = await ref
                      .read(noteFoldersProvider.notifier)
                      .updateFolder(updated);

                  if (mounted) {
                    navigator.pop();
                    if (result != null) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('文件夹"$name"已成功更新'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            '更新文件夹失败，名称可能已存在。',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('更新'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteFolder(NoteFolder folder) async {
    // If it's a vault folder, require authentication first
    if (folder.isVault) {
      final authenticated = await VaultAuthService.authenticate(
        context: context,
        folderId: folder.id,
        folderName: folder.name,
        useBiometric: folder.useBiometric,
        hasPassword: folder.hasPassword,
      );

      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('需要身份验证才能删除保险箱文件夹'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除文件夹'),
        content: Text(
          '删除"${folder.name}"？\n\n此文件夹中的笔记不会被删除，但将不再与当前文件夹关联。',
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(noteFoldersProvider.notifier)
          .deleteFolder(folder.id);

      if (mounted) {
        if (success) {
          // Delete the vault password if it was a vault folder
          if (folder.isVault && folder.hasPassword) {
            await VaultPasswordService.removeVaultPassword(folder.id);
          }

          messenger.showSnackBar(
            SnackBar(
              content: Text('文件夹"${folder.name}"已成功删除'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  /// Shows password setup dialog for vault folders
  Future<Map<String, dynamic>?> _showPasswordSetupDialog(
    BuildContext context,
    String folderName,
  ) async {
    final formKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirm = true;
    bool useBiometric = true;

    // Check if biometric is available
    final biometricAvailable =
        await BiometricAuthService.isBiometricsAvailable();

    if (!context.mounted) return null;
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('为 $folderName 设置密码'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '创建密码/PIN 以保护此保险箱文件夹',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: '密码/PIN',
                      border: const OutlineInputBorder(),
                      suffixIcon: ExpressiveIconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入密码';
                      }
                      if (value.length < 4) {
                        return '密码长度至少为 4 个字符';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: '确认密码',
                      border: const OutlineInputBorder(),
                      suffixIcon: ExpressiveIconButton(
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureConfirm = !obscureConfirm;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value != passwordController.text) {
                        return '密码不匹配';
                      }
                      return null;
                    },
                  ),
                  if (biometricAvailable) ...[
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('使用生物识别快捷方式'),
                      subtitle: const Text(
                        '使用指纹/面部识别跳过密码',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: useBiometric,
                      onChanged: (value) {
                        setState(() {
                          useBiometric = value ?? true;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            ExpressiveTextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, {
                    'password': passwordController.text,
                    'useBiometric': useBiometric,
                  });
                }
              },
              child: const Text('设置'),
            ),
          ],
        ),
      ),
    );
  }
}
