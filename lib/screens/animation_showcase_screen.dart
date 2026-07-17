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
import '../utils/animations.dart';
import '../utils/animated_navigation.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/common/common.dart';

/// Animation Showcase Screen
/// Demonstrates all Material Design 3 animations implemented in the app
class AnimationShowcaseScreen extends StatefulWidget {
  const AnimationShowcaseScreen({super.key});

  @override
  State<AnimationShowcaseScreen> createState() =>
      _AnimationShowcaseScreenState();
}

class _AnimationShowcaseScreenState extends State<AnimationShowcaseScreen>
    with TickerProviderStateMixin {
  bool _fabVisible = true;
  bool _expanded = false;
  bool _chipsSelected = false;
  bool _switchValue = false;
  bool _loading = false;
  int _counter = 0;
  double _progress = 0.3;
  bool _showContent = true;

  late AnimationController _listController;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      duration: AppAnimations.durationLong2,
      vsync: this,
    );
    _listController.forward();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('动画展示'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section: Navigation Transitions
          _buildSection(
            title: '导航过渡动画',
            children: [
              _buildButton(
                '共享轴过渡',
                () => AnimatedNavigation.push(
                  context,
                  const _DemoScreen(title: '共享轴'),
                ),
              ),
              const SizedBox(height: 8),
              _buildButton(
                '淡入淡出过渡',
                () => AnimatedNavigation.pushFadeThrough(
                  context,
                  const _DemoScreen(title: '淡入淡出'),
                ),
              ),
              const SizedBox(height: 8),
              _buildButton(
                '容器变换',
                () => AnimatedNavigation.pushContainerTransform(
                  context,
                  const _DemoScreen(title: '容器变换'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Dialogs & Sheets
          _buildSection(
            title: '对话框和底部面板',
            children: [
              _buildButton(
                '动画对话框',
                () => AnimatedDialog.show(
                  context: context,
                  child: AlertDialog(
                    title: const Text('动画对话框'),
                    content: const Text(
                      '此对话框以平滑的淡入和缩放动画出现。',
                    ),
                    actions: [
                      ExpressiveTextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('关闭'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildButton(
                '动画底部面板',
                () => AnimatedBottomSheet.show(
                  context: context,
                  isScrollControlled: true,
                  child: Container(
                    height: 400,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.4,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Text(
                          '底部面板',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '此底部面板以平滑动画向上滑出。',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Snackbars
          _buildSection(
            title: '提示条',
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildButton(
                      '成功',
                      () => AnimatedSnackbar.success(
                        context,
                        message: '任务完成！',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildButton(
                      '错误',
                      () => AnimatedSnackbar.error(
                        context,
                        message: '保存失败',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildButton(
                      '信息',
                      () => AnimatedSnackbar.info(
                        context,
                        message: '同步中',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildButton(
                      '警告',
                      () => AnimatedSnackbar.warning(
                        context,
                        message: '存储空间几乎已满',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Animated Widgets
          _buildSection(
            title: '动画浮动按钮',
            children: [
              Center(
                child: AnimatedFAB(
                  visible: _fabVisible,
                  icon: const Icon(Icons.add),
                  label: '添加任务',
                  onPressed: () {
                    AnimatedSnackbar.info(context, message: '浮动按钮已按下！');
                  },
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ExpressiveElevatedButton(
                  onPressed: () => setState(() => _fabVisible = !_fabVisible),
                  child: Text(_fabVisible ? '隐藏浮动按钮' : '显示浮动按钮'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Animated Card
          _buildSection(
            title: '动画卡片',
            children: [
              AnimatedCard(
                onTap: () {
                  AnimatedSnackbar.info(context, message: '卡片已点击！');
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '交互式卡片',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text('点击此卡片查看按压动画。'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Animated Chips
          _buildSection(
            title: '动画标签',
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AnimatedChip(
                    label: '高优先级',
                    icon: Icons.priority_high,
                    selected: _chipsSelected,
                    onTap: () =>
                        setState(() => _chipsSelected = !_chipsSelected),
                  ),
                  AnimatedChip(
                    label: '工作',
                    icon: Icons.work,
                    selected: !_chipsSelected,
                    onTap: () =>
                        setState(() => _chipsSelected = !_chipsSelected),
                  ),
                  AnimatedChip(
                    label: '个人',
                    icon: Icons.person,
                    selected: false,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Counters and Progress
          _buildSection(
            title: '动画计数器和进度条',
            children: [
              Center(
                child: AnimatedCounter(
                  value: _counter,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExpressiveElevatedButton(
                    onPressed: () => setState(() => _counter++),
                    child: const Text('增加'),
                  ),
                  const SizedBox(width: 8),
                  ExpressiveOutlinedButton(
                    onPressed: () => setState(
                      () => _counter = (_counter - 1) < 0 ? 0 : _counter - 1,
                    ),
                    child: const Text('减少'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AnimatedProgressIndicator(
                value: _progress,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Slider(
                value: _progress,
                onChanged: (value) => setState(() => _progress = value),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Animated Text
          _buildSection(
            title: '动画文本',
            children: [
              Center(
                child: AnimatedText(
                  text: _switchValue ? '已启用' : '已禁用',
                  style: theme.textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('切换：'),
                    AnimatedSwitch(
                      value: _switchValue,
                      onChanged: (value) =>
                          setState(() => _switchValue = value),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Expandable Container
          _buildSection(
            title: '可展开容器',
            children: [
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('可展开区域'),
                      trailing: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                      ),
                      onTap: () => setState(() => _expanded = !_expanded),
                    ),
                    ExpandableContainer(
                      expanded: _expanded,
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          '此内容以淡入和大小变化动画平滑展开和折叠。',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Loading Indicator
          _buildSection(
            title: '动画加载',
            children: [
              Center(
                child: AnimatedLoadingIndicator(
                  loading: _loading,
                  size: 32,
                  child: const Icon(Icons.check_circle, size: 32),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ExpressiveElevatedButton(
                  onPressed: () => setState(() => _loading = !_loading),
                  child: Text(_loading ? '隐藏加载' : '显示加载'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Visibility Toggle
          _buildSection(
            title: '动画可见性',
            children: [
              AnimatedVisibility(
                visible: _showContent,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.info, size: 48),
                        const SizedBox(height: 8),
                        Text('内容', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        const Text(
                          '此内容平滑地淡入淡出和滑入滑出。',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ExpressiveElevatedButton(
                  onPressed: () => setState(() => _showContent = !_showContent),
                  child: Text(_showContent ? '隐藏内容' : '显示内容'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Staggered List
          _buildSection(
            title: '交错列表动画',
            children: [
              const Text(
                '项目以交错时间出现：',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              ...List.generate(
                5,
                (index) => StaggeredListAnimation(
                  index: index,
                  animation: _listController,
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text('列表项 ${index + 1}'),
                      subtitle: const Text('交错动画'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ExpressiveElevatedButton(
                  onPressed: () {
                    _listController.reset();
                    _listController.forward();
                  },
                  child: const Text('重播动画'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Shimmer Loading
          _buildSection(
            title: '闪烁加载效果',
            children: [
              ShimmerLoading(
                child: Column(
                  children: [
                    Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 20,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 20,
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildButton(String label, VoidCallback onPressed) {
    return FilledButton.tonal(onPressed: onPressed, child: Text(label));
  }
}

/// Demo screen for navigation transitions
class _DemoScreen extends StatelessWidget {
  final String title;

  const _DemoScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              '您通过以下方式导航：',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}
