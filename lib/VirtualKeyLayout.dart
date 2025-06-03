import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

/// 普通虚拟按键配置
class VirtualKeyConfig {
  final String key;
  Offset position;
  Size size;

  VirtualKeyConfig({
    required this.key,
    required this.position,
    required this.size,
  });

  VirtualKeyConfig copy() {
    return VirtualKeyConfig(
      key: key,
      position: position,
      size: size,
    );
  }

  //转为json
  Map<String, dynamic> toJson() => {
    'key': key,
    'x': position.dx,
    'y': position.dy,
    'width': size.width,
    'height': size.height,
  };
  //由json转为结构体
  factory VirtualKeyConfig.fromJson(Map<String, dynamic> json) {
    return VirtualKeyConfig(
      key: json['key'] as String,
      position: Offset(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      ),
      size: Size(
        (json['width'] as num).toDouble(),
        (json['height'] as num).toDouble(),
      ),
    );
  }
}

/// 摇杆占位：记录圆心和边长
class JoystickPlaceholder {
  Offset position;
  double size;

  JoystickPlaceholder({
    required this.position,
    required this.size,
  });

  JoystickPlaceholder copy() {
    return JoystickPlaceholder(position: position, size: size);
  }

  //转json
  Map<String, dynamic> toJson() => {
    'x': position.dx,
    'y': position.dy,
    'size': size,
  };

  //由json转为结构体
  factory JoystickPlaceholder.fromJson(Map<String, dynamic> json) {
    return JoystickPlaceholder(
      position: Offset(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      ),
      size: (json['size'] as num).toDouble(),
    );
  }
}

/// 全局：从预设键盘中选择一个按键
Future<String?> pickKeyDialog(BuildContext context) {
  const List<List<String>> _keyboardLayout = [
    ['Esc', 'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12'],
    ['`', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 'Backspace'],
    ['Tab', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '[', ']', '\\'],
    ['Caps', 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ';', '\'', 'Enter'],
    ['Shift', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', ',', '.', '/', 'Shift'],
    ['Ctrl', 'Alt', 'Space', 'Alt', 'Ctrl'],
  ];

  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.grey[900],
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '选择一个按键',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: _keyboardLayout.map((row) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: row.map((keyLabel) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[700],
                                    minimumSize: const Size(60, 40),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).pop(keyLabel);
                                  },
                                  child: Text(
                                    keyLabel,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 全局：修改布局名称对话框
Future<String?> renameDialog(BuildContext context, String initialName) {
  final controller = TextEditingController(text: initialName);
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.grey[900],
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: '布局名称',
                    labelStyle: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消', style: TextStyle(color: Colors.white)),
                    ),
                    TextButton(
                      onPressed: () {
                        final newName = controller.text.trim();
                        if (newName.isNotEmpty) {
                          Navigator.pop(context, newName);
                        }
                      },
                      child: const Text('确定', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// 全局：修改按键大小对话框
Future<Size?> sizeInputDialog(
    BuildContext context, double initialW, double initialH) {
  final widthController = TextEditingController(text: initialW.toInt().toString());
  final heightController = TextEditingController(text: initialH.toInt().toString());

  return showDialog<Size>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.grey[900],
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: widthController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: '宽度(px)',
                    labelStyle: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: heightController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: '高度(px)',
                    labelStyle: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消', style: TextStyle(color: Colors.white)),
                    ),
                    TextButton(
                      onPressed: () {
                        final newW = double.tryParse(widthController.text) ?? initialW;
                        final newH = double.tryParse(heightController.text) ?? initialH;
                        Navigator.pop(context, Size(newW, newH));
                      },
                      child: const Text('确定', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// 全局：修改摇杆大小对话框
Future<double?> joystickSizeInputDialog(BuildContext context, double initial) {
  final sizeController = TextEditingController(text: initial.toInt().toString());

  return showDialog<double>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.grey[900],
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: sizeController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: '边长(px)',
                    labelStyle: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消', style: TextStyle(color: Colors.white)),
                    ),
                    TextButton(
                      onPressed: () {
                        final newSize = double.tryParse(sizeController.text) ?? initial;
                        Navigator.pop(context, newSize);
                      },
                      child: const Text('确定', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// 编辑布局页面
///
/// 接收当前布局名称、已有布局名称列表（用于检查重名）、以及按键和摇杆初始配置。
class LayoutEditorPage extends StatefulWidget {
  final String layoutName;
  final List<String> existingNames;
  final List<VirtualKeyConfig> initialKeyConfig;
  final List<JoystickPlaceholder> initialJoystickPlaceholder;

  const LayoutEditorPage({
    Key? key,
    required this.layoutName,
    required this.existingNames,
    required this.initialKeyConfig,
    required this.initialJoystickPlaceholder,
  }) : super(key: key);

  @override
  State<LayoutEditorPage> createState() => _LayoutEditorPageState();
}

class _LayoutEditorPageState extends State<LayoutEditorPage> {
  late List<VirtualKeyConfig> _editingKeyConfig;
  late List<JoystickPlaceholder> _editingJoystickPlaceholder;
  late String _currentName;

  @override
  void initState() {
    super.initState();
    _editingKeyConfig = widget.initialKeyConfig.map((e) => e.copy()).toList();
    _editingJoystickPlaceholder =
        widget.initialJoystickPlaceholder.map((e) => e.copy()).toList();
    _currentName = widget.layoutName;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final screenH = media.size.height;

    return Scaffold(
      body: Stack(
        children: [
          Container(color: Colors.grey[900]),

          // 普通按键：全屏拖拽；点击调用 sizeInputDialog；长按删除
          ..._editingKeyConfig.asMap().entries.map((entry) {
            final idx = entry.key;
            final config = entry.value;
            return Positioned(
              left: config.position.dx,
              top: config.position.dy,
              width: config.size.width,
              height: config.size.height,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) {
                  setState(() {
                    final newPos = config.position + details.delta;
                    final clampedX =
                    newPos.dx.clamp(0.0, screenW - config.size.width);
                    final clampedY =
                    newPos.dy.clamp(0.0, screenH - config.size.height);
                    _editingKeyConfig[idx].position =
                        Offset(clampedX, clampedY);
                  });
                },
                onTap: () async {
                  final newSize = await sizeInputDialog(
                    context,
                    config.size.width,
                    config.size.height,
                  );
                  if (newSize != null) {
                    setState(() {
                      _editingKeyConfig[idx].size = newSize;
                    });
                  }
                },
                onLongPress: () {
                  setState(() {
                    _editingKeyConfig.removeAt(idx);
                  });
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.6),
                    border: Border.all(color: Colors.white),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    config.key,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            );
          }).toList(),

          // 摇杆：全屏拖拽；点击调用 joystickSizeInputDialog；长按删除
          ..._editingJoystickPlaceholder.asMap().entries.map((entry) {
            final idx = entry.key;
            final ph = entry.value;
            final half = ph.size / 2;
            return Positioned(
              left: ph.position.dx - half,
              top: ph.position.dy - half,
              width: ph.size,
              height: ph.size,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) {
                  setState(() {
                    final newCenter = ph.position + details.delta;
                    final clampedX =
                    newCenter.dx.clamp(ph.size / 2, screenW - ph.size / 2);
                    final clampedY =
                    newCenter.dy.clamp(ph.size / 2, screenH - ph.size / 2);
                    _editingJoystickPlaceholder[idx].position =
                        Offset(clampedX, clampedY);
                  });
                },
                onTap: () async {
                  final newSize =
                  await joystickSizeInputDialog(context, ph.size);
                  if (newSize != null) {
                    setState(() {
                      _editingJoystickPlaceholder[idx].size = newSize;
                    });
                  }
                },
                onLongPress: () {
                  setState(() {
                    _editingJoystickPlaceholder.removeAt(idx);
                  });
                },
                child: Joystick(listener: (_) {}),
              ),
            );
          }).toList(),

          // 顶部布局名称（右上角）
          Positioned(
            top: 40,
            right: 16,
            child: Text(
              _currentName.isEmpty ? '未命名' : _currentName,
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),

          // 顶部中央：五个悬浮按钮（不在容器中）
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Wrap(
                spacing: 12,
                children: [
                  // 添加按键
                  FloatingActionButton(
                    heroTag: 'addKeyEdit',
                    tooltip: '添加按键',
                    backgroundColor: Colors.blueGrey,
                    onPressed: () async {
                      final selected = await pickKeyDialog(context);
                      if (selected != null) {
                        final center = Offset(
                          (screenW - 60) / 2,
                          (screenH - 160) / 2,
                        );
                        setState(() {
                          _editingKeyConfig.add(
                            VirtualKeyConfig(
                              key: selected,
                              position: center,
                              size: const Size(60, 60),
                            ),
                          );
                        });
                      }
                    },
                    child: const Icon(Icons.keyboard, color: Colors.white),
                  ),

                  // 添加摇杆（限一个）
                  FloatingActionButton(
                    heroTag: 'addJoyEdit',
                    tooltip: '添加摇杆',
                    backgroundColor: _editingJoystickPlaceholder.isEmpty
                        ? Colors.blueGrey
                        : Colors.grey[800],
                    onPressed: _editingJoystickPlaceholder.isEmpty
                        ? () {
                      final center = Offset(screenW / 2, (screenH - 160) / 2);
                      setState(() {
                        _editingJoystickPlaceholder.add(
                          JoystickPlaceholder(position: center, size: 100.0),
                        );
                      });
                    }
                        : null,
                    child: const Icon(Icons.gamepad, color: Colors.white),
                  ),

                  // 重命名
                  FloatingActionButton(
                    heroTag: 'renameEdit',
                    tooltip: '重命名',
                    backgroundColor: Colors.orange[700],
                    onPressed: () async {
                      final newName = await renameDialog(context, _currentName);
                      if (newName != null) {
                        // 检查重名（编辑时允许保持原名）
                        final others = widget.existingNames
                            .where((n) => n != widget.layoutName)
                            .toList();
                        if (others.contains(newName)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('布局名称重复，无法重命名')),
                          );
                        } else {
                          setState(() {
                            _currentName = newName;
                          });
                        }
                      }
                    },
                    child: const Icon(Icons.edit, color: Colors.white),
                  ),

                  // 返回
                  FloatingActionButton(
                    heroTag: 'goBackEdit',
                    tooltip: '返回',
                    backgroundColor: Colors.grey[700],
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),

                  // 保存
                  FloatingActionButton(
                    heroTag: 'saveEdit',
                    tooltip: '保存',
                    backgroundColor: Colors.blue[700],
                    onPressed: () {
                      // 最终保存时也检查重名
                      final others = widget.existingNames
                          .where((n) => n != widget.layoutName)
                          .toList();
                      if (_currentName.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请先命名布局')),
                        );
                        return;
                      }
                      if (others.contains(_currentName)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('布局名称重复，无法保存')),
                        );
                        return;
                      }
                      Navigator.pop(context, {
                        'name': _currentName,
                        'keys': _editingKeyConfig,
                        'joysticks': _editingJoystickPlaceholder,
                      });
                    },
                    child: const Icon(Icons.save, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 创建新布局页面
///
/// 接收已有布局名称列表（用于检查重名）。
class LayoutCreatePage extends StatefulWidget {
  final List<String> existingNames;

  const LayoutCreatePage({
    Key? key,
    required this.existingNames,
  }) : super(key: key);

  @override
  State<LayoutCreatePage> createState() => _LayoutCreatePageState();
}

class _LayoutCreatePageState extends State<LayoutCreatePage> {
  final List<VirtualKeyConfig> _newKeyConfig = [];
  final List<JoystickPlaceholder> _newJoystickConfig = [];
  String _currentName = '';

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final screenH = media.size.height;

    return Scaffold(
      body: Stack(
        children: [
          Container(color: Colors.grey[900]),

          // 顶部布局名称（右上角）
          Positioned(
            top: 40,
            right: 16,
            child: Text(
              _currentName.isEmpty ? '未命名' : _currentName,
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),

          // 普通按键：全屏拖拽；点击调用 sizeInputDialog；长按删除
          ..._newKeyConfig.asMap().entries.map((entry) {
            final idx = entry.key;
            final config = entry.value;
            return Positioned(
              left: config.position.dx,
              top: config.position.dy,
              width: config.size.width,
              height: config.size.height,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) {
                  setState(() {
                    final newPos = config.position + details.delta;
                    final clampedX =
                    newPos.dx.clamp(0.0, screenW - config.size.width);
                    final clampedY =
                    newPos.dy.clamp(0.0, screenH - config.size.height);
                    _newKeyConfig[idx].position = Offset(clampedX, clampedY);
                  });
                },
                onTap: () async {
                  final newSize = await sizeInputDialog(
                    context,
                    config.size.width,
                    config.size.height,
                  );
                  if (newSize != null) {
                    setState(() {
                      _newKeyConfig[idx].size = newSize;
                    });
                  }
                },
                onLongPress: () {
                  setState(() {
                    _newKeyConfig.removeAt(idx);
                  });
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.6),
                    border: Border.all(color: Colors.white),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    config.key,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            );
          }).toList(),

          // 摇杆：全屏拖拽；点击调用 joystickSizeInputDialog；长按删除
          ..._newJoystickConfig.asMap().entries.map((entry) {
            final idx = entry.key;
            final ph = entry.value;
            final half = ph.size / 2;
            return Positioned(
              left: ph.position.dx - half,
              top: ph.position.dy - half,
              width: ph.size,
              height: ph.size,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) {
                  setState(() {
                    final newCenter = ph.position + details.delta;
                    final clampedX =
                    newCenter.dx.clamp(ph.size / 2, screenW - ph.size / 2);
                    final clampedY =
                    newCenter.dy.clamp(ph.size / 2, screenH - ph.size / 2);
                    _newJoystickConfig[idx].position =
                        Offset(clampedX, clampedY);
                  });
                },
                onTap: () async {
                  final newSize =
                  await joystickSizeInputDialog(context, ph.size);
                  if (newSize != null) {
                    setState(() {
                      _newJoystickConfig[idx].size = newSize;
                    });
                  }
                },
                onLongPress: () {
                  setState(() {
                    _newJoystickConfig.removeAt(idx);
                  });
                },
                child: Joystick(listener: (_) {}),
              ),
            );
          }).toList(),

          // 顶部中央：五个悬浮按钮（不在容器中）
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Wrap(
                spacing: 12,
                children: [
                  // 添加按键
                  FloatingActionButton(
                    heroTag: 'addKeyCreate',
                    tooltip: '添加按键',
                    backgroundColor: Colors.blueGrey,
                    onPressed: () async {
                      final selected = await pickKeyDialog(context);
                      if (selected != null) {
                        final center = Offset(
                          (screenW - 60) / 2,
                          (screenH - 160) / 2,
                        );
                        setState(() {
                          _newKeyConfig.add(
                            VirtualKeyConfig(
                              key: selected,
                              position: center,
                              size: const Size(60, 60),
                            ),
                          );
                        });
                      }
                    },
                    child: const Icon(Icons.keyboard, color: Colors.white),
                  ),

                  // 添加摇杆（限一个）
                  FloatingActionButton(
                    heroTag: 'addJoyCreate',
                    tooltip: '添加摇杆',
                    backgroundColor: _newJoystickConfig.isEmpty
                        ? Colors.blueGrey
                        : Colors.grey[800],
                    onPressed: _newJoystickConfig.isEmpty
                        ? () {
                      final center = Offset(screenW / 2, (screenH - 160) / 2);
                      setState(() {
                        _newJoystickConfig.add(
                          JoystickPlaceholder(position: center, size: 100.0),
                        );
                      });
                    }
                        : null,
                    child: const Icon(Icons.gamepad, color: Colors.white),
                  ),

                  // 重命名
                  FloatingActionButton(
                    heroTag: 'renameCreate',
                    tooltip: '重命名',
                    backgroundColor: Colors.orange[700],
                    onPressed: () async {
                      final newName = await renameDialog(context, _currentName);
                      if (newName != null) {
                        if (widget.existingNames.contains(newName)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('布局名称重复，无法重命名')),
                          );
                        } else {
                          setState(() {
                            _currentName = newName;
                          });
                        }
                      }
                    },
                    child: const Icon(Icons.edit, color: Colors.white),
                  ),

                  // 返回
                  FloatingActionButton(
                    heroTag: 'goBackCreate',
                    tooltip: '返回',
                    backgroundColor: Colors.grey[700],
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),

                  // 保存
                  FloatingActionButton(
                    heroTag: 'saveCreate',
                    tooltip: '保存',
                    backgroundColor: Colors.blue[700],
                    onPressed: () {
                      final name = _currentName.trim().isEmpty
                          ? '未命名'
                          : _currentName.trim();
                      if (widget.existingNames.contains(name)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('布局名称重复，无法保存')),
                        );
                        return;
                      }
                      Navigator.pop(context, {
                        'name': name,
                        'keys': _newKeyConfig,
                        'joysticks': _newJoystickConfig,
                      });
                    },
                    child: const Icon(Icons.save, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
