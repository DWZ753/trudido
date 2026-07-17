import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../repositories/notes_repository.dart';
import '../providers/notes_providers.dart';
import '../repositories/note_folder_repository.dart';
import '../widgets/common/common.dart';

class VaultBinScreen extends ConsumerStatefulWidget {
  const VaultBinScreen({super.key});

  @override
  ConsumerState<VaultBinScreen> createState() => _VaultBinScreenState();
}

class _VaultBinScreenState extends ConsumerState<VaultBinScreen> {
  List<Note> _deletedVaultNotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final notesRepo = ref.read(notesRepositoryProvider);
    final allDeletedNotes = await notesRepo.getDeletedNotes();
    final folderRepo = ref.read(noteFolderRepositoryProvider);

    final vaultNotes = <Note>[];
    for (final note in allDeletedNotes) {
      if (note.folderId == null) continue;
      final folder = folderRepo.getNoteFolderById(note.folderId!);
      if (folder != null && folder.isVault) {
        vaultNotes.add(note);
      }
    }
    _deletedVaultNotes = vaultNotes;

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _emptyBin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空保险库回收站？'),
        content: const Text(
          '所有已删除的保险库笔记将被永久移除，此操作无法撤销。',
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context, true),
            style: ExpressiveTextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清空回收站'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(notesRepositoryProvider)
          .emptyBin(true); // true = only vault
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('保险库回收站'),
        actions: [
          ExpressiveIconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: '清空回收站',
            onPressed: _emptyBin,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _deletedVaultNotes.isEmpty
          ? const Center(child: Text('没有已删除的保险库笔记'))
          : ListView.builder(
              itemCount: _deletedVaultNotes.length,
              itemBuilder: (context, index) {
                final note = _deletedVaultNotes[index];
                return ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('已锁定的笔记'),
                  subtitle: const Text('内容已隐藏'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExpressiveIconButton(
                        icon: const Icon(Icons.restore),
                        onPressed: () async {
                          await ref
                              .read(notesRepositoryProvider)
                              .restoreNote(note.id);
                          _loadData();
                          final _ = ref.refresh(notesProvider);
                        },
                      ),
                      ExpressiveIconButton(
                        icon: const Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                        ),
                        onPressed: () async {
                          await ref
                              .read(notesRepositoryProvider)
                              .permanentlyDeleteNote(note.id);
                          _loadData();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
