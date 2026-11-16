import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/server/aura_server_client.dart';
import '../../../models/consultation.dart';
import '../../../models/consultation_message.dart';

/// 상담 턴은 서버 Gemma가 생성한다. 앱은 대화 기록과 새 질문만 보낸다.
final gemmaChatSessionProvider = Provider<ServerChatSession>((ref) {
  return ServerChatSession(ref);
});

class ServerChatSession {
  ServerChatSession(this._ref);

  final Ref _ref;

  Future<void> openSession(Consultation consultation) async {
    // 모델은 서버에 상주한다. 화면 진입 시 로컬 세션을 열지 않는다.
    return;
  }

  Stream<String> sendMessage({
    required Consultation consultation,
    required List<ConsultationMessage> history,
    required String userInput,
  }) {
    final window = history.length <= 12
        ? history
        : history.sublist(history.length - 12);
    return _ref.read(auraServerClientProvider).chat(
          locale: consultation.locale,
          analysisType: consultation.analysisType == AnalysisType.face
              ? 'face'
              : 'palm',
          contextSummary: consultation.contextSummary,
          features: consultation.contextFeatures,
          history: [
            for (final message in window)
              {
                'role': message.role == MessageRole.user ? 'user' : 'assistant',
                'content': message.content,
              },
          ],
          message: userInput,
        );
  }

  void dispose() {}
}
