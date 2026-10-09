import 'package:flutter/material.dart';

import '../../../data/rest/api_config.dart';

/// Поле адреса живёт до конца анимации закрытия диалога.
class ServerUrlDialog extends StatefulWidget {
  const ServerUrlDialog({required this.initialUrl, super.key});

  final String initialUrl;

  @override
  State<ServerUrlDialog> createState() => _ServerUrlDialogState();
}

class _ServerUrlDialogState extends State<ServerUrlDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initialUrl);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Адрес сервера'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _save(),
        decoration: const InputDecoration(
          labelText: 'IP-адрес и порт',
          hintText: '127.0.0.1:9223',
        ),
        validator: (value) {
          try {
            ApiConfig.normalizeBaseUrl(value ?? '');
            return null;
          } on FormatException catch (error) {
            return error.message.toString();
          }
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Отмена'),
      ),
      FilledButton(onPressed: _save, child: const Text('Сохранить')),
    ],
  );
}
