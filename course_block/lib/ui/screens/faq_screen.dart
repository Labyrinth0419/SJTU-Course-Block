import 'package:flutter/material.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final List<_FaqItem> _items = [
    _FaqItem(header: '如何更新课表？', body: '打开“同步课表”页面，输入学年学期并点击同步即可。也可以手动添加课程。'),
    _FaqItem(
      header: '桌面组件不刷新怎么办？',
      body: '尝试在应用内进入设置界面，然后再次回到首页，这会触发刷新。如果仍无效，可重启设备。',
    ),
    _FaqItem(
      header: '如何备份/恢复数据？',
      body: '在设置中使用导出功能生成 JSON 文件；使用导入功能可恢复之前备份的课表。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('帮助与反馈')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: ExpansionPanelList.radio(
                children: _items
                    .map(
                      (item) => ExpansionPanelRadio(
                        value: item.header,
                        headerBuilder: (context, isExpanded) {
                          return ListTile(title: Text(item.header));
                        },
                        body: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Text(item.body),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('检查更新'),
            onTap: () {
              debugPrint('检查更新 tapped');
            },
          ),
          ListTile(
            title: const Text('提交问题反馈'),
            onTap: () {
              debugPrint('提交问题反馈 tapped');
            },
          ),
          const SizedBox(height: 20),
          const Center(child: Text('当前版本: v1.0.0 (占位)')),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _FaqItem {
  final String header;
  final String body;
  _FaqItem({required this.header, required this.body});
}
