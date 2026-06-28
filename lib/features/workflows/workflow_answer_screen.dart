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
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/platform/file_download.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/customer/customer_context_provider.dart';
import '../../core/models/workflow_answer_group.dart';
import '../../core/widgets/gap_report_dialog.dart';
import '../../core/widgets/reanalyze_dialog.dart';
import '../../l10n/app_localizations.dart';

// ── Palette ───────────────────────────────────────────────────
const _kGrad1   = Color(0xFF005A9E);
const _kGrad2   = Color(0xFF0078D4);
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (fileText != null) 'fileText': fileText,
        if (imageDescription != null) 'imageDescription': imageDescription,
      };

  factory _PendingFile.fromJson(Map<String, dynamic> j) => _PendingFile(
        id: j['id'] as String,
        name: j['name'] as String? ?? '(file)',
        fileText: j['fileText'] as String?,
        imageDescription: j['imageDescription'] as String?,
      );
}


/// Persists the per-question pending-files queue across navigation /
/// env-switches / app restarts so file blobs that were uploaded but
/// not yet linked don't become orphans. Keyed by `sessionId` so each
/// env-session in a group has its own queue.
class _PendingFilesStore {
  static String _key(String sessionId) => 'pending_files::$sessionId';

  static Future<Map<String, List<_PendingFile>>> load(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(sessionId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((qid, list) => MapEntry(
            qid,
            (list as List)
                .map((e) => _PendingFile.fromJson(e as Map<String, dynamic>))
                .toList(),
          ));
    } catch (_) {
      return {};
    }
  }

  static Future<void> save(
      String sessionId, Map<String, List<_PendingFile>> queue) async {
    final prefs = await SharedPreferences.getInstance();
    if (queue.isEmpty) {
      await prefs.remove(_key(sessionId));
      return;
    }
    final encoded = jsonEncode(queue.map(
      (qid, list) => MapEntry(qid, list.map((f) => f.toJson()).toList()),
    ));
    await prefs.setString(_key(sessionId), encoded);
  }
}

// ── Local answer model ────────────────────────────────────────
class _LocalAns {
  int? answerNumber;
  String answerText;
  Set<String> pickedOptionIds;
  // Step 36: per-environment answers. NON-EMPTY only for questions whose
  // `isDataEnvironmentQuestion` is true. Key = customer_data_environment_id;
  // value = answerNumber (1 for yes, 0 for no). When this is populated,
  // [answerNumber] / [answerText] / [pickedOptionIds] are ignored for the
  // per-env submit (POST /answers/bulk).
  Map<String, int> envAnswers;
  int? evidenceSufficiencyPcntg; // loaded from server, shown as badge
  String? evidenceDecision;      // 'APPROVE' | 'INSUFFICIENT'
  String? evidenceSummary;       // LLM short summary
  String? evidenceReason;        // LLM reasoning
  String? answerId;              // server answer ID — used to load evidence files

  _LocalAns({
    this.answerNumber,
    this.answerText = '',
    Set<String>? pickedOptionIds,
    Map<String, int>? envAnswers,
    this.evidenceSufficiencyPcntg,
    this.evidenceDecision,
    this.evidenceSummary,
    this.evidenceReason,
    this.answerId,
  }) : pickedOptionIds = pickedOptionIds ?? {},
       envAnswers = envAnswers ?? {};

  bool get hasValue =>
      answerNumber != null ||
      answerText.trim().isNotEmpty ||
      pickedOptionIds.isNotEmpty ||
      envAnswers.isNotEmpty;

  /// Step 36: true when EVERY env in [envIds] has an answer. Used by
  /// canAdvance for per-environment questions (single hasValue isn't
  /// enough — partial answers must keep the Next button disabled).
  bool allEnvsAnswered(Iterable<String> envIds) {
    final ids = envIds.toList();
    if (ids.isEmpty) return false;
    return ids.every(envAnswers.containsKey);
  }

  _LocalAns copyWith({
    int? answerNumber,
    bool clearAnswerNumber = false,
    String? answerText,
    Set<String>? pickedOptionIds,
    Map<String, int>? envAnswers,
    int? evidenceSufficiencyPcntg,
    bool clearSufficiency = false,
    String? evidenceDecision,
    String? evidenceSummary,
    String? evidenceReason,
    bool clearReview = false,
    String? answerId,
  }) =>
      _LocalAns(
        answerNumber:
            clearAnswerNumber ? null : (answerNumber ?? this.answerNumber),
        answerText: answerText ?? this.answerText,
        pickedOptionIds: pickedOptionIds ?? Set.from(this.pickedOptionIds),
        envAnswers: envAnswers ?? Map.from(this.envAnswers),
        evidenceSufficiencyPcntg: (clearSufficiency || clearReview)
            ? null
            : (evidenceSufficiencyPcntg ?? this.evidenceSufficiencyPcntg),
        evidenceDecision: clearReview
            ? null
            : (evidenceDecision ?? this.evidenceDecision),
        evidenceSummary: clearReview
            ? null
            : (evidenceSummary ?? this.evidenceSummary),
        evidenceReason: clearReview
            ? null
            : (evidenceReason ?? this.evidenceReason),
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
    // Restore any pending uploads that were saved to disk on a prior visit
    // (e.g. user uploaded evidence, switched envs, never submitted). The
    // restore is best-effort and runs in parallel with the session load.
    _restorePending();
    _load();
  }

  /// Coalesced disk persistence for the pending-files queue.
  ///
  /// Multiple add/remove actions in quick succession (e.g. upload A → remove A
  /// → upload B) would otherwise schedule N parallel SharedPreferences
  /// writes, which can complete out of order and leave a stale snapshot on
  /// disk. Symptom: after notifier dispose+restore, file A reappears.
  ///
  /// This buffer tracks ONLY the latest target state; if a save is already in
  /// flight, we just update the target and return. The runner loop keeps
  /// draining `_pendingSaveState` until it matches the latest in-memory
  /// state, so disk ALWAYS ends up reflecting the most recent action.
  Map<String, List<_PendingFile>>? _pendingSaveState;
  bool _saveRunning = false;

  Future<void> _persistPending(Map<String, List<_PendingFile>> queue) async {
    _pendingSaveState = queue;
    if (_saveRunning) return;
    _saveRunning = true;
    try {
      while (_pendingSaveState != null) {
        final toSave = _pendingSaveState!;
        _pendingSaveState = null;
        await _PendingFilesStore.save(sessionId, toSave);
      }
    } finally {
      _saveRunning = false;
    }
  }

  /// Re-hydrate the pending-files queue from disk. If a persisted entry's
  /// question already has a server-saved answer, attempt to link it now
  /// so the file isn't left orphaned.
  Future<void> _restorePending() async {
    try {
      final disk = await _PendingFilesStore.load(sessionId);
      if (disk.isEmpty) return;
      // Merge into state (don't clobber any pending added since boot)
      final merged = Map<String, List<_PendingFile>>.from(state.pendingFiles);
      disk.forEach((qid, list) {
        merged[qid] = [...(merged[qid] ?? []), ...list];
      });
      state = state.copyWith(pendingFiles: merged);
      // Try to flush any pendings whose answer is already on the server.
      await _flushPendingForKnownAnswers();
    } catch (_) {
      // Restore failures are non-fatal — user can re-upload.
    }
  }

  /// For each persisted pending file, if the answer row already exists for
  /// that question, POST the link and drop it from the queue.
  Future<void> _flushPendingForKnownAnswers() async {
    final flushedQids = <String>{};
    final failures = <String>[];
    for (final entry in state.pendingFiles.entries) {
      final qid = entry.key;
      final ans = state.answers[qid];
      final aid = ans?.answerId;
      if (aid == null || entry.value.isEmpty) continue;
      bool allOk = true;
      for (final f in entry.value) {
        try {
          await _dio.post<dynamic>(
            '/answers/$aid/files',
            data: {'fileId': f.id},
          );
        } catch (e) {
          allOk = false;
          failures.add('${f.name}: ${_dioMsg(e)}');
        }
      }
      if (allOk) flushedQids.add(qid);
    }
    if (flushedQids.isNotEmpty) {
      final newPending = Map<String, List<_PendingFile>>.from(state.pendingFiles);
      for (final qid in flushedQids) {
        newPending.remove(qid);
      }
      state = state.copyWith(pendingFiles: newPending);
      await _persistPending(newPending);
    }
    if (failures.isNotEmpty) {
      state = state.copyWith(
        error: 'Evidence link failed: ${failures.first}'
              + (failures.length > 1 ? ' (+${failures.length - 1} more)' : ''),
      );
    }
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _dio.get<Map<String, dynamic>>(
          '/workflow-answers/$sessionId');
      final data = res.data!;

      // Step 36: a single question may have N answer rows for per-env
      // questions (one row per environment). Group by questionId — for
      // per-env answers, accumulate into envAnswers; for normal answers,
      // overwrite (only one row exists).
      final answers = <String, _LocalAns>{};
      for (final a in (data['answers'] as List? ?? [])) {
        final m = a as Map<String, dynamic>;
        final qId = m['questionId'] as String;
        final envId = m['customerDataEnvironmentId'] as String?;
        final num = m['answerNumber'] as int?;

        if (envId != null) {
          // Per-env answer — accumulate into the question's envAnswers map.
          final cur = answers[qId] ?? _LocalAns();
          if (num != null) cur.envAnswers[envId] = num;
          answers[qId] = cur;
          continue;
        }
        // Normal answer — single row per question.
        answers[qId] = _LocalAns(
          answerNumber: num,
          answerText: m['answerText'] as String? ?? '',
          pickedOptionIds:
              Set<String>.from(m['pickedOptionIds'] as List? ?? []),
          evidenceSufficiencyPcntg: m['evidenceSufficiencyPcntg'] as int?,
          evidenceDecision:         m['evidenceDecision']         as String?,
          evidenceSummary:          m['evidenceSummary']          as String?,
          evidenceReason:           m['evidenceReason']           as String?,
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

  /// Returns a new serverAnsweredIds set without [questionId] — so the
  /// evidence guard re-runs when the user changes a previously-saved answer.
  Set<String> _invalidateServerAnswered(String questionId) =>
      Set<String>.from(state.serverAnsweredIds)..remove(questionId);

  void setAnswerNumber(String questionId, int? v) {
    final cur = state.answers[questionId] ?? _LocalAns();
    if (cur.answerNumber == v) return; // no real change
    state = state.copyWith(
      answers: {
        ...state.answers,
        questionId: cur.copyWith(answerNumber: v, clearReview: true),
      },
      serverAnsweredIds: _invalidateServerAnswered(questionId),
      error: null,
    );
  }

  /// Step 36: set the yes/no answer for ONE environment of a per-env
  /// question. Other envs' answers are preserved. The bulk submit is
  /// triggered by the user clicking Next (we don't auto-advance per-env
  /// because the user has multiple rows to answer).
  void setEnvAnswerNumber(String questionId, String envId, int v) {
    final cur = state.answers[questionId] ?? _LocalAns();
    if (cur.envAnswers[envId] == v) return;
    final newEnvs = Map<String, int>.from(cur.envAnswers);
    newEnvs[envId] = v;
    state = state.copyWith(
      answers: {
        ...state.answers,
        questionId: cur.copyWith(envAnswers: newEnvs, clearReview: true),
      },
      serverAnsweredIds: _invalidateServerAnswered(questionId),
      error: null,
    );
  }

  void setAnswerText(String questionId, String v) {
    final cur = state.answers[questionId] ?? _LocalAns();
    if (cur.answerText == v) return;
    state = state.copyWith(
      answers: {
        ...state.answers,
        questionId: cur.copyWith(answerText: v, clearReview: true),
      },
      serverAnsweredIds: _invalidateServerAnswered(questionId),
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
        questionId:
            cur.copyWith(pickedOptionIds: newPicked, clearReview: true),
      },
      serverAnsweredIds: _invalidateServerAnswered(questionId),
      error: null,
    );
  }

  void setOnePickOption(String questionId, String optId) {
    final cur = state.answers[questionId] ?? _LocalAns();
    if (cur.pickedOptionIds.length == 1 && cur.pickedOptionIds.contains(optId)) return;
    state = state.copyWith(
      answers: {
        ...state.answers,
        questionId: cur.copyWith(
            pickedOptionIds: {optId},
            answerText: optId,
            clearReview: true),
      },
      serverAnsweredIds: _invalidateServerAnswered(questionId),
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
    // Fire-and-forget persistence — survives env-switch / app restart so
    // the file blob doesn't become an orphan if the answer never gets
    // submitted before the user leaves the screen.
    unawaited(_persistPending(updated));
  }

  void removePendingFile(String questionId, String fileId) {
    final updated = Map<String, List<_PendingFile>>.from(state.pendingFiles);
    updated[questionId] =
        (updated[questionId] ?? []).where((f) => f.id != fileId).toList();
    if (updated[questionId]!.isEmpty) updated.remove(questionId);
    state = state.copyWith(pendingFiles: updated);
    unawaited(_persistPending(updated));
  }

  // ── Navigation ──────────────────────────────────────────────

  Future<void> submitAndAdvance() async {
    final q = state.currentQuestion;
    if (q == null) return;

    final qId    = q['id'] as String;
    final qType  = q['qType'] as String;
    final quizId = state.currentQuiz!['id'] as String;
    final local  = state.answers[qId] ?? _LocalAns();
    // Step 36
    final isPerEnv = q['isDataEnvironmentQuestion'] as bool? ?? false;
    final envList = (q['environments'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const [];

    // Guard: must answer before advancing
    if (!local.hasValue) {
      state = state.copyWith(error: 'pleaseAnswerBeforeContinuing');
      return;
    }
    // Step 36: per-env requires ALL envs to be answered (partial = block).
    if (isPerEnv && !local.allEnvsAnswered(envList.map((e) => e['id'] as String))) {
      state = state.copyWith(error: 'pleaseAnswerBeforeContinuing');
      return;
    }

    // Guard: evidence required and condition met but evidence isn't approved.
    // NOTE: per-env questions skip the evidence flow in v1 — there's no
    // single answer_id to attach evidence to. The reviewer can attach
    // task-level evidence post-analysis instead.
    //
    // The check intentionally does NOT short-circuit on
    // serverAnsweredIds.contains(qId): the user may have submitted once,
    // gotten an INSUFFICIENT verdict, navigated away, and come back. In
    // that case we still need to block advance unless there are NEW
    // pending files to upload+review on this attempt.
    final reqsEv   = q['requiresEvidence'] as bool? ?? false;
    final evidCond = q['evidenceCondition'] as String?;
    if (!isPerEnv &&
        reqsEv &&
        _evidenceConditionMet(evidCond, local) &&
        local.evidenceDecision?.toUpperCase() != 'APPROVE') {
      final hasNewFiles = state.pendingFiles[qId]?.isNotEmpty ?? false;
      if (!hasNewFiles) {
        // No new files to re-trigger the review. Surface the prior
        // verdict's reason if we have one; otherwise the i18n placeholder.
        final priorReason =
            (local.evidenceReason ?? '').trim();
        state = state.copyWith(
          error: priorReason.isNotEmpty
              ? priorReason
              : 'evidenceRequiredBeforeContinuing',
        );
        return;
      }
    }

    state = state.copyWith(saving: true, error: null);

    // ── Step 36: per-environment bulk submit ───────────────────────────────
    // Branch early — bypasses the single-answer payload, evidence linking,
    // and evidence review (none apply to per-env in v1). On success we fall
    // through to the same _afterSubmitAdvance() that the normal path uses.
    if (isPerEnv) {
      try {
        final items = local.envAnswers.entries
            .map((e) => <String, dynamic>{
                  'customerDataEnvironmentId': e.key,
                  'answerNumber': e.value,
                })
            .toList();
        await _dio.post<dynamic>(
          '/workflow-answers/$sessionId/answers/bulk',
          data: <String, dynamic>{
            'quizId': quizId,
            'questionId': qId,
            'items': items,
            'nextQuizId': null,
            'nextQuestionId': null,
          },
        );
        // Mark as server-answered so the back-nav guard doesn't re-trigger.
        state = state.copyWith(
          serverAnsweredIds:
              Set<String>.from(state.serverAnsweredIds)..add(qId),
        );
        await _afterSubmitAdvance();
      } catch (e) {
        state = state.copyWith(saving: false, error: _dioMsg(e));
      }
      return;
    }

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
        // Mark the question as server-answered so canAdvance / evidence guard
        // recognise it next time the user navigates back.
        final updatedServerAnswered =
            Set<String>.from(state.serverAnsweredIds)..add(qId);
        state = state.copyWith(
          answers: updatedAnswers,
          serverAnsweredIds: updatedServerAnswered,
        );

        final toLink = List<_PendingFile>.from(state.pendingFiles[qId] ?? []);
        // Track which files actually got linked. Failures stay in the
        // queue (persisted) so the user can see what's still pending +
        // we can retry on next mount via _flushPendingForKnownAnswers.
        final stillPending = <_PendingFile>[];
        final linkErrors = <String>[];
        for (final f in toLink) {
          try {
            await _dio.post<dynamic>(
              '/answers/$answerId/files',
              data: {'fileId': f.id},
            );
          } catch (e) {
            stillPending.add(f);
            linkErrors.add('${f.name}: ${_dioMsg(e)}');
            // ignore: avoid_print
            print('[evidence-link] failed for $answerId / ${f.id}: $e');
          }
        }
        if (toLink.isNotEmpty) {
          final newPending = Map<String, List<_PendingFile>>.from(state.pendingFiles);
          if (stillPending.isEmpty) {
            newPending.remove(qId);
          } else {
            newPending[qId] = stillPending;
          }
          state = state.copyWith(pendingFiles: newPending);
          await _persistPending(newPending);
          if (linkErrors.isNotEmpty) {
            state = state.copyWith(
              error: 'Evidence link failed: ${linkErrors.first}'
                + (linkErrors.length > 1 ? ' (+${linkErrors.length - 1} more)' : ''),
            );
          }

          // ── 3b. Evidence review (blocking) ─────────────────────────────────
          // Files were just linked — run the review synchronously so we can
          // block navigation if the evidence is insufficient.
          try {
            final reviewRes = await _dio.post<Map<String, dynamic>>(
              '/evidence-review',
              data: {'type': 'answer', 'elementId': answerId},
            );
            final d = reviewRes.data ?? const <String, dynamic>{};
            final decision   = (d['decision'] as String? ?? '').toUpperCase();
            final summary    = d['summary']                  as String?;
            final reason     = d['reason']                   as String? ?? '';
            final pcntg      = (d['evidenceSufficiencyPcntg'] as num?)?.toInt();

            // Persist review results into local _LocalAns so the evidence
            // panel can show the decision badge / summary box when the user
            // navigates back to this question.
            final updatedAns = Map<String, _LocalAns>.from(state.answers);
            final cur = updatedAns[qId];
            if (cur != null) {
              updatedAns[qId] = cur.copyWith(
                evidenceDecision:        decision,
                evidenceSummary:         summary,
                evidenceReason:          reason,
                evidenceSufficiencyPcntg: pcntg,
              );
              state = state.copyWith(answers: updatedAns);
            }

            if (decision != 'APPROVE') {
              state = state.copyWith(
                saving: false,
                error: reason.isNotEmpty ? reason : 'Evidence is insufficient.',
              );
              return;
            }
          } catch (_) {
            // If the review call itself fails, allow navigation (non-blocking).
          }
        }
      }

      await _afterSubmitAdvance();
    } catch (e) {
      state = state.copyWith(saving: false, error: _dioMsg(e));
    }
  }

  /// Shared post-POST logic — runs after EITHER the normal single-answer
  /// submit OR the Step 36 per-environment bulk submit. Computes the
  /// current quiz's result (if this was its last visible question),
  /// scans forward for the next visible question, and updates state for
  /// the slide animation. Assumes `state.saving == true` on entry and
  /// always clears it on success.
  Future<void> _afterSubmitAdvance() async {
    final quizId = state.currentQuiz!['id'] as String;

    // ── If this was the last VISIBLE question of the current quiz,
    //    compute its result NOW so cross-quiz conditionals see fresh data. ─
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
        // Non-critical — result computation failure should not block nav.
      }
    }

    // ── Find the next VISIBLE question by scanning forward. ─────────────
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
      nextQuizIdx++;
      nextQIdx = 0;
    }

    if (!foundNext) finished = true;

    // ── When the entire workflow is done, mark this session as active ───
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
  }

  /// Extract a user-facing error message from a Dio/Exception object.
  /// Mirrors the pattern used elsewhere in the codebase.
  static String _dioMsg(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      final detail = data is Map ? data['detail']?.toString() : null;
      return detail ?? e.message ?? 'Network error';
    }
    return e.toString().replaceFirst('Exception: ', '');
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
  /// Either `sessionId` (legacy single-session entry point) or `groupId`
  /// (Step 41 grouped entry point) must be provided. When both are
  /// provided, `groupId` wins and the screen mounts in group mode with
  /// the chip-strip env switcher.
  final String? sessionId;
  final String? groupId;
  final String workflowName;

  const WorkflowAnswerScreen({
    super.key,
    this.sessionId,
    this.groupId,
    required this.workflowName,
  }) : assert(sessionId != null || groupId != null,
            'WorkflowAnswerScreen needs either sessionId or groupId');

  @override
  ConsumerState<WorkflowAnswerScreen> createState() =>
      _WorkflowAnswerScreenState();
}

class _WorkflowAnswerScreenState extends ConsumerState<WorkflowAnswerScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode             _keyFocus = FocusNode();
  String? _lastTextQuestionId;
  Timer?  _autoAdvanceTimer;

  // ── Step 41: group-mode state ────────────────────────────────
  // _envSessions is the chip-strip data; _currentSessionId is the
  // session id of the chip the user has selected. Both are null when
  // the screen is opened in legacy (single-session) mode.
  List<EnvSessionSummary> _envSessions = const [];
  String? _currentSessionId;
  bool _groupLoading = false;
  String? _groupError;

  /// The session id we should be watching right now:
  ///   - group mode: the active chip's session id (null until /
  ///     workflow-answer-groups/{id} resolves)
  ///   - legacy:     widget.sessionId (constructor-validated non-null)
  String? get _activeSessionId =>
      widget.groupId != null ? _currentSessionId : widget.sessionId;

  bool get _isGroupMode => widget.groupId != null;

  @override
  void initState() {
    super.initState();
    if (_isGroupMode) {
      _loadGroup();
    }
  }

  Future<void> _loadGroup() async {
    if (widget.groupId == null) return;
    setState(() {
      _groupLoading = true;
      _groupError = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get<Map<String, dynamic>>(
        '/workflow-answer-groups/${widget.groupId}',
      );
      final group = WorkflowAnswerGroupFull.fromJson(resp.data!);
      setState(() {
        _envSessions = group.envSessions;
        // Pick the first env that has answers in progress, else the
        // first env in the list. Both default to envSessions.first.
        final firstInProgress = group.envSessions.firstWhere(
          (e) => e.answeredCount > 0,
          orElse: () => group.envSessions.first,
        );
        _currentSessionId = firstInProgress.sessionId;
        _groupLoading = false;
      });
    } on DioException catch (e) {
      final detail = e.response?.data is Map
          ? (e.response!.data as Map)['detail']?.toString()
          : null;
      setState(() {
        _groupError = detail ?? 'Failed to load group: ${e.message ?? e}';
        _groupLoading = false;
      });
    } catch (e) {
      setState(() {
        _groupError = 'Failed to load group: $e';
        _groupLoading = false;
      });
    }
  }

  void _switchEnv(String sessionId) {
    if (sessionId == _currentSessionId) return;
    _autoAdvanceTimer?.cancel();
    // Reset the text-controller bookkeeping so the next q-text sync
    // doesn't re-fire for the wrong question.
    _lastTextQuestionId = null;
    setState(() => _currentSessionId = sessionId);
  }

  /// Step 41 — find the next env-session AFTER `currentSid` in the
  /// envSessions list order (which is env created_at ASC). Returns null
  /// when `currentSid` is the last env in the group — in that case the
  /// survey screen shows _FinishedView and triggers group analyze.
  String? _nextEnvSessionIdAfter(String currentSid) {
    final idx = _envSessions.indexWhere((e) => e.sessionId == currentSid);
    if (idx < 0 || idx + 1 >= _envSessions.length) return null;
    return _envSessions[idx + 1].sessionId;
  }

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
      // Step 41: callbacks only fire from widgets we render inside the
      // body, which itself only mounts once _activeSessionId is set —
      // so the bang is always safe here.
      final sid = _activeSessionId;
      if (sid == null) return;
      // Block auto-advance when evidence is required and condition is met
      // but no file has been uploaded yet.
      final s = ref.read(_ansProvider(sid));
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
    final sid = _activeSessionId;
    if (sid == null) return;
    final s = ref.read(_ansProvider(sid));
    final q = s.currentQuestion;
    final _qt = q?['qType'] as String?;
    if (q != null && (_qt == 'text' || _qt == 'numeric')) {
      ref.read(_ansProvider(sid).notifier)
          .setAnswerText(q['id'] as String, _textCtrl.text);
    }
    await ref.read(_ansProvider(sid).notifier).submitAndAdvance();
    _keyFocus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
    final sid = _activeSessionId;
    if (sid == null) return KeyEventResult.ignored;
    final s = ref.read(_ansProvider(sid));
    if (s.saving || s.finished || s.currentQuestion == null) {
      return KeyEventResult.ignored;
    }
    final qType = s.currentQuestion!['qType'] as String;
    final qId   = s.currentQuestion!['id'] as String;
    final notif = ref.read(_ansProvider(sid).notifier);

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      if (qType != 'text') {
        _advance();
        return KeyEventResult.handled;
      }
    }
    // Step 36: skip Y/N shortcut for per-env yes_no questions — the user
    // has N rows to answer; a single keypress doesn't pick which row.
    final isPerEnv =
        s.currentQuestion!['isDataEnvironmentQuestion'] as bool? ?? false;
    if (qType == 'yes_no' && !isPerEnv) {
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
    // Step 41: group-mode guards — show loading / error until the active
    // session id is resolved. Legacy (sessionId-only) mode skips these
    // branches because _activeSessionId is non-null from the constructor.
    if (_groupLoading) {
      return Scaffold(
        backgroundColor: _kBg,
        body: Column(children: [
          _TopBar(
            workflowName: widget.workflowName,
            onBack: () => context.pop(),
          ),
          const Expanded(child: _LoadingView()),
        ]),
      );
    }
    if (_groupError != null) {
      return Scaffold(
        backgroundColor: _kBg,
        body: Column(children: [
          _TopBar(
            workflowName: widget.workflowName,
            onBack: () => context.pop(),
          ),
          Expanded(child: _ErrorView(message: _groupError!, onRetry: _loadGroup)),
        ]),
      );
    }
    final sid = _activeSessionId;
    if (sid == null) {
      // Defensive — shouldn't reach here (constructor asserts at least one
      // of sessionId / groupId is provided; group load above resolves
      // _currentSessionId or sets _groupError).
      return const Scaffold(body: _LoadingView());
    }

    final s = ref.watch(_ansProvider(sid));
    _syncTextCtrl(s);

    // Step 41 — auto-advance to next env when the current env-session
    // finishes, unless this is the last env in the group (in which case
    // _FinishedView renders below and triggers group analyze).
    if (s.finished && _isGroupMode) {
      final nextSid = _nextEnvSessionIdAfter(sid);
      if (nextSid != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _switchEnv(nextSid);
        });
        return Scaffold(
          backgroundColor: _kBg,
          body: Column(children: [
            _TopBar(
              workflowName: widget.workflowName,
              onBack: () => context.pop(),
            ),
            if (_envSessions.isNotEmpty)
              _EnvChipStrip(
                envSessions: _envSessions,
                activeSessionId: sid,
                onSelect: _switchEnv,
              ),
            const Expanded(child: _LoadingView()),
          ]),
        );
      }
      // Last env — fall through to the normal _FinishedView path below
      // (it'll trigger group-level analyze via _FinishedView.groupId).
    }

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

            // ── Step 41: env-switcher chip strip ──────────────
            if (_isGroupMode && _envSessions.isNotEmpty)
              _EnvChipStrip(
                envSessions: _envSessions,
                activeSessionId: sid,
                onSelect: _switchEnv,
              ),

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
                              .read(_ansProvider(sid).notifier)
                              ._load(),
                        )
                      : s.finished
                          ? _FinishedView(
                              sessionId: sid,
                              // Step 41 — when in group mode, _FinishedView
                              // triggers analyze on the whole group rather
                              // than just this env-session.
                              groupId: widget.groupId,
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
                                  sessionId:  sid,
                                  ref:        ref,
                                  onTextChanged: (v) => ref
                                      .read(_ansProvider(sid).notifier)
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
                  // Step 36: per-env needs ALL envs answered, not just any.
                  final isPerEnv =
                      q['isDataEnvironmentQuestion'] as bool? ?? false;
                  if (isPerEnv) {
                    final envIds = ((q['environments'] as List?) ?? const [])
                        .map((e) => (e as Map)['id'] as String);
                    return localAns.allEnvsAnswered(envIds);
                  }
                  final reqsEv  = q['requiresEvidence'] as bool? ?? false;
                  if (!reqsEv) return true;
                  // Evidence only required when the condition matches the answer.
                  final evidCond = q['evidenceCondition'] as String?;
                  if (!_evidenceConditionMet(evidCond, localAns)) return true;
                  // LLM already approved this evidence → allow advance.
                  if (localAns.evidenceDecision?.toUpperCase() == 'APPROVE') return true;
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
                  ref.read(_ansProvider(sid).notifier).goBack();
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
          BoxShadow(color: Color(0x33005A9E), blurRadius: 20, offset: Offset(0, 6)),
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
                  color: Colors.white.withValues(alpha: 0.15),
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
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
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

// ── Step 41: Env-switcher chip strip ──────────────────────────
// Horizontal scrolling row of ChoiceChips, one per env-session in the
// active workflow_answer_group. Selected chip mirrors the currently-
// surveyed env; tapping a non-selected chip calls onSelect(sessionId).
class _EnvChipStrip extends StatelessWidget {
  final List<EnvSessionSummary> envSessions;
  final String activeSessionId;
  final void Function(String sessionId) onSelect;

  const _EnvChipStrip({
    required this.envSessions,
    required this.activeSessionId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kCard,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final env in envSessions) ...[
              ChoiceChip(
                label: Text(
                  // Hardcoded suffix — Phase 11 l10n will swap for
                  // envBadgeLabel(envName) + an answered-count formatter.
                  '${env.envName}  ·  ${env.answeredCount}',
                ),
                selected: env.sessionId == activeSessionId,
                onSelected: (_) => onSelect(env.sessionId),
              ),
              const SizedBox(width: 8),
            ],
          ],
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
                                      color: badgeColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: badgeColor.withValues(alpha: 0.5)),
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
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title tag
                            if (title != null && title.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _kGrad2.withValues(alpha: 0.08),
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
                            // Step 36: per-env yes/no questions get the
                            // N-row card; everything else uses the single
                            // big-button input.
                            if (qType == 'yes_no' &&
                                (q['isDataEnvironmentQuestion'] as bool? ??
                                    false))
                              _PerEnvAnswerCard(
                                environments: (q['environments'] as List?)
                                        ?.cast<Map<String, dynamic>>() ??
                                    const [],
                                answers: localAns.envAnswers,
                                onChanged: (envId, v) {
                                  notifier.setEnvAnswerNumber(qId, envId, v);
                                  // No auto-advance for per-env: user has
                                  // multiple rows to answer.
                                },
                              )
                            else if (qType == 'yes_no')
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
                      reviewDecision:   localAns.evidenceDecision,
                      reviewSummary:    localAns.evidenceSummary,
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
  final String? reviewDecision;
  final String? reviewSummary;

  const _EvidencePanel({
    required this.sessionId,
    required this.questionId,
    this.answerId,
    required this.promptText,
    required this.pendingFiles,
    required this.alreadyAnswered,
    required this.notifier,
    this.sufficiencyPcntg,
    this.reviewDecision,
    this.reviewSummary,
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
    _sufficiency    = widget.sufficiencyPcntg;
    _reviewDecision = widget.reviewDecision;
    _reviewSummary  = widget.reviewSummary;
  }

  @override
  void didUpdateWidget(_EvidencePanel old) {
    super.didUpdateWidget(old);
    if (old.answerId != widget.answerId) {
      setState(() {
        _filesFetched = false;
        _serverFiles = [];
        _reviewDecision = widget.reviewDecision;
        _reviewSummary  = widget.reviewSummary;
      });
    }
    if (old.sufficiencyPcntg != widget.sufficiencyPcntg) {
      setState(() => _sufficiency = widget.sufficiencyPcntg);
    }
    if (old.reviewDecision != widget.reviewDecision) {
      setState(() => _reviewDecision = widget.reviewDecision);
    }
    if (old.reviewSummary != widget.reviewSummary) {
      setState(() => _reviewSummary = widget.reviewSummary);
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

    final l10n = AppLocalizations.of(context);
    setState(() {
      _uploading = true;
      _analyzing = false;
      _uploadProgress = 0.0;
      _uploadError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final customerId =
          ref.read(customerContextProvider)?['customerId'] as String?;
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: picked.name),
        if (customerId != null) 'customer_id': customerId,
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
      if (mounted) setState(() => _uploadError = l10n.uploadFailedRetry);
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
        final dio      = ref.read(dioProvider);

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
                      : AppLocalizations.of(context).evidenceLabel,
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
                      .withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (_reviewDecision == 'APPROVE'
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFD97706))
                        .withValues(alpha: 0.35),
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
                  AppLocalizations.of(context).uploadingPercent((_uploadProgress * 100).toInt()),
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
                  AppLocalizations.of(context).noEvidenceUploadedYet,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
              )
            else
              ...allFiles.map((entry) => _EvidenceFileEntryRow(
                    entry: entry,
                    dio: dio,
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
                label: Text(AppLocalizations.of(context).addEvidence,
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
                    _reviewingEvidence ? AppLocalizations.of(context).reviewingLabel : AppLocalizations.of(context).reviewEvidence,
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

class _EvidenceFileEntryRow extends StatefulWidget {
  final _FileEntry entry;
  final Dio dio;
  final void Function(_ServerFile) onRemoveServer;
  final void Function(_PendingFile) onRemovePending;
  final void Function(_FileEntry entry) onView;

  const _EvidenceFileEntryRow({
    required this.entry,
    required this.dio,
    required this.onRemoveServer,
    required this.onRemovePending,
    required this.onView,
  });

  @override
  State<_EvidenceFileEntryRow> createState() => _EvidenceFileEntryRowState();
}

class _EvidenceFileEntryRowState extends State<_EvidenceFileEntryRow> {
  bool _downloading = false;

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      await platformDownload(
        url: '/files/${widget.entry.fileId}/download',
        fileName: widget.entry.name,
        dio: widget.dio,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${AppLocalizations.of(context).downloadFailed}: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final l10n = AppLocalizations.of(context);
    final dateStr = entry.date != null
        ? entry.date!.substring(0, 10).split('-').reversed.join('/')
        : null;
    final isImage = entry.isImage;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // ── File type icon ────────────────────────────────────
          Icon(
            isImage ? Icons.image_outlined : Icons.description_outlined,
            size: 16,
            color: isImage ? AppColors.info : AppColors.blue,
          ),
          const Gap(8),
          // ── Name + date ───────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (dateStr != null)
                  Text(dateStr,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          const Gap(4),
          // ── View button (only when content is available) ──────
          if (entry.hasContent)
            _EvidenceBtn(
              icon: Icons.visibility_outlined,
              tooltip: l10n.view,
              color: AppColors.blue,
              onTap: () => widget.onView(entry),
            ),
          // ── Download button (server files only) ───────────────
          if (entry.server != null)
            _downloading
                ? const Padding(
                    padding: EdgeInsets.all(5),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.success),
                    ),
                  )
                : _EvidenceBtn(
                    icon: Icons.download_outlined,
                    tooltip: l10n.downloadFile,
                    color: AppColors.success,
                    onTap: _download,
                  ),
          // ── Delete button ─────────────────────────────────────
          _EvidenceBtn(
            icon: Icons.delete_outline,
            tooltip: l10n.remove,
            color: AppColors.danger,
            onTap: () {
              if (entry.server != null) widget.onRemoveServer(entry.server!);
              else if (entry.pending != null) widget.onRemovePending(entry.pending!);
            },
          ),
        ],
      ),
    );
  }
}

// ── Small icon button with tooltip (mirrors task_edit_dialog._EvidenceIconBtn)
class _EvidenceBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _EvidenceBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      );
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
                    ? const Color(0xFF0EA5E9).withValues(alpha: 0.08)
                    : AppColors.blue.withValues(alpha: 0.08),
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
                      entry.name.isNotEmpty ? entry.name : AppLocalizations.of(context).evidenceLabel,
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
        child: Text(AppLocalizations.of(context).noContentAvailable,
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                    child: Text(
                      AppLocalizations.of(context).contentsLabel.toUpperCase(),
                      style: const TextStyle(
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
                                  ? const Color(0xFF1A237E).withValues(alpha: 0.08)
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
            border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
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
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFD97706)),
          const Gap(8),
          Expanded(
            child: Text(
              AppLocalizations.of(context).evidenceMayBeRequired,
              style: const TextStyle(
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

// ── Step 36: Per-environment answer card ──────────────────────
// Renders one Yes/No control PER customer_data_environment. The question
// text is still shown above (by the parent card); this widget renders
// only the input rows.
class _PerEnvAnswerCard extends StatelessWidget {
  /// List of `{id, envName}` from the question payload (Phase 6 returns
  /// these on every question with `isDataEnvironmentQuestion: true`).
  final List<Map<String, dynamic>> environments;

  /// Map env_id → answerNumber (0 or 1). Envs not in the map are unanswered.
  final Map<String, int> answers;

  /// Called when the user picks Yes (1) or No (0) for one env.
  final void Function(String envId, int answerNumber) onChanged;

  const _PerEnvAnswerCard({
    required this.environments,
    required this.answers,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (environments.isEmpty) {
      // Defensive: the server should always send ≥1 env for a per-env
      // question (every customer gets a default env). If we somehow get
      // an empty list, surface a quiet hint instead of a silent empty card.
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warningLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          l10n.noResults,
          style: const TextStyle(fontSize: 13, color: AppColors.warning),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < environments.length; i++) ...[
          if (i > 0) const Gap(10),
          _PerEnvRow(
            envName: environments[i]['envName'] as String? ?? '',
            value: answers[environments[i]['id'] as String],
            onChanged: (v) => onChanged(environments[i]['id'] as String, v),
          ),
        ],
      ],
    );
  }
}

class _PerEnvRow extends StatelessWidget {
  final String envName;
  final int? value;   // 1 = Yes, 0 = No, null = unanswered
  final void Function(int) onChanged;

  const _PerEnvRow({
    required this.envName,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_outlined,
              size: 16, color: AppColors.muted),
          const Gap(8),
          Expanded(
            child: Text(
              envName,
              style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: _kText,
              ),
            ),
          ),
          _PerEnvPickBtn(
            label: l10n.yes,
            icon: Icons.check_rounded,
            color: _kDone,
            selected: value == 1,
            onTap: () => onChanged(1),
          ),
          const Gap(8),
          _PerEnvPickBtn(
            label: l10n.no,
            icon: Icons.close_rounded,
            color: AppColors.danger,
            selected: value == 0,
            onTap: () => onChanged(0),
          ),
        ],
      ),
    );
  }
}

class _PerEnvPickBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PerEnvPickBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14, color: selected ? Colors.white : color),
            const Gap(4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
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
                    ? widget.activeColor.withValues(alpha: 0.06)
                    : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel
                  ? widget.activeColor
                  : _hovered
                      ? widget.activeColor.withValues(alpha: 0.4)
                      : const Color(0xFFE2E8F0),
              width: sel ? 2 : 1.5,
            ),
            boxShadow: sel
                ? [BoxShadow(color: widget.activeColor.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
                : null,
          ),
          child: Column(
            children: [
              Icon(widget.icon,
                  color: sel ? Colors.white : widget.activeColor.withValues(alpha: 0.7),
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
                ? _kGrad2.withValues(alpha: 0.08)
                : _hovered
                    ? _kGrad2.withValues(alpha: 0.04)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? _kGrad2 : _hovered ? _kGrad2.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
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
        hintText: AppLocalizations.of(context).typeAnswerHint,
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
              color: _kMuted.withValues(alpha: 0.5),
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
            Icon(Icons.info_outline_rounded, size: 13, color: _kMuted.withValues(alpha: 0.7)),
            const Gap(4),
            Text(
              AppLocalizations.of(context).enterANumber,
              style: TextStyle(fontSize: 12, color: _kMuted.withValues(alpha: 0.7)),
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
            color: Colors.black.withValues(alpha: 0.04),
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
                  child: Text(
                      error == 'pleaseAnswerBeforeContinuing'
                          ? AppLocalizations.of(context).pleaseAnswerBeforeContinuing
                          : error == 'evidenceRequiredBeforeContinuing'
                              ? AppLocalizations.of(context).evidenceRequiredBeforeContinuing
                              : error!,
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
                    onPressed: saving || !canAdvance ? null : () => onNext(),
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
  /// Step 41 — when non-null, this view triggers analysis against the
  /// whole workflow_answer_group rather than just the active env-session.
  /// Used by the polling URL and the analyze trigger.
  final String? groupId;
  final String workflowName;
  final int totalAnswered;
  final int totalQuestions;
  final Map<String, String> quizResults;

  const _FinishedView({
    required this.sessionId,
    this.groupId,
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
  bool _analysisPending = false; // true = LLM running in background, response already received

  Timer? _pollTimer;     // polls /analyze-status while _analysisPending is true
  int   _pollCount = 0;  // counts polls; stops after _kMaxPolls

  // 5 s × 72 polls = 6 minutes maximum wait before giving up.
  static const _kPollInterval = Duration(seconds: 5);
  static const _kMaxPolls     = 72;

  // Step 41 — URL routers. In group mode, hit /workflow-answer-groups
  // endpoints (which fan out per env-session and tag tasks with env name).
  // /reanalyze in group mode supersedes prior non-approved tasks per env
  // BEFORE re-emitting, so re-triggering on subsequent finishes is safe.
  bool get _isGroupMode => widget.groupId != null;
  String get _statusUrl => _isGroupMode
      ? '/workflow-answer-groups/${widget.groupId}/analyze-status'
      : '/workflow-answers/${widget.sessionId}/analyze-status';
  String get _analyzeUrl => _isGroupMode
      ? '/workflow-answer-groups/${widget.groupId}/reanalyze'
      : '/workflow-answers/${widget.sessionId}/analyze';

  @override
  void initState() {
    super.initState();
    // Defer to post-frame so inherited widgets (AppLocalizations) are available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _runAnalysis();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Start polling GET /analyze-status every 5 seconds until analysis completes
  /// or the 6-minute timeout is reached.
  void _startPolling() {
    _pollTimer?.cancel();
    _pollCount = 0;
    _pollTimer = Timer.periodic(_kPollInterval, (_) async {
      _pollCount++;
      if (!mounted) {
        _pollTimer?.cancel();
        return;
      }
      // Timeout: give up after _kMaxPolls attempts (~6 minutes)
      if (_pollCount >= _kMaxPolls) {
        _pollTimer?.cancel();
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          setState(() {
            _analysisPending = false;
            _analyzeError    = l10n.analysisTimedOut;
          });
        }
        return;
      }
      try {
        final dio = ref.read(dioProvider);
        final res = await dio.get<Map<String, dynamic>>(_statusUrl);
        final pending = res.data?['pending'] as bool? ?? true;
        if (!pending && mounted) {
          _pollTimer?.cancel();
          final failed  = res.data?['failed']  as bool? ?? false;
          final created = res.data?['tasksCreated'] as int? ?? 0;
          if (failed) {
            final l10n = AppLocalizations.of(context);
            setState(() {
              _analysisPending = false;
              _analyzeError    = l10n.analysisTimedOut;
            });
          } else {
            setState(() {
              _analysisPending = false;
              _tasksCreated    = created;
            });
            _unlockNav();
          }
        }
      } catch (_) {
        // Silently ignore transient poll errors — keep polling.
      }
    });
  }

  /// Called as soon as analysis is confirmed complete (evaluation row exists).
  /// Unlocks the nav menu so the client_admin sees the sidebar buttons
  /// immediately — without waiting for them to click "Go to Dashboard".
  void _unlockNav() {
    ref.read(clientHasEvaluatedWorkflowsProvider.notifier).state = true;
    final cid =
        ref.read(customerContextProvider)?['customerId'] as String?;
    if (cid != null) ref.invalidate(clientNavEnabledProvider(cid));
  }

  Future<void> _runAnalysis() async {
    final dio = ref.read(dioProvider);

    // The analyze endpoint returns immediately (background task).
    final origConnect = dio.options.connectTimeout;
    final origReceive = dio.options.receiveTimeout;
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout  = const Duration(seconds: 15);

    try {
      final res = await dio.post<Map<String, dynamic>>(_analyzeUrl);
      final created  = res.data?['tasksCreated']   as int?  ?? 0;
      final pending  = res.data?['analysisPending'] as bool? ?? false;
      if (mounted) {
        setState(() {
          _analyzing       = false;
          _analysisPending = pending;
          _tasksCreated    = pending ? null : created;
        });
        if (!pending) _unlockNav();
        if (pending) _startPolling();
      }
    } catch (e) {
      String msg;
      if (e is DioException) {
        final data = e.response?.data;
        final detail = data is Map ? data['detail']?.toString() : null;
        if (detail != null) {
          msg = detail;
        } else if (e.type == DioExceptionType.connectionTimeout ||
                   e.type == DioExceptionType.receiveTimeout ||
                   e.type == DioExceptionType.sendTimeout) {
          msg = mounted
              ? AppLocalizations.of(context).analysisTimedOut
              : 'Analysis timed out';
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
      dio.options.connectTimeout = origConnect;
      dio.options.receiveTimeout  = origReceive;
    }
  }

  /// Confirm + re-run analysis, then send the user to the Kanban board to
  /// review the refreshed task list.
  Future<void> _handleReanalyze() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.analyzeAgainTitle),
        content: Text(l10n.analyzeAgainConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.analyzeAgain),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final created = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReanalyzeDialog(sessionId: widget.sessionId),
    );
    if (created != null && mounted) {
      _unlockNav();
      context.go(AppRoutes.tasks);
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
    return SingleChildScrollView(
      child: Center(
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
                    label: AppLocalizations.of(context).answeredLabel,
                    value: '${widget.totalAnswered} / ${widget.totalQuestions}',
                    color: _kDone,
                  ),
                  const Gap(12),
                  _StatBadge(
                    icon: Icons.percent_rounded,
                    label: AppLocalizations.of(context).completionLabel,
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
                        : _analysisPending
                            ? _AnalysisPendingPanel(key: const ValueKey('pending'))
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
                onPressed: () {
                  // Instant unlock via the StateProvider (shell fallback).
                  ref
                      .read(clientHasEvaluatedWorkflowsProvider.notifier)
                      .state = true;
                  // Also invalidate the cached FutureProvider so the shell
                  // re-fetches the authoritative server result.
                  final ctx = ref.read(customerContextProvider);
                  final cid = ctx?['customerId'] as String?;
                  if (cid != null) {
                    ref.invalidate(clientNavEnabledProvider(cid));
                  }
                  context.go(AppRoutes.dashboard);
                },
                icon: const Icon(Icons.dashboard_outlined, size: 18),
                label: Text(AppLocalizations.of(context).goToDashboard,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ).animate().fadeIn(delay: 600.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),

              // ── Re-analyze + Download Gap Report ─────────────────────────
              if (!_analyzing && _analyzeError == null && !_analysisPending) ...[
                const Gap(12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _handleReanalyze,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: Text(AppLocalizations.of(context).analyzeAgain),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF7C3AED),
                      ),
                    ),
                    const Gap(12),
                    OutlinedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        barrierDismissible: false,
                        // Step 41b — in group mode, generate a group-wide
                        // PDF (sums exposure across envs, includes every
                        // env's answers + env-tagged tasks). In legacy
                        // single-session mode, pass the session id.
                        builder: (_) => widget.groupId != null
                            ? GapReportDialog(groupId: widget.groupId)
                            : GapReportDialog(sessionId: widget.sessionId),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                      label: Text(AppLocalizations.of(context).downloadGapReport),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1B3A6B),
                        side: const BorderSide(color: Color(0xFF1B3A6B)),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 700.ms, duration: 400.ms),
              ],
            ],
          ),
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
                Text(
                  AppLocalizations.of(context).aiAnalyzingResponses,
                  style: const TextStyle(
                    color: Color(0xFF5B21B6),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(2),
                Text(
                  AppLocalizations.of(context).identifyingComplianceGaps,
                  style: const TextStyle(
                    color: Color(0xFF7C3AED),
                    fontSize: 11,
                  ),
                ),
                const Gap(4),
                Text(
                  AppLocalizations.of(context).analysisRunsInBackground,
                  style: const TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
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
          color: Colors.white.withValues(alpha: 0.4),
        );
  }
}

// ── Analysis pending panel (background task started) ───────────
class _AnalysisPendingPanel extends StatefulWidget {
  const _AnalysisPendingPanel({super.key});

  @override
  State<_AnalysisPendingPanel> createState() => _AnalysisPendingPanelState();
}

class _AnalysisPendingPanelState extends State<_AnalysisPendingPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;
  bool _hourglassTop = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _hourglassTop = !_hourglassTop);
          _ctrl.reverse();
        } else if (status == AnimationStatus.dismissed) {
          setState(() => _hourglassTop = !_hourglassTop);
          _ctrl.forward();
        }
      });
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        final borderColor = Color.lerp(
          const Color(0xFFBAE6FD),
          const Color(0xFF0284C7),
          t,
        )!;
        final bgColor = Color.lerp(
          const Color(0xFFF0F9FF),
          const Color(0xFFE0F2FE),
          t,
        )!;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withValues(alpha: 0.15 * t),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              _hourglassTop
                  ? Icons.hourglass_top_rounded
                  : Icons.hourglass_bottom_rounded,
              key: ValueKey(_hourglassTop),
              color: const Color(0xFF0284C7),
              size: 26,
            ),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.analysisRunningInBackground,
                  style: const TextStyle(
                    color: Color(0xFF0369A1),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(2),
                Text(
                  l10n.tasksWillAppearInDashboard,
                  style: const TextStyle(
                    color: Color(0xFF0284C7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tasks created panel ────────────────────────────────────────
class _TasksCreatedPanel extends StatelessWidget {
  final int tasksCreated;
  const _TasksCreatedPanel({super.key, required this.tasksCreated});

  @override
  Widget build(BuildContext context) {
    final l10n   = AppLocalizations.of(context);
    final hasTasks = tasksCreated > 0;
    final bg     = hasTasks ? const Color(0xFFFEF3C7) : const Color(0xFFF0FDF4);
    final border = hasTasks ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0);
    final icon   = hasTasks ? Icons.task_alt_rounded  : Icons.check_circle_outline_rounded;
    final iconColor = hasTasks ? const Color(0xFFD97706) : _kDone;
    final label  = hasTasks
        ? l10n.tasksCreatedCount(tasksCreated)
        : l10n.noComplianceGapsFound;
    final sub    = hasTasks
        ? l10n.reviewTasksInBoard
        : l10n.allRequirementsMet;

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
                      color: iconColor.withValues(alpha: 0.75),
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
              '${AppLocalizations.of(context).analysisFailed}: $error',
              style: const TextStyle(
                  color: Color(0xFFDC2626), fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Gap(8),
          TextButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context).retry,
                style: const TextStyle(
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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
          AppLocalizations.of(context).noQuestionsFound(workflowName),
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
        color: _color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.35)),
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

