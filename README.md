# SJTU CourseBlock

本仓库使用 Dart/Flutter 构建跨平台客户端，重点兼容上海交通大学（SJTU）的教务系统。

---

## 🚀 项目概述

- **目标平台**: Android、iOS（桌面/Web 为未来扩展）
- **核心功能**:
  - 教务系统登录（本科/研生）
  - 课表导入与解析
  - 可视化周视图课表
  - 手动课程管理
  - ICS/JSON/CSV 导入导出
  - Android 桌面小部件（正在开发）
  - 多种设置和帮助页面

---

## 📁 仓库结构

```
.
├── course_block/          # Flutter 主工程
│   ├── lib/               # 应用源码
│   ├── android/           # Android 原生项目
│   ├── ios/               # iOS 原生项目
│   ├── example/           # Android 桌面小部件的示例工程
│   └── test/              # 单元/集成测试
├── assets/                # 构建脚本及资源
└── README.md              # 本文档（根目录）
```

---

## 🛠 开发环境

1. 安装 [Flutter SDK](https://flutter.dev/docs/get-started/install)。
2. 确保已配置 Android/iOS 开发环境。
3. 在Windows下建议使用 PowerShell：
   ```powershell
   cd D:\Desktop\WorkSpace\SJTUCourseBlock\course_block
   flutter pub get
   ```
4. 配置模拟器或真机。

> 若首次运行项目需执行 `flutter clean` 并重启 IDE。

---

## ✅ 功能实现状态

主要功能可参考 `plan.md` 中的勾选列表。当前已完成：

- 登录界面与 Cookie 持久化
- EAS课表解析（JSON与HTML兼容）
- 核心 `ScheduleView` 课表组件
- 课程的增删改查与详情
- ICS/JSON/CSV 导入导出
- 设置页部分项

进度中或待办：

- Android 桌面小部件（`home_widget` 集成）
- 高级设置与 FAQ 页面
- iOS 文件保存优化
- 单元/集成测试补充

---

## 📦 构建与运行

```bash
cd course_block
# 获取依赖
flutter pub get
# Android 调试
flutter run -d emulator-5554
# iOS 调试
flutter run -d ios

# 生成发布 APK
flutter build apk --release
# 生成 iOS Release
flutter build ios --release
```

**示例工程**（桌面小部件）位于 `course_block/example/CourseBlock`，可单独打开并运行以调试原生 Widget 逻辑。

---

## 📘 使用说明

1. 通过“导入”菜单选择“教务系统登录”或从本地备份导入课表。
2. 登录后课程数据会自动解析并存入数据库。
3. 主界面滑动切换周次，点击课程查看详情/编辑/删除。
4. 导出功能支持将当前课表生成 `.ics` 或 JSON 文件，便于备份或共享。
5. 设置页可调整周起始、是否显示周末等选项。

> 有问题请查看 `doc/` 下的相应页面或本仓库的 `faqs.html`。

---

## 🧩 开发与参考

- `course_block/lib/`：模块划分及关键类描述。

可通过阅读这些文件了解各功能的设计思路。

---

## 🛡 测试

主要依赖 Flutter 测试框架，现有测试位于 `course_block/test`。运行：

```bash
flutter test
```

---

## 📄 许可证

该项目基于 MIT 许可，更多信息见 `LICENSE` 文件。

---

## 💡 贡献与交流

欢迎提交 issue 和 pull request。若你正在开发相关功能或发现 bug，请优先在 issue 中讨论。

*开发者*: Labyrinth
*特别鸣谢*： Dujiajun

---

感谢使用与贡献，希望本项目能为 SJTU 同学的课程管理提供便利！