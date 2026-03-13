import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  GeminiService._();
  static final instance = GeminiService._();

  late final GenerativeModel _model = GenerativeModel(
    model: 'gemini-1.5-flash', // nhanh, rẻ; có thể đổi sang 1.5-pro
    apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
    safetySettings: [
      SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
      SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
      SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
    ],
    generationConfig: GenerationConfig(
      temperature: 0.3,
      topP: 0.9,
      topK: 40,
      maxOutputTokens: 4090,
    ),
  );

  /// Tạo prompt chuyên phân tích CV (bạn có thể tinh chỉnh)
  String buildCvSystemPrompt() => '''
Bạn là trợ lý tuyển dụng. Phân tích CV dựa trên JD ngắn gọn (nếu có).
Đầu ra gói gọn, rõ ràng:
- Điểm mạnh (bullet)
- Thiếu sót / gap (bullet)
- Từ khóa còn thiếu nên thêm
- Gợi ý cải thiện (theo STAR nếu phù hợp)
- Mức phù hợp (0–100) và nhận xét tổng quát
Giữ câu trả lời ngắn gọn, dễ đọc.

Nếu người dùng chỉ paste CV, hãy tự trích kỹ năng, kinh nghiệm, dự án, thành tích.
''';

  /// Chat 1 lượt (stream), truyền history để giữ ngữ cảnh
  Stream<String> analyzeStream({
    required List<Content> history,
    required String userMessage,
  }) async* {
    final input = [
      // “system message” ghim hướng dẫn
      Content.system(buildCvSystemPrompt()),
      ...history,
      Content.text(userMessage),
    ];
    final response = _model.generateContentStream(input);
    await for (final chunk in response) {
      yield chunk.text ?? '';
    }
  }

  /// Tạo content message tiện dụng
  Content user(String text) => Content.text(text);
  Content assistant(String text) => Content.model([TextPart(text)]);
}
