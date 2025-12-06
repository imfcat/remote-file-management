import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/backend_provider.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

/// 初始化
class InitScreen extends StatefulWidget {
  const InitScreen({super.key});

  @override
  State<InitScreen> createState() => _InitScreenState();
}

class _InitScreenState extends State<InitScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String _selectedProtocol = 'http://';
  final List<String> _protocols = ['http://', 'https://'];

  @override
  void initState() {
    super.initState();
    _autoJumpIfConfigured();
  }

  Future<void> _autoJumpIfConfigured() async {
    final provider = Provider.of<BackendProvider>(context, listen: false);
    await provider.loadBackendUrl();

    // 如果有保存的地址，自动填充到输入框
    if (provider.backendUrl != null && provider.backendUrl!.isNotEmpty) {
      _fillSavedUrl(provider.backendUrl!);
    }

    if (!provider.isConfigured) return;

    setState(() => _loading = true);
    try {
      await ApiService.listRootFolders(provider.backendUrl!);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      await provider.setBackendUrl('');
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存地址已失效，请重新输入'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 填充保存的链接
  void _fillSavedUrl(String savedUrl) {
    for (final protocol in _protocols) {
      if (savedUrl.startsWith(protocol)) {
        setState(() {
          _selectedProtocol = protocol;
        });
        final urlWithoutProtocol = savedUrl.substring(protocol.length);
        _controller.text = urlWithoutProtocol;
        return;
      }
    }
    _controller.text = savedUrl;
  }

  Future<void> _save() async {
    final urlWithoutProtocol = _controller.text.trim();
    if (urlWithoutProtocol.isEmpty) return;

    // 拼接协议和地址
    final fullUrl = '$_selectedProtocol$urlWithoutProtocol';

    setState(() => _loading = true);
    try {
      await ApiService.listRootFolders(fullUrl);
      await Provider.of<BackendProvider>(context, listen: false)
          .setBackendUrl(fullUrl);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('连接失败'),
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('重新输入'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 600,
          child: Card(
            margin: const EdgeInsets.all(32),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '输入后端地址',
                    style: TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      // 选择框
                      DropdownButton<String>(
                        value: _selectedProtocol,
                        onChanged: _loading
                            ? null
                            : (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedProtocol = newValue;
                            });
                          }
                        },
                        items: _protocols
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        disabledHint: Text(_selectedProtocol),
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                        underline: Container(
                          height: 0,
                        ),
                      ),
                      // 输入框
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: !_loading,
                          decoration: const InputDecoration(
                            labelText: '例：192.168.1.10:8081',
                            border: OutlineInputBorder(),
                            hintText: '请输入服务器地址和端口',
                          ),
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.go,
                          onSubmitted: (_) => _loading ? null : _save(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _save,
                      child: _loading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                            AlwaysStoppedAnimation(Colors.white)),
                      )
                          : const Text('保存'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}