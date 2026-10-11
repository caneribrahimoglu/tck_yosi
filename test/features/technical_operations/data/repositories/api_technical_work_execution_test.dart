import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_status.dart';
import 'package:tck_yosi/features/technical_operations/domain/errors/technical_work_start_exception.dart';
import 'package:tck_yosi/features/technical_operations/domain/errors/technical_work_progress_exception.dart';
import 'package:tck_yosi/features/technical_operations/domain/errors/technical_work_hold_exception.dart';
import 'package:tck_yosi/features/technical_operations/domain/errors/technical_work_detail_read_exception.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/add_technical_work_progress_request.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/put_technical_work_on_hold_request.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work_participant_names.dart';
import 'package:tck_yosi/features/technical_operations/domain/repositories/technical_work_participant_name_source.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_detail_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_hold_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_hold_status.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_progress_submission_status.dart';
import 'api_technical_work_repository_test.dart'
    show repository, workJson, jsonResponse;

const actor = 'real-chief-uuid';
Map<String, Object?> started({
  String status = 'inProgress',
  int revision = 2,
}) => {
  ...workJson(team: 'real-team', revision: revision),
  'status': status,
  'started_by_user_id': actor,
  'started_at': '2026-10-11T12:00:00Z',
};
Map<String, Object?> note() => {
  'id': 'note-id',
  'work_id': 'work-uuid',
  'author_user_id': actor,
  'content': 'Kalıcı not',
  'created_at': '2026-10-11T12:10:00Z',
};
Map<String, Object?> hold({bool resumed = false}) => {
  'id': 'hold-id',
  'work_id': 'work-uuid',
  'held_by_user_id': actor,
  'held_at': '2026-10-11T12:15:00Z',
  'reason': 'Parça bekleniyor',
  'resumed_by_user_id': resumed ? actor : null,
  'resumed_at': resumed ? '2026-10-11T12:20:00Z' : null,
};

void main() {
  test(
    'start uses captured revision, preserves team and reads server starter/time',
    () async {
      final repo = await repository((r) async {
        if (r.method == 'POST') {
          expect(r.url.path, endsWith('/start'));
          expect(jsonDecode(r.body), {'expected_revision': 1});
          return jsonResponse(started());
        }
        return jsonResponse(workJson(team: 'real-team', revision: 1));
      });
      await repo.getWorkById(workId: 'work-uuid', actorUserId: actor);
      final work = await repo.startWork(
        workId: 'work-uuid',
        actorUserId: actor,
      );
      expect(work.status, TechnicalWorkStatus.inProgress);
      expect(work.assignedToTeamId, 'real-team');
      expect(work.assignedToUserId, isNull);
      expect(work.startedByUserId, actor);
      expect(
        work.copyWith().startedAt?.toUtc(),
        DateTime.utc(2026, 10, 11, 12),
      );
      expect(work.revision, 2);
    },
  );

  test(
    'server already-started maps to typed exception; forged actor sends no write',
    () async {
      var writes = 0;
      final repo = await repository((r) async {
        if (r.method == 'POST') {
          writes++;
          return jsonResponse({
            'detail': {'code': 'technical_work_already_started'},
          }, 409);
        }
        return jsonResponse(started());
      });
      await repo.getWorkById(workId: 'work-uuid', actorUserId: actor);
      await expectLater(
        repo.startWork(workId: 'work-uuid', actorUserId: actor),
        throwsA(isA<TechnicalWorkAlreadyStartedException>()),
      );
      await expectLater(
        repo.startWork(workId: 'work-uuid', actorUserId: 'forged'),
        throwsA(isA<TechnicalWorkStartNotAllowedException>()),
      );
      expect(writes, 1);
    },
  );

  test(
    'progress retry keeps submission UUID; returned history is immutable',
    () async {
      final keys = <String>[];
      final repo = await repository((r) async {
        if (r.method == 'POST') {
          final data = jsonDecode(r.body) as Map<String, dynamic>;
          expect(data.keys.toSet(), {'content', 'submission_id'});
          keys.add(data['submission_id'] as String);
          return jsonResponse(note(), 201);
        }
        return jsonResponse([note()]);
      });
      final request = AddTechnicalWorkProgressRequest(
        workId: 'work-uuid',
        content: 'Kalıcı not',
      );
      final first = await repo.addProgressNote(
        request: request,
        actorUserId: actor,
      );
      final second = await repo.addProgressNote(
        request: request,
        actorUserId: actor,
      );
      expect(first.id, second.id);
      expect(keys.toSet().length, 1);
      final notes = await repo.getProgressNotes(
        workId: 'work-uuid',
        actorUserId: actor,
      );
      expect(
        notes.single.createdAt.toUtc(),
        DateTime.utc(2026, 10, 11, 12, 10),
      );
      expect(() => notes.clear(), throwsUnsupportedError);
    },
  );

  test(
    'hold/resume revision advances and immutable cycle metadata remains',
    () async {
      final repo = await repository((r) async {
        if (r.url.path.endsWith('/hold')) {
          expect(jsonDecode(r.body), {
            'expected_revision': 2,
            'reason': 'Parça bekleniyor',
          });
          return jsonResponse({
            'work': started(status: 'onHold', revision: 3),
            'record': hold(),
          });
        }
        if (r.url.path.endsWith('/resume')) {
          expect(jsonDecode(r.body), {'expected_revision': 3});
          return jsonResponse({
            'work': started(revision: 4),
            'record': hold(resumed: true),
          });
        }
        if (r.url.path.endsWith('/holds')) {
          return jsonResponse([hold(resumed: true)]);
        }
        return jsonResponse(started());
      });
      await repo.getWorkById(workId: 'work-uuid', actorUserId: actor);
      final held = await repo.putWorkOnHold(
        request: PutTechnicalWorkOnHoldRequest(
          workId: 'work-uuid',
          reason: 'Parça bekleniyor',
        ),
        actorUserId: actor,
      );
      final resumed = await repo.resumeWork(
        workId: 'work-uuid',
        actorUserId: actor,
      );
      expect(resumed.id, held.id);
      expect(resumed.heldAt, held.heldAt);
      expect(held.isResumed, isFalse);
      expect(resumed.isResumed, isTrue);
      final history = await repo.getHoldHistory(
        workId: 'work-uuid',
        actorUserId: actor,
      );
      expect(() => history.clear(), throwsUnsupportedError);
    },
  );

  test(
    'unauthorized history returns same typed denial for existing and missing work',
    () async {
      final repo = await repository(
        (r) async => jsonResponse({
          'detail': {'code': 'technical_work_read_not_allowed'},
        }, 403),
      );
      for (final id in ['work-uuid', 'missing']) {
        await expectLater(
          repo.getProgressNotes(workId: id, actorUserId: actor),
          throwsA(isA<TechnicalWorkDetailReadNotAllowedException>()),
        );
        await expectLater(
          repo.getHoldHistory(workId: id, actorUserId: actor),
          throwsA(isA<TechnicalWorkDetailReadNotAllowedException>()),
        );
      }
    },
  );

  test(
    'progress state and hold conflict remain typed, not raw server text',
    () async {
      final repo = await repository((r) async {
        if (r.method != 'POST') return jsonResponse(started());
        return jsonResponse({
          'detail': {
            'code': r.url.path.endsWith('/progress')
                ? 'technical_work_progress_invalid_state'
                : 'technical_work_hold_transition_conflict',
          },
        }, 409);
      });
      await repo.getWorkById(workId: 'work-uuid', actorUserId: actor);
      await expectLater(
        repo.addProgressNote(
          request: AddTechnicalWorkProgressRequest(
            workId: 'work-uuid',
            content: 'N',
          ),
          actorUserId: actor,
        ),
        throwsA(isA<TechnicalWorkProgressInvalidStateException>()),
      );
      await expectLater(
        repo.resumeWork(workId: 'work-uuid', actorUserId: actor),
        throwsA(isA<TechnicalWorkHoldTransitionInFlightException>()),
      );
    },
  );

  test(
    'progress controller retry after lost response uses same key, one local note',
    () async {
      final keys = <String>[];
      final gate = Completer<http.Response>();
      final repo = await repository((r) async {
        if (r.method == 'POST') {
          keys.add(jsonDecode(r.body)['submission_id'] as String);
          return keys.length == 1 ? gate.future : jsonResponse(note(), 201);
        }
        if (r.url.path.endsWith('/progress')) return jsonResponse([]);
        if (r.url.path.endsWith('/capabilities')) {
          return jsonResponse({'can_add_progress': true});
        }
        return jsonResponse(started());
      });
      final controller = TechnicalWorkDetailController(
        repository: repo,
        participantNameSource: const Names(),
      );
      addTearDown(controller.dispose);
      await controller.load(workId: 'work-uuid', userId: actor);
      final first = controller.addProgress('Kalıcı not');
      await Future<void>.delayed(Duration.zero);
      expect(controller.isSubmitting, isTrue);
      expect(await controller.addProgress('Kalıcı not'), isFalse);
      expect(keys.length, 1);
      gate.complete(
        jsonResponse({
          'detail': {'code': 'unknown'},
        }, 500),
      );
      expect(await first, isFalse);
      expect(
        controller.submissionStatus,
        TechnicalWorkProgressSubmissionStatus.failure,
      );
      expect(await controller.addProgress('Kalıcı not'), isTrue);
      expect(keys.toSet().length, 1);
      expect(controller.notes.single.id, 'note-id');
      expect(controller.authorName(controller.notes.single), 'İş Yürüten');
    },
  );

  test(
    'progress response after logout cannot repopulate previous session',
    () async {
      final gate = Completer<http.Response>();
      final repo = await repository((r) async {
        if (r.method == 'POST') return gate.future;
        if (r.url.path.endsWith('/progress')) return jsonResponse([]);
        if (r.url.path.endsWith('/capabilities')) {
          return jsonResponse({'can_add_progress': true});
        }
        return jsonResponse(started());
      });
      final controller = TechnicalWorkDetailController(
        repository: repo,
        participantNameSource: const Names(),
      );
      addTearDown(controller.dispose);
      await controller.load(workId: 'work-uuid', userId: actor);
      final submission = controller.addProgress('Kalıcı not');
      await Future<void>.delayed(Duration.zero);
      controller.resetSession();
      gate.complete(jsonResponse(note(), 201));
      expect(await submission, isFalse);
      expect(controller.work, isNull);
      expect(controller.notes, isEmpty);
      expect(controller.errorMessage, isNull);
    },
  );

  test(
    'parallel hold reads failures are caught; logout clears late transition',
    () async {
      var failReads = true;
      final gate = Completer<http.Response>();
      final repo = await repository((r) async {
        if (r.method == 'POST') return gate.future;
        if (r.url.path.endsWith('/work-uuid')) return jsonResponse(started());
        if (failReads) {
          return jsonResponse({
            'detail': {'code': 'not_allowed'},
          }, 403);
        }
        if (r.url.path.endsWith('/holds')) return jsonResponse([]);
        return jsonResponse({'can_pause': true, 'can_resume': false});
      });
      final controller = TechnicalWorkHoldController(
        repository: repo,
        participantNameSource: const Names(),
      );
      addTearDown(controller.dispose);
      await controller.load(workId: 'work-uuid', userId: actor);
      expect(controller.status, TechnicalWorkHoldStatus.failure);
      failReads = false;
      await repo.getWorkById(workId: 'work-uuid', actorUserId: actor);
      await controller.load(workId: 'work-uuid', userId: actor);
      final submission = controller.putOnHold('Parça bekleniyor');
      await Future<void>.delayed(Duration.zero);
      expect(controller.isSubmitting, isTrue);
      expect(await controller.putOnHold('Tekrar'), isFalse);
      controller.resetSession();
      gate.complete(
        jsonResponse({
          'work': started(status: 'onHold', revision: 3),
          'record': hold(),
        }),
      );
      expect(await submission, isFalse);
      expect(controller.status, TechnicalWorkHoldStatus.initial);
      expect(controller.history, isEmpty);
      expect(controller.canResume, isFalse);
    },
  );
}

class Names implements TechnicalWorkParticipantNameSource {
  const Names();
  @override
  Future<TechnicalWorkParticipantNames> resolveNames({
    required Set<String> userIds,
    required Set<String> teamIds,
  }) async => TechnicalWorkParticipantNames(
    userNames: {actor: 'İş Yürüten'},
    teamNames: {'real-team': 'Gerçek Teknik Ekip'},
  );
}
