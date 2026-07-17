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

import 'package:hive/hive.dart';
import '../models/folder_template.dart';
import '../repositories/folder_template_repository.dart';
import '../services/storage_service.dart';

/// Concrete implementation of FolderTemplateRepository using Hive
class HiveFolderTemplateRepository implements FolderTemplateRepository {
  static const String _templatesBoxName = 'folder_templates';
  Box<FolderTemplate>? _templatesBox;

  /// Initialize the repository with Hive box
  Future<void> init() async {
    _templatesBox = await Hive.openBox<FolderTemplate>(_templatesBoxName);
    // Create built-in templates if none exist
    await _createBuiltInTemplatesIfNeeded();
  }

  @override
  Future<List<FolderTemplate>> getAllTemplates() async {
    if (_templatesBox == null) await init();
    final templates = _templatesBox!.values.toList();
    // Sort: built-in first, then by usage count, then by name
    templates.sort((a, b) {
      if (a.isBuiltIn && !b.isBuiltIn) return -1;
      if (!a.isBuiltIn && b.isBuiltIn) return 1;

      final usageComparison = b.useCount.compareTo(a.useCount);
      if (usageComparison != 0) return usageComparison;

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return templates;
  }

  @override
  Future<FolderTemplate?> getTemplateById(String id) async {
    if (_templatesBox == null) await init();
    return _templatesBox!.get(id);
  }

  @override
  Future<void> createTemplate(FolderTemplate template) async {
    if (_templatesBox == null) await init();
    await _templatesBox!.put(template.id, template);
  }

  @override
  Future<void> updateTemplate(FolderTemplate template) async {
    if (_templatesBox == null) await init();
    final updatedTemplate = template.copyWith(updatedAt: DateTime.now());
    await _templatesBox!.put(template.id, updatedTemplate);
  }

  @override
  Future<bool> deleteTemplate(String id) async {
    if (_templatesBox == null) await init();
    final template = await getTemplateById(id);

    // Only allow deletion of custom templates
    if (template != null && !template.isBuiltIn) {
      await _templatesBox!.delete(id);
      return true;
    }
    return false;
  }

  @override
  Future<List<FolderTemplate>> getBuiltInTemplates() async {
    final allTemplates = await getAllTemplates();
    return allTemplates.where((template) => template.isBuiltIn).toList();
  }

  @override
  Future<List<FolderTemplate>> getCustomTemplates() async {
    final allTemplates = await getAllTemplates();
    return allTemplates.where((template) => !template.isBuiltIn).toList();
  }

  @override
  Future<List<FolderTemplate>> searchTemplates(String query) async {
    final allTemplates = await getAllTemplates();
    final lowercaseQuery = query.toLowerCase();

    return allTemplates.where((template) {
      final nameMatch = template.name.toLowerCase().contains(lowercaseQuery);
      final descriptionMatch =
          template.description?.toLowerCase().contains(lowercaseQuery) ?? false;
      final keywordMatch = template.keywords.any(
        (keyword) => keyword.toLowerCase().contains(lowercaseQuery),
      );
      return nameMatch || descriptionMatch || keywordMatch;
    }).toList();
  }

  @override
  Future<List<FolderTemplate>> suggestTemplatesForFolder(
    String folderName,
  ) async {
    final allTemplates = await getAllTemplates();
    final lowercaseName = folderName.toLowerCase();

    // Find templates with matching keywords
    final suggestions = allTemplates.where((template) {
      return template.keywords.any(
        (keyword) => lowercaseName.contains(keyword.toLowerCase()),
      );
    }).toList();

    // Sort by relevance (more keyword matches = higher relevance)
    suggestions.sort((a, b) {
      final aMatches = a.keywords
          .where((keyword) => lowercaseName.contains(keyword.toLowerCase()))
          .length;
      final bMatches = b.keywords
          .where((keyword) => lowercaseName.contains(keyword.toLowerCase()))
          .length;
      final matchComparison = bMatches.compareTo(aMatches);

      if (matchComparison != 0) return matchComparison;
      return b.useCount.compareTo(a.useCount); // Then by usage
    });

    return suggestions.take(3).toList(); // Top 3 suggestions
  }

  @override
  Future<FolderTemplate> createTemplateFromFolder(
    String folderId,
    String templateName,
  ) async {
    // Get folder and its todos
    await StorageService.waitTodosReady();
    final todos = await StorageService.getAllTodosAsync();
    final folderTodos = todos
        .where((todo) => todo.folderId == folderId)
        .toList();

    // Sort todos by creation order or custom order
    folderTodos.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Convert todos to task templates
    final taskTemplates = folderTodos.asMap().entries.map((entry) {
      final index = entry.key;
      final todo = entry.value;

      return TaskTemplate(
        text: todo.text,
        priority: todo.priority,
        tags: todo.tags,
        notes: todo.notes,
        sortOrder: index,
        // Don't copy due dates as they're specific to the original folder
        reminderOffsets: todo.reminderOffsetsMinutes,
      );
    }).toList();

    // Create template
    final template = FolderTemplate(
      name: templateName,
      description: 'Template created from folder',
      keywords: _extractKeywordsFromName(templateName),
      taskTemplates: taskTemplates,
      isBuiltIn: false,
    );

    await createTemplate(template);
    return template;
  }

  @override
  Future<void> incrementTemplateUsage(String templateId) async {
    final template = await getTemplateById(templateId);
    if (template != null) {
      final updatedTemplate = template.copyWith(
        useCount: template.useCount + 1,
        updatedAt: DateTime.now(),
      );
      await updateTemplate(updatedTemplate);
    }
  }

  @override
  Future<List<FolderTemplate>> getMostUsedTemplates(int limit) async {
    final allTemplates = await getAllTemplates();
    final usedTemplates = allTemplates
        .where((template) => template.useCount > 0)
        .toList();
    usedTemplates.sort((a, b) => b.useCount.compareTo(a.useCount));
    return usedTemplates.take(limit).toList();
  }

  @override
  Future<void> resetBuiltInTemplate(String templateId) async {
    final template = await getTemplateById(templateId);
    if (template != null && template.isBuiltIn && template.isCustomized) {
      // Find original built-in template definition and restore it
      final originalTemplate = _getOriginalBuiltInTemplate(templateId);
      if (originalTemplate != null) {
        final restoredTemplate = originalTemplate.copyWith(
          id: templateId,
          useCount: template.useCount, // Keep usage stats
        );
        await updateTemplate(restoredTemplate);
      }
    }
  }

  /// Create built-in templates if they don't exist
  Future<void> _createBuiltInTemplatesIfNeeded() async {
    final existingTemplates = _templatesBox!.values.toList();

    if (existingTemplates.isEmpty ||
        !existingTemplates.any((t) => t.isBuiltIn)) {
      await _createBuiltInTemplates();
    }
  }

  /// Create the default built-in templates
  Future<void> _createBuiltInTemplates() async {
    final builtInTemplates = [
      // Project Management Template
      FolderTemplate(
        name: '项目工作流',
        description: '标准项目管理流程',
        keywords: ['项目', '客户', '开发', '工作', '构建'],
        isBuiltIn: true,
        taskTemplates: [
          TaskTemplate(
            text: '项目调研与规划',
            priority: 'high',
            sortOrder: 0,
            estimatedMinutes: 120,
          ),
          TaskTemplate(
            text: '需求收集',
            priority: 'high',
            sortOrder: 1,
            estimatedMinutes: 90,
          ),
          TaskTemplate(
            text: '制定时间表与里程碑',
            priority: 'high',
            sortOrder: 2,
            estimatedMinutes: 60,
          ),
          TaskTemplate(
            text: '设计与架构',
            priority: 'medium',
            sortOrder: 3,
            estimatedMinutes: 180,
          ),
          TaskTemplate(
            text: '实现阶段',
            priority: 'high',
            sortOrder: 4,
            estimatedMinutes: 480,
          ),
          TaskTemplate(
            text: '测试与质量保证',
            priority: 'high',
            sortOrder: 5,
            estimatedMinutes: 120,
          ),
          TaskTemplate(
            text: '客户评审与反馈',
            priority: 'medium',
            sortOrder: 6,
            estimatedMinutes: 60,
          ),
          TaskTemplate(
            text: '最终交付与文档',
            priority: 'high',
            sortOrder: 7,
            estimatedMinutes: 90,
          ),
        ],
      ),

      // Shopping Template
      FolderTemplate(
        name: '购物清单',
        description: '有序的购物流程',
        keywords: ['购物', '杂货', '商店', '购买', '采购'],
        isBuiltIn: true,
        taskTemplates: [
          TaskTemplate(
            text: '检查储物柜并列出清单',
            priority: 'high',
            sortOrder: 0,
            estimatedMinutes: 15,
          ),
          TaskTemplate(
            text: '查看每周促销广告',
            priority: 'low',
            sortOrder: 1,
            estimatedMinutes: 10,
          ),
          TaskTemplate(
            text: '去超市采购',
            priority: 'high',
            sortOrder: 2,
            estimatedMinutes: 45,
          ),
          TaskTemplate(
            text: '药店取药',
            priority: 'medium',
            sortOrder: 3,
            estimatedMinutes: 10,
          ),
          TaskTemplate(
            text: '整理收纳',
            priority: 'medium',
            sortOrder: 4,
            estimatedMinutes: 15,
          ),
        ],
      ),

      // Travel Planning Template
      FolderTemplate(
        name: '旅行计划',
        description: '完整的旅行准备流程',
        keywords: ['旅行', '出行', '度假', '假期', '航班'],
        isBuiltIn: true,
        taskTemplates: [
          TaskTemplate(
            text: '研究目的地与活动',
            priority: 'high',
            sortOrder: 0,
            estimatedMinutes: 120,
            dueDateOffset: -30,
          ),
          TaskTemplate(
            text: '预订机票',
            priority: 'high',
            sortOrder: 1,
            estimatedMinutes: 30,
            dueDateOffset: -21,
          ),
          TaskTemplate(
            text: '查找并预订住宿',
            priority: 'high',
            sortOrder: 2,
            estimatedMinutes: 45,
            dueDateOffset: -21,
          ),
          TaskTemplate(
            text: '规划每日行程',
            priority: 'medium',
            sortOrder: 3,
            estimatedMinutes: 90,
            dueDateOffset: -14,
          ),
          TaskTemplate(
            text: '检查护照与证件',
            priority: 'high',
            sortOrder: 4,
            estimatedMinutes: 15,
            dueDateOffset: -14,
          ),
          TaskTemplate(
            text: '打包行李',
            priority: 'high',
            sortOrder: 5,
            estimatedMinutes: 60,
            dueDateOffset: -1,
          ),
          TaskTemplate(
            text: '在线值机',
            priority: 'medium',
            sortOrder: 6,
            estimatedMinutes: 10,
            dueDateOffset: -1,
          ),
        ],
      ),

      // Home Maintenance Template
      FolderTemplate(
        name: '家居维护',
        description: '季节性家居维护清单',
        keywords: [
          '家居',
          '房屋',
          '维护',
          '维修',
          '清洁',
          '季节性',
        ],
        isBuiltIn: true,
        taskTemplates: [
          TaskTemplate(
            text: '检查并更换空气滤网',
            priority: 'high',
            sortOrder: 0,
            estimatedMinutes: 15,
          ),
          TaskTemplate(
            text: '清理排水沟',
            priority: 'medium',
            sortOrder: 1,
            estimatedMinutes: 120,
          ),
          TaskTemplate(
            text: '测试烟雾与一氧化碳探测器',
            priority: 'high',
            sortOrder: 2,
            estimatedMinutes: 20,
          ),
          TaskTemplate(
            text: '深度清洁地毯/地板',
            priority: 'medium',
            sortOrder: 3,
            estimatedMinutes: 180,
          ),
          TaskTemplate(
            text: '检查并密封窗户',
            priority: 'medium',
            sortOrder: 4,
            estimatedMinutes: 60,
          ),
          TaskTemplate(
            text: '维护暖通空调系统',
            priority: 'high',
            sortOrder: 5,
            estimatedMinutes: 90,
          ),
        ],
      ),

      // Event Planning Template
      FolderTemplate(
        name: '活动策划',
        description: '通用活动组织流程',
        keywords: [
          '活动',
          '派对',
          '生日',
          '婚礼',
          '庆典',
          '聚会',
        ],
        isBuiltIn: true,
        taskTemplates: [
          TaskTemplate(
            text: '确定日期并创建宾客名单',
            priority: 'high',
            sortOrder: 0,
            estimatedMinutes: 30,
            dueDateOffset: -21,
          ),
          TaskTemplate(
            text: '发送邀请函',
            priority: 'high',
            sortOrder: 1,
            estimatedMinutes: 45,
            dueDateOffset: -14,
          ),
          TaskTemplate(
            text: '规划菜单并预订餐饮',
            priority: 'high',
            sortOrder: 2,
            estimatedMinutes: 60,
            dueDateOffset: -7,
          ),
          TaskTemplate(
            text: '购买装饰与用品',
            priority: 'medium',
            sortOrder: 3,
            estimatedMinutes: 90,
            dueDateOffset: -3,
          ),
          TaskTemplate(
            text: '布置场地',
            priority: 'high',
            sortOrder: 4,
            estimatedMinutes: 120,
            dueDateOffset: -1,
          ),
          TaskTemplate(
            text: '当天协调',
            priority: 'high',
            sortOrder: 5,
            estimatedMinutes: 60,
          ),
          TaskTemplate(
            text: '清理并向宾客致谢',
            priority: 'medium',
            sortOrder: 6,
            estimatedMinutes: 90,
            dueDateOffset: 1,
          ),
        ],
      ),
    ];

    for (final template in builtInTemplates) {
      await createTemplate(template);
    }
  }

  /// Extract keywords from template name for searching
  List<String> _extractKeywordsFromName(String name) {
    final words = name.toLowerCase().split(RegExp(r'[\s\-_]+'));
    return words.where((word) => word.length > 2).toList();
  }

  /// Get original built-in template definition (for reset functionality)
  FolderTemplate? _getOriginalBuiltInTemplate(String templateId) {
    // This would contain the original definitions of built-in templates
    // In a real implementation, you'd store these separately or have a reset mechanism
    // For now, return null as this is a complex feature
    return null;
  }
}
