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

import '../providers/filter_providers.dart';
import '../widgets/common/common.dart';

/// Shows the full, draggable filters sheet used by the overflow menu.
///
/// This is extracted so the greeting header and the overflow menu open the
/// exact same sheet.
Future<void> showFiltersSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        expand: true,
        initialChildSize: 0.95,
        minChildSize: 0.25,
        maxChildSize: 0.95,
        builder: (context, controller) {
          return Consumer(
            builder: (ctx, innerRef, _) {
              final p = innerRef.watch(selectedPriorityProvider);
              final s = innerRef.watch(showCompletedProvider);
              final sort = innerRef.watch(sortByProvider);

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 12,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: controller,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              '筛选',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Divider(),

                          const Padding(
                            padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
                            child: Text(
                              '优先级',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          RadioListTile<String>(
                            title: const Text('所有优先级'),
                            value: 'all',
                            // ignore: deprecated_member_use
                            groupValue: p,
                            // ignore: deprecated_member_use
                            onChanged: (v) => innerRef
                                .read(selectedPriorityProvider.notifier)
                                .update(v ?? 'all'),
                          ),
                          RadioListTile<String>(
                            title: const Text('高优先级'),
                            value: 'high',
                            // ignore: deprecated_member_use
                            groupValue: p,
                            // ignore: deprecated_member_use
                            onChanged: (v) => innerRef
                                .read(selectedPriorityProvider.notifier)
                                .update(v ?? 'high'),
                          ),
                          RadioListTile<String>(
                            title: const Text('中优先级'),
                            value: 'medium',
                            // ignore: deprecated_member_use
                            groupValue: p,
                            // ignore: deprecated_member_use
                            onChanged: (v) => innerRef
                                .read(selectedPriorityProvider.notifier)
                                .update(v ?? 'medium'),
                          ),
                          RadioListTile<String>(
                            title: const Text('低优先级'),
                            value: 'low',
                            // ignore: deprecated_member_use
                            groupValue: p,
                            // ignore: deprecated_member_use
                            onChanged: (v) => innerRef
                                .read(selectedPriorityProvider.notifier)
                                .update(v ?? 'low'),
                          ),

                          const SizedBox(height: 8),

                          SwitchListTile(
                            title: const Text('显示已完成'),
                            value: s,
                            onChanged: (value) => innerRef
                                .read(showCompletedProvider.notifier)
                                .update(value),
                          ),

                          const SizedBox(height: 8),

                          const Padding(
                            padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
                            child: Text(
                              '排序方式',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          RadioListTile<String>(
                            title: const Text('默认'),
                            value: 'default',
                            // ignore: deprecated_member_use
                            groupValue: sort,
                            // ignore: deprecated_member_use
                            onChanged: (v) => innerRef
                                .read(sortByProvider.notifier)
                                .update(v ?? 'default'),
                          ),
                          RadioListTile<String>(
                            title: const Text('创建日期'),
                            value: 'date_created',
                            // ignore: deprecated_member_use
                            groupValue: sort,
                            // ignore: deprecated_member_use
                            onChanged: (v) => innerRef
                                .read(sortByProvider.notifier)
                                .update(v ?? 'date_created'),
                          ),
                          RadioListTile<String>(
                            title: const Text('截止日期'),
                            value: 'date_due',
                            // ignore: deprecated_member_use
                            groupValue: sort,
                            // ignore: deprecated_member_use
                            onChanged: (v) => innerRef
                                .read(sortByProvider.notifier)
                                .update(v ?? 'date_due'),
                          ),
                          RadioListTile<String>(
                            title: const Text('优先级'),
                            value: 'priority',
                            // ignore: deprecated_member_use
                            groupValue: sort,
                            // ignore: deprecated_member_use
                            onChanged: (v) => innerRef
                                .read(sortByProvider.notifier)
                                .update(v ?? 'priority'),
                          ),
                          RadioListTile<String>(
                            title: const Text('按字母顺序'),
                            value: 'alphabetical',
                            // ignore: deprecated_member_use
                            groupValue: sort,
                            // ignore: deprecated_member_use
                            onChanged: (v) => innerRef
                                .read(sortByProvider.notifier)
                                .update(v ?? 'alphabetical'),
                          ),

                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ExpressiveTextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('关闭'),
                        ),
                        const SizedBox(width: 8),
                        ExpressiveElevatedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('完成'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}
