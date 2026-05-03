import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../l10n/app_localizations.dart';

// ── Palette ───────────────────────────────────────────────────
const _kGrad1   = Color(0xFF1B4D3E);
const _kGrad2   = Color(0xFF2E7D5C);
const _kDone    = Color(0xFF16A34A);
const _kDoneBg  = Color(0xFFDCFCE7);
const _kBg      = Color(0xFFF1F5F9);
const _kCard    = Colors.white;
const _kMuted   = Color(0xFF94A3B8);
const _kText    = Color(0xFF111827);
const _kSub     = AppColors.muted;

// ── Helper: does the evidence condition apply for the current answer? ─────────
// Returns true when evidence upload is actually required right now.
bool _evidenceConditionMet(String? evidCond, _LocalAns localAns) {
  if (!localAns.hasValue) return false; // no answer yet — never block / never show
  if (evidCond == null || evidCond.isEmpty) return true; // no condition → always required
  final c = evidCond.toLowerCase();
  if ((c == 'yes' || c == '1') && localAns.answerNumber == 1) return true;
  if ((c == 'no'  || c == '0') && localAns.answerNumber == 0) return true;
  return false; // answer doesn't match the condition
}

// ── Pending evidence file (uploaded but not yet linked to answer) ─────────
class _PendingFile {
  final String id;                   // file_id returned by POST /files/upload
  final String name;                 // original filename for display
  final String? fileText;            // structured text (documents)
  final String? imageDescription;    // AI description (images)
  const _PendingFile({
    required this.id,
    required this.name,
    this.fileText,
    this.imageDescription,
  });
}

// ── Local answer model ────────────────────────────────────────
class _LocalAns {
  int? answerNumber;
  String answerText;
  Set<String> pickedOptionIds;
  int? evidenceSufficiencyPcntg; // loaded from server, shown as badge
  String? answerId;              // server answer ID — used to load evidence files

  _LocalAns({
    this.answerNumber,
    this.answerText = '',
    Set<String>? pickedOptionIds,
    this.evidenceSufficiencyPcntg,
    this.answerId,
  }) : pickedOptionIds = pickedOptionIds ?? {};

  bool get hasValue =>
      answerNumber != null ||
      answerText.trim().isNotEmpty ||
      pickedOptionIds.isNotEmpty;

  _LocalAns copyWith({
    int? answerNumber,
    bool clearAnswerNumber = false,
    String? answerText,
    Set<String>? pickedOptionIds,
    int? evidenceSufficiencyPcntg,
    bool clearSufficiency = false,
    String? answerId,
  }) =>
      _LocalAns(
        answerNumber:
            clearAnswerNumber ? null : (answerNumber ?? this.answerNumber),
        answerText: answerText ?? this.answerText,
        pickedOptionIds: pickedOptionIds ?? Set.from(this.pickedOptionIds),
        evidenceSufficiencyPcntg: clearSufficiency
            ? null
            : (evidenceSufficiencyPcntg ?? this.evidenceSufficiencyPcntg),
        answerId: answerId ?? this.answerId,
      );
}

// ── State ─────────────────────────────────────────────────────
class _AnsState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? data;
  final Map<String, _LocalAns> answers;
  final int quizIdx;
  final int qIdx;
  final bool saving;
  final bool finished;
  final int slideDir;
  /// Uploaded files not yet linked to an answer (keyed by questionId).
  final Map<String, List<_PendingFile>> pendingFiles;
  /// QuestionIds whose answers were already on the server when the session loaded
  /// — evidence was previously submitted for these, so no re-upload is required.
  final Set<String> serverAnsweredIds;
  /// Quiz results computed so far: quizId → resultLabel (e.g. 'HIGH').
  /// Used to evaluate conditionToShowQuestion on each question.
  final Map<String, String> quizResults;

  const _AnsState({
    this.isLoading = true,
    this.error,
    this.data,
    this.answers = const {},
    this.quizIdx = 0,
    this.qIdx = 0,
    this.saving = false,
    this.finished = false,
    this.slideDir = 1,
    this.pendingFiles = const {},
    this.serverAnsweredIds = const {},
    this.quizResults = const {},
  });

  _AnsState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? data,
    Map<String, _LocalAns>? answers,
    int? quizIdx,
    int? qIdx,
    bool? saving,
    bool? finished,
    int? slideDir,
    Map<String, List<_PendingFile>>? pendingFiles,
    Set<String>? serverAnsweredIds,
    Map<String, String>? quizResults,
  }) =>
      _AnsState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        data: data ?? this.data,
        answers: answers ?? this.answers,
        quizIdx: quizIdx ?? this.quizIdx,
        qIdx: qIdx ?? this.qIdx,
        saving: saving ?? this.saving,
        finished: finished ?? this.finished,
        slideDir: slideDir ?? this.slideDir,
        pendingFiles: pendingFiles ?? this.pendingFiles,
        serverAnsweredIds: serverAnsweredIds ?? this.serverAnsweredIds,
        quizResults: quizResults ?? this.quizResults,
      );

  List<dynamic> get quizzes => (data?['quizzes'] as List?) ?? [];
  Map<String, dynamic>? get currentQuiz =>
      quizIdx < quizzes.length ? quizzes[quizIdx] as Map<String, dynamic> : null;
  List<dynamic> get currentQuestions =>
      (currentQuiz?['questions'] as List?) ?? [];
  Map<String, dynamic>? get currentQuestion =>
      qIdx < currentQuestions.length
          ? currentQuestions[qIdx] as Map<String, dynamic>
          : null;
  int get totalQuestionsInQuiz => currentQuestions.length;

  /// Returns true if this question should be shown to the user.
  /// A question is hidden when is_active == false, or when
  /// conditionToShowQuestion is set and no matching quiz result exists.
  bool isQuestionVisible(Map<String, dynamic> q) {
    if (q['isActive'] == false) return false;
    final condition =
        (q['conditionToShowQuestion'] as List?)?.cast<String>();
    if (condition == null || condition.isEmpty) return true;
    return quizResults.values.any(condition.contains);
  }

  bool isQuizDone(int idx) {
    if (idx >= quizzes.length) return false;
    final quiz = quizzes[idx] as Map<String, dynamic>;
    final qs = (quiz['questions'] as List?) ?? [];
    if (qs.isEmpty) return false;
    return qs.every((q) {
      final qMap = q as Map<String, dynamic>;
      if (!isQuestionVisible(qMap)) return true; // hidden = treated as done
      return answers[qMap['id']]?.hasValue ?? false;
    });
  }

  /// True when there is no next visible question after the current one.
  bool get isLastQuestion {
    // scan forward from current position
    for (var qi = quizIdx; qi < quizzes.length; qi++) {
      final qs =
          ((quizzes[qi] as Map)['questions'] as List?) ?? [];
      final startQqi = (qi == quizIdx) ? qIdx + 1 : 0;
      for (var qqi = startQqi; qqi < qs.length; qqi++) {
        if (isQuestionVisible(qs[qqi] as Map<String, dynamic>)) return false;
      }
    }
    return true;
  }

  // Total answered / total visible questions across all quizzes
  int get totalAnswered {
    int count = 0;
    for (final quiz in quizzes) {
      final qs = (quiz as Map)['questions'] as List? ?? [];
      for (final q in qs) {
        final qMap = q as Map<String, dynamic>;
        if (!isQuestionVisible(qMap)) continue;
        if (answers[qMap['id']]?.hasValue ?? false) count++;
      }
    }
    return count;
  }

  int get totalQuestions {
    int count = 0;
    for (final quiz in quizzes) {
      for (final q in (quiz as Map)['questions'] as List? ?? []) {
        if (isQuestionVisible(q as Map<String, dynamic>)) count++;
      }
    }
    return count;
  }

  // Index of current question across ALL visible questions (1-based for display)
  int get globalQuestionIndex {
    int count = 0;
    for (var qi = 0; qi < quizzes.length; qi++) {
      final qs = ((quizzes[qi] as Map)['questions'] as List?) ?? [];
      for (var qqi = 0; qqi < qs.length; qqi++) {
        if (!isQuestionVisible(qs[qqi] as Map<String, dynamic>)) continue;
        count++;
        if (qi == quizIdx && qqi == qIdx) return count;
      }
    }
    return count;
  }
}

// ── Notifier ──────────────────────────────────────────────────
class _AnsNotifier extends StateNotifier<_AnsState> {
  final Dio _dio;
  final String sessionId;

  _AnsNotifier(this._dio, this.sessionId) : super(const _AnsState()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _dio.get<Map<String, dynamic>>(
          '/workflow-answers/$sessionId');
      final data = res.data!;

      final answers = <String, _LocalAns>{};
      for (final a in (data['answers'] as List? ?? [])) {
        final m = a as Map<String, dynamic>;
        answers[m['questionId'] as String] = _LocalAns(
          answerNumber: m['answerNumber'] as int?,
          answerText: m['answerText'] as String? ?? '',
          pickedOptionIds:
              Set<String>.from(m['pickedOptionIds'] as List? ?? []),
          evidenceSufficiencyPcntg: m['evidenceSufficiencyPcntg'] as int?,
          answerId: m['id'] as String?,
        );
      }

      final currentQuizId = data['currentQuizId'] as String?;
      final currentQuestionId = data['currentQuestionId'] as String?;
      final quizzes = data['quizzes'] as List? ?? [];

      // Parse quiz results map FIRST — needed for visibility checks below.
      final quizResults = <String, String>{};
      final rawResults = data['quizResults'] as Map<String, dynamic>? ?? {};
      rawResults.forEach((k, v) {
        quizResults[k] = v as String;
      });

      int quizIdx = 0;
      int qIdx = 0;

      if (currentQuizId != null) {
        final qi = quizzes.indexWhere(
            (q) => (q as Map)['id'] == currentQuizId);
        if (qi >= 0) {
          quizIdx = qi;
          final qs = (quizzes[qi] as Map)['questions'] as List? ?? [];
          if (currentQuestionId != null) {
            final qqi =
                qs.indexWhere((q) => (q as Map)['id'] == currentQuestionId);
            if (qqi >= 0) qIdx = qqi;
          }
        }
      } else if (answers.isNotEmpty) {
        _computeResumePosition(quizzes, answers, quizResults, (qi, qi2) {
          quizIdx = qi;
          qIdx = qi2;
        });
      }

      state = state.copyWith(
        isLoading: false,
        data: data,
        answers: answers,
        quizIdx: quizIdx,
        qIdx: qIdx,
        serverAnsweredIds: answers.keys.toSet(),
        quizResults: quizResults,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _computeResumePosition(List quizzes, Map<String, _LocalAns> answers,
      Map<String, String> quizResults, void Function(int, int) onFound) {
    for (var qi = 0; qi < quizzes.length; qi++) {
      final qs = (quizzes[qi] as Map)['questions'] as List? ?? [];
      for (var qqi = 0; qqi < qs.length; qqi++) {
        final qMap = qs[qqi] as Map<String, dynamic>;
        // Skip inactive and invisible questions
        if (qMap['isActive'] == false) continue;
        final condition =
            (qMap['conditionToShowQuestion'] as List?)?.cast<String>();
        if (condition != null &&
            condition.isNotEmpty &&
            !quizResults.values.any(condition.contains)) {
          continue;
        }
        final qId = qMap['id'] as String;
        if (!(answers[qId]?.hasValue ?? false)) {
          onFound(qi, qqi);
          return;
        }
      }
    }
  }

  // ── Answer setters ──────────────────────────────────────────

  void setAnswerNumber(String questionId, int? v) {
    final cur = state.answers[questionId] ?? _LocalAns();
    state = state.copyWith(
      answers: {...state.answers, questionId: cur.copyWith(answerNumber: v)},
      error: null,
    );
  }

  void setAnswerText(String questionId, String v) {
    final cur = state.answers[questionId] ?? _LocalAns();
    state = state.copyWith(
      answers: {...state.answers, questionId: cur.copyWith(answerText: v)},
      error: null,
    );
  }

  void toggleOption(String questionId, String optId) {
    final cur = state.answers[questionId] ?? _LocalAns();
    final newPicked = Set<String>.from(cur.pickedOptionIds);
    if (newPicked.contains(optId)) {
      newPicked.remove(optId);
    } else {
      newPicked.add(optId);
    }
    state = state.copyWith(
      answers: {
        ...state.answers,
        questionId: cur.copyWith(pickedOptionIds: newPicked),
      },
      error: null,
    );
  }

  void setOnePickOption(String questionId, String optId) {
    final cur = state.answers[questionId] ?? _LocalAns();
    state = state.copyWith(
      answers: {
        ...state.answers,
        questionId: cur.copyWith(pickedOptionIds: {optId}, answerText: optId),
      },
      error: null,
    );
  }

  // ── Evidence file tracking ──────────────────────────────────

  void addPendingFile(
    String questionId,
    String fileId,
    String fileName, {
    String? fileText,
    String? imageDescription,
  }) {
    final updated = Map<String, List<_PendingFile>>.from(state.pendingFiles);
    updated[questionId] = [
      ...(updated[questionId] ?? []),
      _PendingFile(
        id: fileId,
        name: fileName,
        fileText: fileText,
        imageDescription: imageDescription,
      ),
    ];
    state = state.copyWith(pendingFiles: updated);
  }

  void removePendingFile(String questionId, String fileId) {
    final updated = Map<String, List<_PendingFile>>.from(state.pendingFiles);
    updated[questionId] =
        (updated[questionId] ?? []).where((f) => f.id != fileId).toList();
    state = state.copyWith(pendingFiles: updated);
  }

  // ── Navigation ──────────────────────────────────────────────

  Future<void> submitAndAdvance() async {
    final q = state.currentQuestion;
    if (q == null) return;

    final qId    = q['id'] as String;
    final qType  = q['qType'] as String;
    final quizId = state.currentQuiz!['id'] as String;
    final local  = state.answers[qId] ?? _LocalAns();

    // Guard: must answer before advancing
    if (!local.hasValue) {
      state = state.copyWith(error: 'Please answer this question before continuing.');
      return;
    }

    state = state.copyWith(saving: true, error: null);

    try {
      // ── 1. Prepare answer payload ──────────────────────────────────────────
      List<String> pickedOptionIds = [];
      int?    answerNumber = local.answerNumber;
      String? answerText;

      if (qType == 'yes_no') {
        answerNumber = local.answerNumber;
      } else if (qType == 'one_pick') {
        pickedOptionIds = local.pickedOptionIds.toList();
        answerText = pickedOptionIds.isNotEmpty ? pickedOptionIds.first : null;
      } else if (qType == 'multiple_pick') {
        pickedOptionIds = local.pickedOptionIds.toList();
        answerText      = pickedOptionIds.join(',');
      } else {
        answerText = local.answerText.trim().isEmpty
            ? null
            : local.answerText.trim();
      }

      // ── 2. Submit answer (position fields left null; will be corrected on
      //       the NEXT submission once we know the real next question) ────────
      final ansRes = await _dio.post<Map<String, dynamic>>(
        '/workflow-answers/$sessionId/answers',
        data: {
          'quizId':          quizId,
          'questionId':      qId,
          'answerNumber':    answerNumber,
          'answerText':      answerText,
          'pickedOptionIds': pickedOptionIds,
          'nextQuizId':      null,
          'nextQuestionId':  null,
        },
      );

      // ── 3. Link any pending evidence files to the saved answer ─────────────
      final answerId = ansRes.data?['id'] as String?;
      if (answerId != null) {
        // Store the answerId in _LocalAns so the evidence panel can load
        // server files if the user navigates back to this question.
        final updatedAnswers = Map<String, _LocalAns>.from(state.answers);
        if (updatedAnswers.containsKey(qId)) {
          updatedAnswers[qId] = updatedAnswers[qId]!.copyWith(answerId: answerId);
        }
        state = state.copyWith(answers: updatedAnswers);

        final toLink = List<_PendingFile>.from(state.pendingFiles[qId] ?? []);
        for (final f in toLink) {
          try {
            await _dio.post<dynamic>(
              '/answers/$answerId/files',
              data: {'fileId': f.id},
            );
          } catch (_) {
            // Non-critical: file upload already succeeded; linking failure
            // is logged but does not block the user from advancing.
          }
        }
        if (toLink.isNotEmpty) {
          final newPending = Map<String, List<_PendingFile>>.from(state.pendingFiles)
            ..remove(qId);
          state = state.copyWith(pendingFiles: newPending);
        }
      }

      // ── 4. If this was the last VISIBLE question of the current quiz,
      //       compute its result NOW — before scanning for the next visible
      //       question.  This is critical: questions in subsequent quizzes may
      //       have conditionToShowQuestion that depends on this quiz's result,
      //       so the scan in step 5 must see the freshly computed result. ─────
      final currentQsList = (state.currentQuiz?['questions'] as List?) ?? [];
      bool hasLaterVisible = false;
      for (var i = state.qIdx + 1; i < currentQsList.length; i++) {
        if (state.isQuestionVisible(currentQsList[i] as Map<String, dynamic>)) {
          hasLaterVisible = true;
          break;
        }
      }
      if (!hasLaterVisible) {
        try {
          final resultRes = await _dio.post<Map<String, dynamic>>(
            '/workflow-answers/$sessionId/quizzes/$quizId/compute-result',
          );
          // Update local quiz results map so the scan below uses the fresh result.
          if (resultRes.data != null) {
            final resultLabel = resultRes.data!['resultLabel'] as String?;
            if (resultLabel != null) {
              final updatedResults =
                  Map<String, String>.from(state.quizResults)
                    ..[quizId] = resultLabel;
              state = state.copyWith(quizResults: updatedResults);
            }
          }
        } catch (_) {
          // Non-critical — result computation failure should not block navigation.
        }
      }

      // ── 5. Find the next VISIBLE question by scanning forward.
      //       Uses state.quizResults which now includes any result computed
      //       in step 4, so cross-quiz conditional questions are evaluated
      //       with the latest data. ────────────────────────────────────────────
      final quizzes = state.quizzes;
      int nextQuizIdx = state.quizIdx;
      int nextQIdx    = state.qIdx + 1;
      bool foundNext  = false;
      bool finished   = false;

      outer:
      while (nextQuizIdx < quizzes.length) {
        final qs = ((quizzes[nextQuizIdx] as Map)['questions'] as List?) ?? [];
        while (nextQIdx < qs.length) {
          final nextQMap = qs[nextQIdx] as Map<String, dynamic>;
          if (state.isQuestionVisible(nextQMap)) {
            foundNext = true;
            break outer;
          }
          nextQIdx++;
        }
        // Move to next quiz
        nextQuizIdx++;
        nextQIdx = 0;
      }

      if (!foundNext) finished = true;

      // ── 6. When the entire workflow is done, mark this session as active ───
      if (finished) {
        try {
          await _dio.patch<dynamic>('/workflow-answers/$sessionId/activate');
        } catch (_) {
          // Non-critical — show finished screen regardless.
        }
      }

      state = state.copyWith(
        saving:   false,
        quizIdx:  nextQuizIdx,
        qIdx:     nextQIdx,
        finished: finished,
        slideDir: 1,
        error:    null,
      );
    } catch (e) {
      state = state.copyWith(
        saving: false,
        error:  e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void goBack() {
    if (state.saving) return;

    // Scan backward for the nearest previous visible question.
    int prevQuizIdx = state.quizIdx;
    int prevQIdx    = state.qIdx - 1;

    while (true) {
      if (prevQIdx >= 0) {
        final qs =
            ((state.quizzes[prevQuizIdx] as Map)['questions'] as List?) ?? [];
        if (prevQIdx < qs.length &&
            state.isQuestionVisible(
                qs[prevQIdx] as Map<String, dynamic>)) {
          // Found the previous visible question.
          state = state.copyWith(
            quizIdx:  prevQuizIdx,
            qIdx:     prevQIdx,
            error:    null,
            slideDir: -1,
          );
          return;
        }
        prevQIdx--;
      } else {
        // No visible question in this quiz going backward; try previous quiz.
        if (prevQuizIdx == 0) return; // already at the very first question
        prevQuizIdx--;
        final prevQsList =
            ((state.quizzes[prevQuizIdx] as Map)['questions'] as List?) ?? [];
        prevQIdx = prevQsList.length - 1;
      }
    }
  }
}

// ── Provider ──────────────────────────────────────────────────
final _ansProvider = StateNotifierProvider.autoDispose
    .family<_AnsNotifier, _AnsState, String>(
  (ref, sessionId) => _AnsNotifier(ref.watch(dioProvider), sessionId),
);

// ── Screen ────────────────────────────────────────────────────
class WorkflowAnswerScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String workflowName;

  const WorkflowAnswerScreen({
    super.key,
    required this.sessionId,
    required this.workflowName,
  });

  @override
  ConsumerState<WorkflowAnswerScreen> createState() =>
      _WorkflowAnswerScreenState();
}

class _WorkflowAnswerScreenState extends ConsumerState<WorkflowAnswerScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode             _keyFocus = FocusNode();
  String? _lastTextQuestionId;
  Timer?  _autoAdvanceTimer;

  @override
  void dispose() {
    _textCtrl.dispose();
    _keyFocus.dispose();
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  void _syncTextCtrl(_AnsState s) {
    final q = s.currentQuestion;
    if (q == null) return;
    final qId   = q['id'] as String;
    final qType = q['qType'] as String;
    if ((qType == 'text' || qType == 'numeric') && qId != _lastTextQuestionId) {
      _lastTextQuestionId = qId;
      _textCtrl.text = s.answers[qId]?.answerText ?? '';
    }
  }

  void _scheduleAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(const Duration(milliseconds: 550), () {
      if (!mounted) return;
      // Block auto-advance when evidence is required and condition is met
      // but no file has been uploaded yet.
      final s = ref.read(_ansProvider(widget.sessionId));
      final q = s.currentQuestion;
      if (q != null) {
        final qId      = q['id'] as String;
        final reqsEv   = q['requiresEvidence'] as bool? ?? false;
        final evidCond = q['evidenceCondition'] as String?;
        final localAns = s.answers[qId] ?? _LocalAns();
        if (reqsEv && _evidenceConditionMet(evidCond, localAns)) {
          final hasFiles        = s.pendingFiles[qId]?.isNotEmpty ?? false;
          final alreadyAnswered = s.serverAnsweredIds.contains(qId);
          if (!hasFiles && !alreadyAnswered) return;
        }
      }
      _advance();
    });
  }

  Future<void> _advance() async {
    _autoAdvanceTimer?.cancel();
    final s = ref.read(_ansProvider(widget.sessionId));
    final q = s.currentQuestion;
    final _qt = q?['qType'] as String?;
    if (q != null && (_qt == 'text' || _qt == 'numeric')) {
      ref.read(_ansProvider(widget.sessionId).notifier)
          .setAnswerText(q['id'] as String, _textCtrl.text);
    }
    await ref.read(_ansProvider(widget.sessionId).notifier).submitAndAdvance();
    _keyFocus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
    final s = ref.read(_ansProvider(widget.sessionId));
    if (s.saving || s.finished || s.currentQuestion == null) {
      return KeyEventResult.ignored;
    }
    final qType = s.currentQuestion!['qType'] as String;
    final qId   = s.currentQuestion!['id'] as String;
    final notif = ref.read(_ansProvider(widget.sessionId).notifier);

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      if (qType != 'text') {
        _advance();
        return KeyEventResult.handled;
      }
    }
    if (qType == 'yes_no') {
      if (event.logicalKey == LogicalKeyboardKey.keyY) {
        notif.setAnswerNumber(qId, 1);
        _scheduleAutoAdvance();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyN) {
        notif.setAnswerNumber(qId, 0);
        _scheduleAutoAdvance();
        return KeyEventResult.handled;
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _advance();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      notif.goBack();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(_ansProvider(widget.sessionId));
    _syncTextCtrl(s);

    return Focus(
      focusNode: _keyFocus,
      autofocus: true,
      onKey: _onKey,
      child: Scaffold(
        backgroundColor: _kBg,
        body: Column(
          children: [
            // ── Gradient top bar ────────────────────────────────
            _TopBar(
              workflowName: widget.workflowName,
              onBack: () => context.pop(),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.06, end: 0),

            // ── Thin overall progress bar ────────────────────────
            if (!s.isLoading && s.data != null && !s.finished)
              _OverallProgressBar(
                answered: s.totalAnswered,
                total:    s.totalQuestions,
              ),

            // ── Timeline stepper ─────────────────────────────────
            if (!s.isLoading && s.data != null && s.quizzes.length > 1 && !s.finished)
              _StepperBar(
                quizzes:        s.quizzes.cast<Map<String, dynamic>>(),
                currentQuizIdx: s.quizIdx,
                isQuizDone:     s.isQuizDone,
                quizResults:    s.quizResults,
              ),

            // ── Body ─────────────────────────────────────────────
            Expanded(
              child: s.isLoading
                  ? const _LoadingView()
                  : s.error != null && s.data == null
                      ? _ErrorView(
                          message: s.error!,
                          onRetry: () => ref
                              .read(_ansProvider(widget.sessionId).notifier)
                              ._load(),
                        )
                      : s.finished
                          ? _FinishedView(
                              sessionId: widget.sessionId,
                              workflowName: widget.workflowName,
                              totalAnswered: s.totalAnswered,
                              totalQuestions: s.totalQuestions,
                              quizResults: s.quizResults,
                            )
                          : s.currentQuestion == null
                              ? _EmptyView(workflowName: widget.workflowName)
                              : _QuestionView(
                                  s:          s,
                                  textCtrl:   _textCtrl,
                                  sessionId:  widget.sessionId,
                                  ref:        ref,
                                  onTextChanged: (v) => ref
                                      .read(_ansProvider(widget.sessionId).notifier)
                                      .setAnswerText(s.currentQuestion!['id'] as String, v),
                                  onAutoAdvance: _scheduleAutoAdvance,
                                ),
            ),

            // ── Navigation bar ───────────────────────────────────
            if (!s.isLoading && s.data != null && !s.finished)
              _NavBar(
                canGoBack:  s.quizIdx > 0 || s.qIdx > 0,
                canAdvance: () {
                  final q = s.currentQuestion;
                  if (q == null) return true;
                  final qId = q['id'] as String;
                  final localAns = s.answers[qId] ?? _LocalAns();
                  if (!localAns.hasValue) return false;
                  final reqsEv  = q['requiresEvidence'] as bool? ?? false;
                  if (!reqsEv) return true;
                  // Evidence only required when the condition matches the answer.
                  final evidCond = q['evidenceCondition'] as String?;
                  if (!_evidenceConditionMet(evidCond, localAns)) return true;
                  // Already answered server-side → evidence was previously provided.
                  if (s.serverAnsweredIds.contains(qId)) return true;
                  // New answer → must have at least one pending file.
                  return (s.pendingFiles[qId]?.isNotEmpty ?? false);
                }(),
                isLast:     s.isLastQuestion,
                saving:     s.saving,
                current:    s.globalQuestionIndex,
                total:      s.totalQuestions,
                error:      s.error,
                onBack:    () {
                  _autoAdvanceTimer?.cancel();
                  ref.read(_ansProvider(widget.sessionId).notifier).goBack();
                },
                onNext:    _advance,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String workflowName;
  final VoidCallback onBack;

  const _TopBar({required this.workflowName, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kGrad1, _kGrad2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Color(0x331B4D3E), blurRadius: 20, offset: Offset(0, 6)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 20, 14),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_note_rounded,
                    color: Colors.white, size: 22),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context).fillingWorkflow,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.4,
                        )),
                    Text(
                      workflowName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Keyboard hint chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.keyboard_rounded, color: Colors.white60, size: 12),
                    Gap(4),
                    Text('↵ Next  Y/N',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Overall Progress Bar ──────────────────────────────────────
class _OverallProgressBar extends StatelessWidget {
  final int answered;
  final int total;

  const _OverallProgressBar({required this.answered, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : answered / total;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: pct),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (_, v, __) => LinearProgressIndicator(
        value: v,
        minHeight: 4,
        backgroundColor: const Color(0xFFE2E8F0),
        valueColor: const AlwaysStoppedAnimation<Color>(_kGrad2),
      ),
    );
  }
}

// ── Timeline Stepper Bar ──────────────────────────────────────
class _StepperBar extends StatelessWidget {
  final List<Map<String, dynamic>> quizzes;
  final int currentQuizIdx;
  final bool Function(int) isQuizDone;
  final Map<String, String> quizResults;

  const _StepperBar({
    required this.quizzes,
    required this.currentQuizIdx,
    required this.isQuizDone,
    required this.quizResults,
  });

  static Color _resultColor(String label) {
    switch (label.toUpperCase()) {
      case 'HIGH':     return const Color(0xFFDC2626);
      case 'MEDIUM':   return const Color(0xFFD97706);
      case 'BASIC':    return const Color(0xFF2563EB);
      case 'COMPLETE': return const Color(0xFF16A34A);
      default:         return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    const double nodeSize = 36.0;
    const double lineH    = 2.0;

    return Container(
      color: _kCard,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Connector lines (drawn behind the circles) ──────
          Positioned(
            top: nodeSize / 2 - lineH / 2,
            left: nodeSize / 2,
            right: nodeSize / 2,
            height: lineH,
            child: Row(
              children: [
                for (int i = 0; i < quizzes.length - 1; i++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      color: isQuizDone(i) ? _kGrad1 : const Color(0xFFE2E8F0),
                    ),
                  ),
              ],
            ),
          ),

          // ── Circles + labels ────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < quizzes.length; i++)
                Expanded(
                  child: Builder(builder: (_) {
                    final quizId = quizzes[i]['id'] as String?;
                    final result = quizId != null ? quizResults[quizId] : null;
                    final showBadge = isQuizDone(i) && result != null && result != 'COMPLETE';
                    final badgeColor = showBadge ? _resultColor(result!) : Colors.transparent;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StepNode(
                          index: i,
                          isCurrent: i == currentQuizIdx,
                          isDone: isQuizDone(i),
                          size: nodeSize,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          quizzes[i]['name'] as String? ?? '',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.3,
                            fontWeight: i == currentQuizIdx
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: i == currentQuizIdx
                                ? _kGrad1
                                : isQuizDone(i)
                                    ? _kText
                                    : _kMuted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // ── Result label badge ────────────────
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          child: showBadge
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: badgeColor.withOpacity(0.5)),
                                    ),
                                    child: Text(
                                      result!,
                                      style: TextStyle(
                                        color: badgeColor,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    );
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepNode extends StatelessWidget {
  final int index;
  final bool isCurrent;
  final bool isDone;
  final double size;

  const _StepNode({
    required this.index,
    required this.isCurrent,
    required this.isDone,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final bool active = isCurrent || isDone;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? _kGrad1 : const Color(0xFFE2E8F0),
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
            : Text(
                '${index + 1}',
                style: TextStyle(
                  color: isCurrent ? Colors.white : _kMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

// ── Question View ─────────────────────────────────────────────
class _QuestionView extends StatelessWidget {
  final _AnsState s;
  final TextEditingController textCtrl;
  final String sessionId;
  final WidgetRef ref;
  final void Function(String) onTextChanged;
  final VoidCallback onAutoAdvance;

  const _QuestionView({
    required this.s,
    required this.textCtrl,
    required this.sessionId,
    required this.ref,
    required this.onTextChanged,
    required this.onAutoAdvance,
  });

  @override
  Widget build(BuildContext context) {
    final q        = s.currentQuestion!;
    final qId      = q['id'] as String;
    final qType    = q['qType'] as String;
    final title    = q['title'] as String?;
    final qText    = q['questionText'] as String? ?? '';
    final evidCond       = q['evidenceCondition'] as String?;
    final requiresEvidence = q['requiresEvidence'] as bool? ?? false;
    final evidencePrompt   = q['evidencePrompt'] as String?;
    final options  = (q['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final localAns = s.answers[qId] ?? _LocalAns();
    final notifier = ref.read(_ansProvider(sessionId).notifier);
    final pendingFiles = s.pendingFiles[qId] ?? [];
    final alreadyAnswered = s.serverAnsweredIds.contains(qId);

    // Show evidence panel only after the user picks an answer AND
    // the evidence_condition matches that answer.
    final showEvidencePanel = requiresEvidence &&
        _evidenceConditionMet(evidCond, localAns);

    // Soft notice (no upload required) when evidenceCondition applies
    // but requiresEvidence is false.
    final showEvidenceNotice = !requiresEvidence &&
        evidCond != null &&
        evidCond.isNotEmpty &&
        qType == 'yes_no' &&
        _evidenceConditionMet(evidCond, localAns);

    // Key used for AnimatedSwitcher — changes when question changes
    final questionKey = ValueKey('$qId-${s.slideDir}');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, anim) {
            final dir = s.slideDir;
            final offsetBegin = Offset(dir * 0.06, 0);
            return FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(begin: offsetBegin, end: Offset.zero)
                    .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                child: child,
              ),
            );
          },
          child: SingleChildScrollView(
            key: questionKey,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Quiz section label ─────────────────────
                _QuizSectionLabel(quizName: s.currentQuiz?['name'] as String? ?? ''),
                const Gap(12),

                // ── Question card ──────────────────────────
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0D000000), blurRadius: 16, offset: Offset(0, 4)),
                      BoxShadow(color: Color(0x06000000), blurRadius: 40, offset: Offset(0, 12)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card header stripe
                      Container(
                        height: 4,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [_kGrad1, _kGrad2]),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title tag
                            if (title != null && title.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _kGrad2.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    color: _kGrad2,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const Gap(12),
                            ],

                            // Question text
                            Text(
                              qText,
                              style: const TextStyle(
                                color: _kText,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                height: 1.5,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const Gap(24),

                            // Answer input
                            if (qType == 'yes_no')
                              _YesNoInput(
                                value:      localAns.answerNumber,
                                onChanged:  (v) {
                                  notifier.setAnswerNumber(qId, v);
                                  onAutoAdvance();
                                },
                              )
                            else if (qType == 'one_pick')
                              _OnePickInput(
                                options:    options,
                                selectedId: localAns.pickedOptionIds.isNotEmpty
                                    ? localAns.pickedOptionIds.first
                                    : null,
                                onChanged:  (id) {
                                  notifier.setOnePickOption(qId, id);
                                  onAutoAdvance();
                                },
                              )
                            else if (qType == 'multiple_pick')
                              _MultiPickInput(
                                options: options,
                                selected: localAns.pickedOptionIds,
                                onToggle: (id) => notifier.toggleOption(qId, id),
                              )
                            else if (qType == 'numeric')
                              _NumericInput(
                                controller: textCtrl,
                                onChanged:  onTextChanged,
                              )
                            else
                              _TextInput(
                                controller: textCtrl,
                                onChanged:  onTextChanged,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Mandatory evidence panel ──────────────
                if (showEvidencePanel)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _EvidencePanel(
                      sessionId:        sessionId,
                      questionId:       qId,
                      answerId:         localAns.answerId,
                      promptText:       evidencePrompt,
                      pendingFiles:     pendingFiles,
                      alreadyAnswered:  alreadyAnswered,
                      notifier:         notifier,
                      sufficiencyPcntg: localAns.evidenceSufficiencyPcntg,
                    )
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.08, end: 0),
                  )
                // ── Conditional evidence notice ───────────
                else if (showEvidenceNotice)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _EvidenceNotice()
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.08, end: 0),
                  ),

                const Gap(8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Quiz Section Label ────────────────────────────────────────
class _QuizSectionLabel extends StatelessWidget {
  final String quizName;
  const _QuizSectionLabel({required this.quizName});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3, height: 16,
          decoration: BoxDecoration(
            color: _kGrad2,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Gap(8),
        Flexible(
          child: Text(
            quizName.toUpperCase(),
            style: const TextStyle(
              color: _kGrad2,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Server-side answer file (already linked) ──────────────────
class _ServerFile {
  final String id;        // AnswerFile.id (for DELETE)
  final String fileId;
  final String fileName;
  final String? fileText;
  final String? imageDescription;
  final String createdAt;
  const _ServerFile({
    required this.id,
    required this.fileId,
    required this.fileName,
    this.fileText,
    this.imageDescription,
    required this.createdAt,
  });
  factory _ServerFile.fromJson(Map<String, dynamic> j) => _ServerFile(
        id: j['id'] as String,
        fileId: j['fileId'] as String,
        fileName: j['fileName'] as String? ?? '',
        fileText: j['fileText'] as String?,
        imageDescription: j['imageDescription'] as String?,
        createdAt: j['createdAt'] as String? ?? '',
      );
}

// ── Evidence Panel (mandatory upload) ─────────────────────────
// Shown when quiz_questions.requires_evidence = true.
// The user must upload at least one file before the Next button is enabled.
class _EvidencePanel extends StatefulWidget {
  final String sessionId;
  final String questionId;
  final String? answerId;
  final String? promptText;
  final List<_PendingFile> pendingFiles;
  final bool alreadyAnswered;
  final _AnsNotifier notifier;
  final int? sufficiencyPcntg;

  const _EvidencePanel({
    required this.sessionId,
    required this.questionId,
    this.answerId,
    required this.promptText,
    required this.pendingFiles,
    required this.alreadyAnswered,
    required this.notifier,
    this.sufficiencyPcntg,
  });

  @override
  State<_EvidencePanel> createState() => _EvidencePanelState();
}

class _EvidencePanelState extends State<_EvidencePanel> {
  bool   _uploading = false;
  bool   _analyzing = false;
  double _uploadProgress = 0.0;
  String? _uploadError;
  bool   _reviewingEvidence = false;
  int?   _sufficiency;
  String? _reviewDecision;
  String? _reviewSummary;
  List<_ServerFile> _serverFiles = [];
  bool _filesFetched = false;

  @override
  void initState() {
    super.initState();
    _sufficiency = widget.sufficiencyPcntg;
  }

  @override
  void didUpdateWidget(_EvidencePanel old) {
    super.didUpdateWidget(old);
    if (old.answerId != widget.answerId) {
      setState(() { _filesFetched = false; _serverFiles = []; });
    }
    if (old.sufficiencyPcntg != widget.sufficiencyPcntg) {
      setState(() => _sufficiency = widget.sufficiencyPcntg);
    }
  }

  Future<void> _fetchServerFiles(WidgetRef ref) async {
    if (widget.answerId == null) return;
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get<List<dynamic>>(
        '/answers/${widget.answerId}/files',
      );
      if (!mounted) return;
      setState(() {
        _serverFiles = (res.data ?? [])
            .cast<Map<String, dynamic>>()
            .map(_ServerFile.fromJson)
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _pickAndUpload(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) return;

    setState(() {
      _uploading = true;
      _analyzing = false;
      _uploadProgress = 0.0;
      _uploadError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: picked.name),
      });
      final uploadRes = await dio.post<Map<String, dynamic>>(
        '/files/upload',
        data: formData,
        onSendProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          final progress = sent / total;
          setState(() {
            _uploadProgress = progress;
            if (progress >= 1.0) _analyzing = true;
          });
        },
      );
      final data   = uploadRes.data!;
      final fileId = data['id'] as String;
      widget.notifier.addPendingFile(
        widget.questionId,
        fileId,
        picked.name,
        fileText:         data['fileText'] as String?,
        imageDescription: data['imageDescription'] as String?,
      );
    } catch (e) {
      if (mounted) setState(() => _uploadError = 'Upload failed. Please try again.');
    } finally {
      if (mounted) setState(() { _uploading = false; _analyzing = false; });
    }
  }

  Future<void> _removeServerFile(WidgetRef ref, _ServerFile f) async {
    if (widget.answerId == null) return;
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/answers/${widget.answerId}/files/${f.id}');
      if (mounted) setState(() => _serverFiles.removeWhere((x) => x.id == f.id));
    } catch (_) {}
  }

  Future<void> _reviewEvidence(WidgetRef ref) async {
    if (widget.answerId == null) return;
    setState(() => _reviewingEvidence = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post<Map<String, dynamic>>(
        '/evidence-review',
        data: {'type': 'answer', 'elementId': widget.answerId},
      );
      if (!mounted) return;
      final d = res.data!;
      setState(() {
        _sufficiency    = (d['evidenceSufficiencyPcntg'] as num?)?.toInt();
        _reviewDecision = d['decision'] as String?;
        _reviewSummary  = d['summary'] as String?;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _reviewingEvidence = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        // Fetch server files once per answerId
        if (widget.answerId != null && !_filesFetched) {
          _filesFetched = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fetchServerFiles(ref);
          });
        }

        final allFiles = [..._serverFiles.map((f) => _FileEntry.server(f)),
                          ...widget.pendingFiles.map((f) => _FileEntry.pending(f))];
        final hasFiles = allFiles.isNotEmpty;
        final baseUrl  = ref.read(dioProvider).options.baseUrl;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: label + sufficiency badge ─────────────────
            Row(children: [
              const Icon(Icons.attach_file_rounded,
                  size: 14, color: AppColors.muted),
              const Gap(6),
              Expanded(
                child: Text(
                  widget.promptText != null && widget.promptText!.isNotEmpty
                      ? widget.promptText!
                      : 'Evidence',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151)),
                ),
              ),
              if (_sufficiency != null)
                _SufficiencyBadge(pcntg: _sufficiency!),
            ]),
            const Gap(8),

            // ── Review summary box ─────────────────────────────────
            if (_reviewSummary != null && _reviewSummary!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_reviewDecision == 'APPROVE'
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFD97706))
                      .withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (_reviewDecision == 'APPROVE'
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFD97706))
                        .withOpacity(0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _reviewDecision == 'APPROVE'
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                      size: 15,
                      color: _reviewDecision == 'APPROVE'
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFD97706),
                    ),
                    const Gap(8),
                    Expanded(
                      child: Text(_reviewSummary!,
                          style: const TextStyle(fontSize: 12, height: 1.5)),
                    ),
                  ],
                ),
              ),
              const Gap(8),
            ],

            // ── Upload progress ────────────────────────────────────
            if (_uploading) ...[
              if (_analyzing) ...[
                Row(children: [
                  const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.8, color: Color(0xFF7C3AED)),
                  ),
                  const Gap(8),
                  Text(AppLocalizations.of(context).aiAnalyzingDocument,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7C3AED))),
                ]),
              ] else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _uploadProgress > 0 ? _uploadProgress : null,
                    backgroundColor: const Color(0xFFE5E7EB),
                    color: AppColors.blue,
                    minHeight: 4,
                  ),
                ),
                const Gap(4),
                Text(
                  'Uploading… ${(_uploadProgress * 100).toInt()}%',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.muted),
                ),
              ],
              const Gap(8),
            ],

            // ── File rows ─────────────────────────────────────────
            if (!hasFiles && !_uploading)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'No evidence uploaded yet.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
              )
            else
              ...allFiles.map((entry) => _EvidenceFileEntryRow(
                    entry: entry,
                    baseUrl: baseUrl,
                    onRemoveServer: (f) => _removeServerFile(ref, f),
                    onRemovePending: (f) =>
                        widget.notifier.removePendingFile(widget.questionId, f.id),
                    onView: (entry) => showDialog(
                      context: context,
                      builder: (_) => _EvidenceViewerDialog(entry: entry),
                    ),
                  )),

            if (_uploadError != null) ...[
              const Gap(4),
              Text(_uploadError!,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
            ],

            // ── Buttons ───────────────────────────────────────────
            const Gap(10),
            Row(children: [
              OutlinedButton.icon(
                onPressed: _uploading ? null : () => _pickAndUpload(ref),
                icon: const Icon(Icons.upload_file_outlined, size: 15),
                label: Text(hasFiles ? 'הוסף ראיה' : 'הוסף ראיה',
                    style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.blue,
                  side: const BorderSide(color: AppColors.blue),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              if (hasFiles && widget.answerId != null) ...[
                const Gap(10),
                OutlinedButton.icon(
                  onPressed: _reviewingEvidence ? null : () => _reviewEvidence(ref),
                  icon: _reviewingEvidence
                      ? const SizedBox(
                          width: 13, height: 13,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF6C3FC5)),
                        )
                      : const Icon(Icons.fact_check_outlined, size: 15),
                  label: Text(
                    _reviewingEvidence ? 'Reviewing…' : 'Review Evidence',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6C3FC5),
                    side: const BorderSide(color: Color(0xFF6C3FC5)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ]),
          ],
        );
      },
    );
  }
}

// ── Unified file entry (server-linked or pending) ──────────────
class _FileEntry {
  final _ServerFile? server;
  final _PendingFile? pending;
  const _FileEntry.server(this.server) : pending = null;
  const _FileEntry.pending(this.pending) : server = null;

  String get name     => server?.fileName ?? pending?.name ?? '';
  String get fileId   => server?.fileId   ?? pending?.id   ?? '';
  String? get text    => server?.fileText ?? pending?.fileText;
  String? get imgDesc => server?.imageDescription ?? pending?.imageDescription;
  String? get date    => server?.createdAt;
  bool   get isImage  => imgDesc != null && imgDesc!.isNotEmpty;
  bool   get hasContent => (text != null && text!.isNotEmpty) ||
                           (imgDesc != null && imgDesc!.isNotEmpty);
}

class _EvidenceFileEntryRow extends StatelessWidget {
  final _FileEntry entry;
  final String baseUrl;
  final void Function(_ServerFile) onRemoveServer;
  final void Function(_PendingFile) onRemovePending;
  final void Function(_FileEntry entry) onView;

  const _EvidenceFileEntryRow({
    required this.entry,
    required this.baseUrl,
    required this.onRemoveServer,
    required this.onRemovePending,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = entry.date != null
        ? entry.date!.substring(0, 10).split('-').reversed.join('/')
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          // Delete
          GestureDetector(
            onTap: () {
              if (entry.server != null) onRemoveServer(entry.server!);
              else if (entry.pending != null) onRemovePending(entry.pending!);
            },
            child: const Icon(Icons.delete_outline_rounded,
                size: 16, color: Color(0xFFDC2626)),
          ),
          const Gap(8),
          // Download (server files only)
          if (entry.server != null) ...[
            GestureDetector(
              onTap: () async {
                final url = Uri.parse('$baseUrl/files/${entry.fileId}/download');
                if (await canLaunchUrl(url)) launchUrl(url);
              },
              child: const Icon(Icons.download_outlined,
                  size: 16, color: Color(0xFF16A34A)),
            ),
            const Gap(8),
          ],
          // View content
          if (entry.hasContent) ...[
            GestureDetector(
              onTap: () => onView(entry),
              child: const Icon(Icons.visibility_outlined,
                  size: 16, color: AppColors.blue),
            ),
            const Gap(8),
          ],
          // Name + date + type icon
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(entry.name,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right),
                if (dateStr != null)
                  Text(dateStr,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          const Gap(8),
          Icon(
            entry.isImage
                ? Icons.image_outlined
                : Icons.insert_drive_file_outlined,
            size: 16,
            color: const Color(0xFF9CA3AF),
          ),
        ],
      ),
    );
  }
}

// ── Evidence content viewer dialog ────────────────────────────
// Mirrors _EvidenceViewerDialog in task_edit_dialog.dart:
//   • Documents → _DocumentView  (parses structured JSON or falls back to plain text)
//   • Images    → _ImageDescriptionView  (AI-generated description)
class _EvidenceViewerDialog extends StatelessWidget {
  final _FileEntry entry;
  const _EvidenceViewerDialog({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isImage = entry.isImage;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                color: isImage
                    ? const Color(0xFF0EA5E9).withOpacity(0.08)
                    : AppColors.blue.withOpacity(0.08),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                border: const Border(
                    bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Icon(
                    isImage
                        ? Icons.image_outlined
                        : Icons.article_outlined,
                    color: isImage
                        ? const Color(0xFF0EA5E9)
                        : AppColors.blue,
                    size: 20,
                  ),
                  const Gap(10),
                  Expanded(
                    child: Text(
                      entry.name.isNotEmpty ? entry.name : 'Evidence',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.muted,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // ── Body ───────────────────────────────────────────
            Expanded(
              child: isImage
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _ImageDescriptionView(
                          description: entry.imgDesc ?? ''),
                    )
                  : _DocumentView(fileText: entry.text ?? ''),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Structured document renderer ──────────────────────────────
// Parses {"title":"…","content":[{"sectionName":"…","sectionContent":"…"}]}
// Falls back to plain selectable text for any other format.
// When 2+ named sections exist, shows a left TOC panel with scroll-to on tap.
class _DocumentView extends StatefulWidget {
  final String fileText;
  const _DocumentView({required this.fileText});

  @override
  State<_DocumentView> createState() => _DocumentViewState();
}

class _DocumentViewState extends State<_DocumentView> {
  final _scrollController = ScrollController();
  final _sectionKeys = <GlobalKey>[];
  int _activeSection = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(int index) {
    if (index < 0 || index >= _sectionKeys.length) return;
    setState(() => _activeSection = index);
    final ctx = _sectionKeys[index].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.05,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fileText.isEmpty) {
      return Center(
        child: Text('No content available.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
      );
    }

    try {
      final decoded = jsonDecode(widget.fileText) as Map<String, dynamic>;
      final title = decoded['title'] as String? ?? '';
      final content =
          (decoded['content'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      // Build section key list (one per section)
      while (_sectionKeys.length < content.length) {
        _sectionKeys.add(GlobalKey());
      }

      final hasToc = content.length >= 2 &&
          content.any((s) => (s['sectionName'] as String? ?? '').isNotEmpty);

      if (hasToc) {
        // ── Two-panel layout: TOC left, content right ──────────
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left TOC panel
            Container(
              width: 190,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F8),
                border: Border(
                  right: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 16, 14, 8),
                    child: Text(
                      'CONTENTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: content.length,
                      itemBuilder: (context, i) {
                        final name =
                            content[i]['sectionName'] as String? ?? '';
                        final isActive = i == _activeSection;
                        return InkWell(
                          onTap: () => _scrollTo(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF1A237E).withOpacity(0.08)
                                  : Colors.transparent,
                              border: Border(
                                left: BorderSide(
                                  color: isActive
                                      ? const Color(0xFF1A237E)
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? const Color(0xFF1A237E)
                                        : const Color(0xFF9CA3AF),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isActive
                                          ? const Color(0xFF1A237E)
                                          : const Color(0xFF374151),
                                      fontWeight: isActive
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Right content panel
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty) ...[
                      Text(title,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A237E))),
                      const Gap(12),
                      const Divider(color: Color(0xFFE5E7EB)),
                      const Gap(16),
                    ],
                    ...List.generate(content.length, (i) {
                      final section = content[i];
                      final name = section['sectionName'] as String? ?? '';
                      final body = section['sectionContent'] as String? ?? '';
                      return Padding(
                        key: _sectionKeys[i],
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (name.isNotEmpty) ...[
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A237E),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A237E),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Gap(10),
                            ],
                            SelectableText(
                              body,
                              style:
                                  const TextStyle(fontSize: 13, height: 1.7),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Gap(40),
                  ],
                ),
              ),
            ),
          ],
        );
      }

      // ── Single-column fallback (0 or 1 sections) ───────────
      return SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) ...[
              Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A237E))),
              const Gap(12),
              const Divider(color: Color(0xFFE5E7EB)),
              const Gap(16),
            ],
            ...content.map((section) {
              final name = section['sectionName'] as String? ?? '';
              final body = section['sectionContent'] as String? ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EAF6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A237E))),
                      ),
                      const Gap(8),
                    ],
                    SelectableText(body,
                        style: const TextStyle(fontSize: 13, height: 1.6)),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    } catch (_) {
      // Not structured JSON — show as plain selectable text
      return SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        child: SelectableText(widget.fileText,
            style: const TextStyle(fontSize: 13, height: 1.6)),
      );
    }
  }
}

// ── AI image description renderer ─────────────────────────────
class _ImageDescriptionView extends StatelessWidget {
  final String description;
  const _ImageDescriptionView({required this.description});

  @override
  Widget build(BuildContext context) {
    if (description.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context).noDescriptionAvailable,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF9CA3AF))),
      );
    }
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.auto_awesome_outlined,
              size: 16, color: Color(0xFF0EA5E9)),
          const Gap(6),
          Text(l10n.aiGeneratedDescription,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0EA5E9))),
        ]),
        const Gap(12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.3)),
          ),
          child: SelectableText(
            description,
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
        ),
      ],
    );
  }
}

// ── Evidence Notice (conditional, based on answer value) ──────
class _EvidenceNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFD97706)),
          Gap(8),
          Expanded(
            child: Text(
              'Evidence may be required based on your answer.',
              style: TextStyle(
                color: Color(0xFFD97706),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Yes/No Input ──────────────────────────────────────────────
class _YesNoInput extends StatelessWidget {
  final int? value;
  final void Function(int) onChanged;

  const _YesNoInput({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _AnswerButton(
            label: l10n.yes,
            sublabel: l10n.pressY,
            icon: Icons.check_rounded,
            selected: value == 1,
            activeColor: _kDone,
            onTap: () => onChanged(1),
          ),
        ),
        const Gap(14),
        Expanded(
          child: _AnswerButton(
            label: l10n.no,
            sublabel: l10n.pressN,
            icon: Icons.close_rounded,
            selected: value == 0,
            activeColor: AppColors.danger,
            onTap: () => onChanged(0),
          ),
        ),
      ],
    );
  }
}

class _AnswerButton extends StatefulWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _AnswerButton({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  State<_AnswerButton> createState() => _AnswerButtonState();
}

class _AnswerButtonState extends State<_AnswerButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: sel
                ? widget.activeColor
                : _hovered
                    ? widget.activeColor.withOpacity(0.06)
                    : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel
                  ? widget.activeColor
                  : _hovered
                      ? widget.activeColor.withOpacity(0.4)
                      : const Color(0xFFE2E8F0),
              width: sel ? 2 : 1.5,
            ),
            boxShadow: sel
                ? [BoxShadow(color: widget.activeColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
                : null,
          ),
          child: Column(
            children: [
              Icon(widget.icon,
                  color: sel ? Colors.white : widget.activeColor.withOpacity(0.7),
                  size: 26),
              const Gap(6),
              Text(
                widget.label,
                style: TextStyle(
                  color: sel ? Colors.white : const Color(0xFF374151),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const Gap(2),
              Text(
                widget.sublabel,
                style: TextStyle(
                  color: sel ? Colors.white60 : _kMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── One Pick Input ────────────────────────────────────────────
class _OnePickInput extends StatelessWidget {
  final List<Map<String, dynamic>> options;
  final String? selectedId;
  final void Function(String) onChanged;

  const _OnePickInput({
    required this.options,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.asMap().entries.map((e) {
        final idx  = e.key;
        final opt  = e.value;
        final id   = opt['id'] as String;
        final text = opt['optionText'] as String? ?? '';
        final sel  = selectedId == id;
        // Keyboard letter hint (A, B, C…)
        final letter = String.fromCharCode(65 + idx);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _OptionRow(
            id:     id,
            text:   text,
            letter: letter,
            sel:    sel,
            radio:  true,
            onTap:  () => onChanged(id),
          ),
        );
      }).toList(),
    );
  }
}

// ── Multi Pick Input ──────────────────────────────────────────
class _MultiPickInput extends StatelessWidget {
  final List<Map<String, dynamic>> options;
  final Set<String> selected;
  final void Function(String) onToggle;

  const _MultiPickInput({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).selectAllThatApply,
          style: const TextStyle(color: _kMuted, fontSize: 11, fontWeight: FontWeight.w500),
        ),
        const Gap(8),
        ...options.asMap().entries.map((e) {
          final idx  = e.key;
          final opt  = e.value;
          final id   = opt['id'] as String;
          final text = opt['optionText'] as String? ?? '';
          final sel  = selected.contains(id);
          final letter = String.fromCharCode(65 + idx);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionRow(
              id:     id,
              text:   text,
              letter: letter,
              sel:    sel,
              radio:  false,
              onTap:  () => onToggle(id),
            ),
          );
        }),
      ],
    );
  }
}

// ── Shared Option Row ─────────────────────────────────────────
class _OptionRow extends StatefulWidget {
  final String id;
  final String text;
  final String letter;
  final bool sel;
  final bool radio;
  final VoidCallback onTap;

  const _OptionRow({
    required this.id,
    required this.text,
    required this.letter,
    required this.sel,
    required this.radio,
    required this.onTap,
  });

  @override
  State<_OptionRow> createState() => _OptionRowState();
}

class _OptionRowState extends State<_OptionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.sel;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: sel
                ? _kGrad2.withOpacity(0.08)
                : _hovered
                    ? _kGrad2.withOpacity(0.04)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? _kGrad2 : _hovered ? _kGrad2.withOpacity(0.3) : const Color(0xFFE2E8F0),
              width: sel ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Letter badge
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 24, height: 24,
                decoration: BoxDecoration(
                  shape: widget.radio ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: widget.radio ? null : BorderRadius.circular(6),
                  color: sel ? _kGrad2 : Colors.transparent,
                  border: Border.all(
                    color: sel ? _kGrad2 : const Color(0xFFCBD5E1),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: sel
                      ? Icon(
                          widget.radio ? Icons.circle : Icons.check_rounded,
                          color: Colors.white,
                          size: widget.radio ? 8 : 13,
                        )
                      : Text(
                          widget.letter,
                          style: const TextStyle(
                            color: _kMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const Gap(12),
              Expanded(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    color: sel ? _kGrad1 : const Color(0xFF374151),
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Text Input ────────────────────────────────────────────────
class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onChanged;

  const _TextInput({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged:  onChanged,
      maxLines:   5,
      style: const TextStyle(fontSize: 14, color: _kText),
      decoration: InputDecoration(
        hintText: 'Type your answer here…',
        hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kGrad2, width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }
}

// ── Numeric Input ─────────────────────────────────────────────
class _NumericInput extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onChanged;

  const _NumericInput({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          onChanged:  onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _kText,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(
              color: _kMuted.withOpacity(0.5),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kGrad2, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  )
                : null,
          ),
        ),
        const Gap(8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline_rounded, size: 13, color: _kMuted.withOpacity(0.7)),
            const Gap(4),
            Text(
              'Enter a number',
              style: TextStyle(fontSize: 12, color: _kMuted.withOpacity(0.7)),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Nav Bar ───────────────────────────────────────────────────
class _NavBar extends StatelessWidget {
  final bool canGoBack;
  final bool canAdvance;
  final bool isLast;
  final bool saving;
  final int current;
  final int total;
  final String? error;
  final VoidCallback onBack;
  final Future<void> Function() onNext;

  const _NavBar({
    required this.canGoBack,
    required this.canAdvance,
    required this.isLast,
    required this.saving,
    required this.current,
    required this.total,
    required this.error,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: BoxDecoration(
        color: _kCard,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error
              if (error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(error!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                ),
              Row(
                children: [
                  // Back
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.muted,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    ),
                    onPressed: canGoBack && !saving ? onBack : null,
                    icon: const Icon(Icons.arrow_back_rounded, size: 15),
                    label: Text(AppLocalizations.of(context).back),
                  ),

                  // Counter
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '$current / $total',
                          style: const TextStyle(
                            color: _kText,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context).questionsAnsweredPct(total == 0 ? 0 : ((current - 1) * 100 ~/ total)),
                          style: const TextStyle(color: _kMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),

                  // Next / Finish
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: saving
                          ? _kGrad1
                          : !canAdvance
                              ? const Color(0xFFE2E8F0)
                              : isLast
                                  ? _kDone
                                  : _kGrad1,
                      foregroundColor: canAdvance ? Colors.white : const Color(0xFF94A3B8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    ),
                    onPressed: saving ? null : () => onNext(),
                    icon: saving
                        ? const SizedBox(
                            width: 15, height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(
                            !canAdvance
                                ? Icons.lock_rounded
                                : isLast
                                    ? Icons.check_circle_rounded
                                    : Icons.arrow_forward_rounded,
                            size: 15,
                          ),
                    label: Text(
                      isLast ? AppLocalizations.of(context).finish : AppLocalizations.of(context).next,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Finished View ─────────────────────────────────────────────
// Calls the analyze endpoint on mount, shows animated analyzing phase,
// then reveals quiz results + tasks-created count.
class _FinishedView extends ConsumerStatefulWidget {
  final String sessionId;
  final String workflowName;
  final int totalAnswered;
  final int totalQuestions;
  final Map<String, String> quizResults;

  const _FinishedView({
    required this.sessionId,
    required this.workflowName,
    required this.totalAnswered,
    required this.totalQuestions,
    required this.quizResults,
  });

  @override
  ConsumerState<_FinishedView> createState() => _FinishedViewState();
}

class _FinishedViewState extends ConsumerState<_FinishedView> {
  // Analysis phases
  bool _analyzing = true;
  int? _tasksCreated;
  String? _analyzeError;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    final dio = ref.read(dioProvider);

    // LLM gap analysis can take 1-3 minutes (loads docs + calls GPT-4o).
    // On Flutter Web, BrowserHttpClientAdapter uses connectTimeout as the
    // overall XHR timeout — per-request Options.receiveTimeout is ignored.
    // We temporarily widen both timeouts and restore them in finally.
    final origConnect = dio.options.connectTimeout;
    final origReceive = dio.options.receiveTimeout;
    dio.options.connectTimeout = const Duration(minutes: 4);
    dio.options.receiveTimeout  = const Duration(minutes: 4);

    try {
      final res = await dio.post<Map<String, dynamic>>(
        '/workflow-answers/${widget.sessionId}/analyze',
      );
      final created = res.data?['tasksCreated'] as int? ?? 0;
      if (mounted) {
        setState(() {
          _analyzing = false;
          _tasksCreated = created;
        });
      }
    } catch (e) {
      // Non-critical: show done screen even if analysis fails.
      // Extract a short human-readable message from DioException.
      String msg;
      if (e is DioException) {
        final data = e.response?.data;
        final detail = data is Map ? data['detail']?.toString() : null;
        if (detail != null) {
          msg = detail;
        } else if (e.type == DioExceptionType.connectionTimeout ||
                   e.type == DioExceptionType.receiveTimeout ||
                   e.type == DioExceptionType.sendTimeout) {
          msg = 'The request timed out. The analysis may still be running — please try again in a moment.';
        } else {
          msg = e.message ?? 'Unknown error';
        }
      } else {
        msg = e.toString().replaceFirst('Exception: ', '');
      }
      if (mounted) {
        setState(() {
          _analyzing = false;
          _analyzeError = msg;
        });
      }
    } finally {
      // Always restore the original timeouts
      dio.options.connectTimeout = origConnect;
      dio.options.receiveTimeout  = origReceive;
    }
  }

  // Color for result badge
  static Color _resultColor(String label) {
    switch (label.toUpperCase()) {
      case 'HIGH':     return const Color(0xFFDC2626);
      case 'MEDIUM':   return const Color(0xFFD97706);
      case 'BASIC':    return const Color(0xFF2563EB);
      case 'COMPLETE': return const Color(0xFF16A34A);
      default:         return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Animated checkmark ─────────────────────────────
              Container(
                padding: const EdgeInsets.all(30),
                decoration: const BoxDecoration(color: _kDoneBg, shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded, size: 64, color: _kDone),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0, 0),
                    duration: 500.ms,
                    curve: Curves.elasticOut,
                  )
                  .fadeIn(duration: 200.ms),
              const Gap(24),

              Text(
                AppLocalizations.of(context).allDone,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _kText,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(delay: 250.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),
              const Gap(8),
              Text(
                AppLocalizations.of(context).youCompleted(widget.workflowName),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: _kSub, height: 1.5),
              ).animate().fadeIn(delay: 350.ms, duration: 400.ms),
              const Gap(24),

              // ── Stats row ──────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatBadge(
                    icon: Icons.quiz_rounded,
                    label: 'Answered',
                    value: '${widget.totalAnswered} / ${widget.totalQuestions}',
                    color: _kDone,
                  ),
                  const Gap(12),
                  _StatBadge(
                    icon: Icons.percent_rounded,
                    label: 'Completion',
                    value: widget.totalQuestions == 0
                        ? '100%'
                        : '${(widget.totalAnswered * 100 ~/ widget.totalQuestions)}%',
                    color: _kGrad2,
                  ),
                ],
              ).animate().fadeIn(delay: 450.ms, duration: 400.ms),
              const Gap(24),

              // ── AI Analysis panel ──────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: _analyzing
                    ? _AnalyzingPanel(key: const ValueKey('analyzing'))
                    : _analyzeError != null
                        ? _AnalyzeErrorPanel(
                            key: const ValueKey('error'),
                            error: _analyzeError!,
                            onRetry: () {
                              setState(() {
                                _analyzing = true;
                                _analyzeError = null;
                              });
                              _runAnalysis();
                            },
                          )
                        : _TasksCreatedPanel(
                            key: const ValueKey('done'),
                            tasksCreated: _tasksCreated ?? 0,
                          ),
              ),

              const Gap(28),

              // ── Dashboard button ───────────────────────────────
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _kGrad1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
                onPressed: () => context.go(AppRoutes.dashboard),
                icon: const Icon(Icons.dashboard_outlined, size: 18),
                label: Text(AppLocalizations.of(context).goToDashboard,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ).animate().fadeIn(delay: 600.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Analyzing animation panel ──────────────────────────────────
class _AnalyzingPanel extends StatelessWidget {
  const _AnalyzingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEDE9FE), Color(0xFFF5F3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(
              color: Color(0xFF7C3AED),
              strokeWidth: 2.5,
            ),
          ),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI is analyzing your responses…',
                  style: TextStyle(
                    color: Color(0xFF5B21B6),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(2),
                const Text(
                  'Identifying compliance gaps — this may take up to a minute',
                  style: TextStyle(
                    color: Color(0xFF7C3AED),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          delay: 600.ms,
          duration: 1800.ms,
          color: Colors.white.withOpacity(0.4),
        );
  }
}

// ── Tasks created panel ────────────────────────────────────────
class _TasksCreatedPanel extends StatelessWidget {
  final int tasksCreated;
  const _TasksCreatedPanel({super.key, required this.tasksCreated});

  @override
  Widget build(BuildContext context) {
    final hasTasks = tasksCreated > 0;
    final bg     = hasTasks ? const Color(0xFFFEF3C7) : const Color(0xFFF0FDF4);
    final border = hasTasks ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0);
    final icon   = hasTasks ? Icons.task_alt_rounded  : Icons.check_circle_outline_rounded;
    final iconColor = hasTasks ? const Color(0xFFD97706) : _kDone;
    final label  = hasTasks
        ? '$tasksCreated compliance task${tasksCreated != 1 ? 's' : ''} created'
        : 'No compliance gaps found';
    final sub    = hasTasks
        ? 'Review your tasks in the Task Board'
        : 'All requirements appear to be met';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    )),
                const Gap(2),
                Text(sub,
                    style: TextStyle(
                      color: iconColor.withOpacity(0.75),
                      fontSize: 11,
                    )),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }
}

// ── Analyze error panel ────────────────────────────────────────
class _AnalyzeErrorPanel extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _AnalyzeErrorPanel({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFDC2626), size: 22),
          const Gap(10),
          Expanded(
            child: Text(
              'Analysis failed: $error',
              style: const TextStyle(
                  color: Color(0xFFDC2626), fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Gap(8),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry',
                style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const Gap(6),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(color: _kMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Empty / Loading / Error ───────────────────────────────────
class _EmptyView extends StatelessWidget {
  final String workflowName;
  const _EmptyView({required this.workflowName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.quiz_outlined, size: 52, color: Color(0xFFCBD5E1)),
        const Gap(16),
        Text(
          'No questions found in "$workflowName".\nAdd quizzes with questions first.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _kMuted, fontSize: 14),
        ),
      ]),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(
          width: 48, height: 48,
          child: CircularProgressIndicator(
            color: _kGrad2,
            strokeWidth: 3,
          ),
        ),
        const Gap(16),
        Text(AppLocalizations.of(context).loadingQuestions,
            style: const TextStyle(color: _kMuted, fontSize: 13)),
      ])
          .animate()
          .fadeIn(duration: 300.ms),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                color: AppColors.dangerLight, shape: BoxShape.circle),
            child: const Icon(Icons.error_outline_rounded,
                size: 40, color: AppColors.danger),
          ),
          const Gap(16),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          const Gap(20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(AppLocalizations.of(context).retry),
          ),
        ]),
      ),
    );
  }
}

// ── Evidence sufficiency badge ────────────────────────────────────────────────
class _SufficiencyBadge extends StatelessWidget {
  final int pcntg;
  const _SufficiencyBadge({required this.pcntg});

  Color get _color {
    if (pcntg >= 75) return const Color(0xFF16A34A);
    if (pcntg >= 40) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, size: 11, color: _color),
          const Gap(4),
          Text(
            '$pcntg%',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: _color),
          ),
        ],
      ),
    );
  }
}

