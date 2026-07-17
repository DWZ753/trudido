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

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/media_service.dart';
import '../widgets/common/common.dart';

/// Dialog for inserting a link in the note editor
class LinkInsertDialog extends StatefulWidget {
  final Function(String url, String text) onInsert;

  const LinkInsertDialog({super.key, required this.onInsert});

  @override
  State<LinkInsertDialog> createState() => _LinkInsertDialogState();
}

class _LinkInsertDialogState extends State<LinkInsertDialog> {
  final _urlController = TextEditingController();
  final _textController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('插入链接'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: '网址',
              hintText: 'https://example.com',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            decoration: const InputDecoration(
              labelText: '链接文本（可选）',
              hintText: '点击此处',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        ExpressiveTextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ExpressiveElevatedButton(
          onPressed: () {
            if (_urlController.text.trim().isNotEmpty) {
              widget.onInsert(
                _urlController.text.trim(),
                _textController.text.trim(),
              );
              Navigator.of(context).pop();
            }
          },
          child: const Text('插入'),
        ),
      ],
    );
  }
}

/// Dialog for recording voice notes
class VoiceRecordingDialog extends StatefulWidget {
  final MediaService mediaService;
  final Function(File) onRecordingComplete;

  const VoiceRecordingDialog({
    super.key,
    required this.mediaService,
    required this.onRecordingComplete,
  });

  @override
  State<VoiceRecordingDialog> createState() => _VoiceRecordingDialogState();
}

class _VoiceRecordingDialogState extends State<VoiceRecordingDialog> {
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _durationTimer;
  Duration _recordingDuration = Duration.zero;

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final success = await widget.mediaService.startRecording();
    if (success && mounted) {
      setState(() {
        _isRecording = true;
        _recordingStartTime = DateTime.now();
        _recordingDuration = Duration.zero;
      });

      // Keep screen on while recording
      WakelockPlus.enable();

      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _recordingStartTime != null) {
          setState(() {
            _recordingDuration = DateTime.now().difference(
              _recordingStartTime!,
            );
          });
        }
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '无法开始录音，请检查麦克风权限。',
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _stopRecording() async {
    _durationTimer?.cancel();
    WakelockPlus.disable();
    final file = await widget.mediaService.stopRecording();
    if (file != null && mounted) {
      widget.onRecordingComplete(file);
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存录音失败')));
      Navigator.pop(context);
    }
  }

  Future<void> _cancelRecording() async {
    _durationTimer?.cancel();
    WakelockPlus.disable();
    await widget.mediaService.cancelRecording();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('录制语音笔记'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isRecording) ...[
            const SizedBox(height: 20),
            Icon(
              Icons.mic,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 20),
            Text(
              _formatDuration(_recordingDuration),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            const Text('正在录音...'),
          ] else ...[
            const SizedBox(height: 20),
            Icon(
              Icons.mic_none,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            const Text('点击麦克风开始录音'),
          ],
        ],
      ),
      actions: [
        if (!_isRecording) ...[
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ExpressiveElevatedButton.icon(
            onPressed: _startRecording,
            icon: const Icon(Icons.mic),
            label: const Text('开始录音'),
          ),
        ] else ...[
          ExpressiveTextButton(
            onPressed: _cancelRecording,
            child: const Text('取消'),
          ),
          ExpressiveElevatedButton.icon(
            onPressed: _stopRecording,
            icon: const Icon(Icons.stop),
            label: const Text('停止并保存'),
            style: ExpressiveElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
          ),
        ],
      ],
    );
  }
}
