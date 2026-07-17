<p align="center">
  <img src="assets/icon/2.png" alt="App Icon" width="200" height="200">
</p>

<h1 align="center">Trudido 中文版</h1>

<p align="center">简洁的任务管理 · 安全的笔记存储 · 隐私优先</p>

<p align="center">
  <a href="https://github.com/DWZ753/trudido">
    <img src="https://img.shields.io/badge/汉化版本-v1.3.5--zh-blue?style=for-the-badge" alt="Version"></a>
  <a href="https://github.com/DWZ753/trudido/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/DWZ753/trudido?style=for-the-badge&color=blue" alt="License"></a>
</p>

---

## 关于此版本

本仓库是 [Trudido](https://github.com/dominikmuellr/trudido) 的**简体中文汉化版**。

原项目由 Dominik Müller 开发，采用 GPL-3.0 协议开源。本汉化版沿用相同协议。

### 汉化内容

- 全部 UI 界面翻译为简体中文
- 日期时间格式中文化（`7月17日`、`上午/下午`）
- 材料设计（Material 3）组件中文化（日期选择器、对话框等）
- Android 原生层中文化（通知、小部件、Toast 消息）
- 默认文件夹分类与模板翻译为中文

---

## 安装

### 从 Release 下载 APK

前往 [Releases 页面](../../releases) 下载最新的 APK 文件，直接安装即可。

### 自行构建

```bash
# 克隆仓库
git clone https://github.com/DWZ753/trudido.git
cd trudido

# 安装依赖
flutter pub get

# 构建 Debug APK
flutter build apk --debug
```

---

## 功能特性

### 📋 任务管理
- 智能任务创建：标题、备注、截止日期和时间、优先级
- 用文件夹组织任务（支持颜色/图标）
- 重复任务：每天/每周/每月 + 自定义模式
- 多日任务（开始日期 → 截止日期）
- 提醒功能，支持多个提醒时间
- 多种视图：列表 + 日历（月/双周/周/日）
- 高级筛选、排序和搜索
- 快速操作：滑动操作、多选、批量处理

### 📝 笔记
- Markdown 笔记，支持实时预览 + 格式化辅助
- 富文本编辑器（所见即所得），支持媒体（图片/音频/视频）
- 置顶笔记、在文件夹间移动、管理笔记集
- 导出笔记（PDF / Markdown）

### 🔐 保险库（加密笔记）
- 将笔记文件夹锁定为 AES-256 加密保险库
- 用密码/PIN 和生物识别解锁

### 🗂️ 文件夹模板
- 内置模板，快速创建含预设工作流的任务文件夹
- 自定义模板

### 💾 备份与数据所有权
- 导出/导入完整应用数据（JSON）
- 导出全部内容为 PDF
- 导入/导出笔记为 Markdown
- 自动备份 + 从备份恢复

### 📅 日历同步
- 可选同步设备日历（导入/导出）
- 日历诊断和选择性同步

### 🎨 设计与定制
- Material 3 界面
- 动态取色（Material You，Android 12+）
- 浅色/深色模式 + 自定义主题色
- 紧凑布局 + 高对比度选项

### 🔒 隐私
- **默认 100% 离线** — 数据仅存储在您的设备上
- 无追踪、无广告、无分析
- 完全控制数据：导入/导出和备份
- 应用锁（PIN + 生物识别）

---

## 协议

本项目沿用原项目的 **GNU General Public License v3.0 (GPL-3.0)** 协议。

您可以自由使用、修改和分发此软件，但必须以相同协议发布。详见 [LICENSE](LICENSE)。

---

## 致谢

原始项目：[Trudido](https://github.com/dominikmuellr/trudido) by [Dominik Müller](https://github.com/dominikmuellr)
