import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class CvAnalysisScreen extends StatefulWidget {
  const CvAnalysisScreen({super.key});

  @override
  State<CvAnalysisScreen> createState() => _CvAnalysisScreenState();
}

class _CvAnalysisScreenState extends State<CvAnalysisScreen> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Msg> _messages = [];

  bool _sending = false;

  // 👇 Thêm để preview PDF
  String? _pdfPath;
  PdfControllerPinch? _pdfCtrl;
  Uint8List? _pdfBytes;
  String? _pdfName;

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    _pdfCtrl?.dispose();
    super.dispose();
  }

  void _appendUser(String text) {
    setState(() {
      _messages.add(_Msg(role: _Role.user, text: text));
    });
  }

  void _appendAssistant(String text) {
    setState(() {
      _messages.add(_Msg(role: _Role.assistant, text: text));
    });
  }

  void _clear() {
    setState(() {
      _messages.clear();
      _pdfPath = null;
      _pdfCtrl?.dispose();
      _pdfCtrl = null;
    });
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true, // try to obtain bytes when possible
      );
      if (result == null) return;
      final picked = result.files.single;
      _pdfName = picked.name;
      _pdfBytes = picked.bytes == null
          ? null
          : Uint8List.fromList(picked.bytes!);

      // Prefer opening from bytes (works across platforms). If bytes
      // are not provided, fall back to the file path. If path exists but
      // file is missing, try to materialize from readStream.
      String? path = picked.path;

      if (_pdfBytes != null) {
        _pdfCtrl?.dispose();
        _pdfCtrl = PdfControllerPinch(
          document: PdfDocument.openData(_pdfBytes!),
        );
        setState(() {
          _pdfPath = null;
        });
      } else if (path != null) {
        // ensure file exists; if not, try to reconstruct from readStream
        try {
          final f = File(path);
          if (!await f.exists()) {
            if (picked.readStream != null) {
              final tempDir = await Directory.systemTemp.createTemp(
                'appmobie_pdf_',
              );
              final tempFile = File('${tempDir.path}/${picked.name}');
              final sink = tempFile.openWrite();
              await for (final chunk in picked.readStream!) {
                sink.add(chunk);
              }
              await sink.close();
              path = tempFile.path;
            } else {
              throw Exception(
                'Picked file path does not exist and no readStream available',
              );
            }
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Không thể đọc file PDF: $e')));
          return;
        }

        _pdfCtrl?.dispose();
        _pdfCtrl = PdfControllerPinch(document: PdfDocument.openFile(path));
        setState(() => _pdfPath = path);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể lấy file PDF đã chọn.')),
        );
        return;
      }

      // Đọc text bằng Syncfusion
      final bytes = _pdfBytes ?? await File(_pdfPath!).readAsBytes();
      final document = sfpdf.PdfDocument(inputBytes: bytes);
      final text = sfpdf.PdfTextExtractor(document).extractText();
      document.dispose();

      if (text.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể đọc nội dung PDF.')),
        );
        return;
      }

      _appendUser('📄 Đã chọn file PDF, bắt đầu phân tích nội dung CV...');
      await _sendToBackend('Hãy phân tích nội dung sau từ file PDF:\n\n$text');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi đọc PDF: $e')));
    }
  }

  Future<void> _sendToBackend(String text) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _appendUser('📄 Đã gửi CV hoặc câu hỏi, đang phân tích...');
      _appendAssistant('Đang phân tích…');
    });

    try {
      // Đổi endpoint cho đúng backend Flask sử dụng
      final url = Uri.parse('http://10.0.2.2:5000/api/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['question_users'] = text;

      // Nếu có file PDF đã chọn, gửi kèm.
      // Prefer sending bytes (safer across Android scoped storage),
      // otherwise fall back to path.
      if (_pdfBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            _pdfBytes!,
            filename: _pdfName ?? 'cv.pdf',
            contentType: MediaType('application', 'pdf'),
          ),
        );
      } else if (_pdfPath != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'files', // đúng tên trường backend yêu cầu
            _pdfPath!,
            contentType: MediaType('application', 'pdf'),
          ),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      String result;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Hiển thị kết quả trả về từ backend Flask
        result = data['answer'] ?? 'Không có kết quả';
      } else {
        result = 'Lỗi backend: ${response.statusCode}\n${response.body}';
      }
      setState(() {
        _messages.removeLast();
        _appendAssistant(result);
      });
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _appendAssistant('Lỗi khi gọi backend: $e');
      });
    }
    setState(() => _sending = false);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    await _sendToBackend(text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Thanh toolbar
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Xoá hội thoại',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _messages.isEmpty ? null : _clear,
                ),
                FilledButton.tonalIcon(
                  onPressed: _sending ? null : _pickPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Chọn file PDF'),
                ),
                const Spacer(),
                const Text('CV Assistant 🧠'),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        // 👇 Hiển thị PDF nếu có (hỗ trợ preview từ bytes hoặc path)
        if (_pdfCtrl != null)
          SizedBox(
            height: 220,
            child: PdfViewPinch(
              controller: _pdfCtrl!,
              onDocumentError: (err) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi hiển thị PDF: $err')),
                );
              },
            ),
          ),

        // Danh sách tin nhắn
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            itemCount: _messages.length,
            itemBuilder: (ctx, i) {
              final m = _messages[i];
              final isUser = m.role == _Role.user;
              return Align(
                alignment: isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(ctx).size.width * 0.82,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Theme.of(ctx).colorScheme.primary
                        : Theme.of(ctx).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SelectableText(
                    m.text.isEmpty && _sending && !isUser
                        ? 'Đang phân tích…'
                        : m.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : null,
                      height: 1.35,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const Divider(height: 1),

        // Ô nhập tin nhắn
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Nhập câu hỏi hoặc dán CV...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                  label: const Text('Gửi'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _Role { user, assistant }

class _Msg {
  final _Role role;
  final String text;
  const _Msg({required this.role, required this.text});
}
