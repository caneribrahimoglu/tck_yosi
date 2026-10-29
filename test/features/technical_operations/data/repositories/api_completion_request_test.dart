import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tck_yosi/features/technical_operations/domain/errors/technical_work_completion_exception.dart';
import 'package:tck_yosi/features/technical_operations/domain/errors/technical_work_detail_read_exception.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/submit_technical_work_completion_request.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_completion_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_completion_status.dart';
import 'api_technical_work_repository_test.dart' show repository, jsonResponse;
import 'api_technical_work_execution_test.dart' show actor, started, Names;

Map<String, Object?> requestJson() => {
  'id': 'request-id',
  'work_id': 'work-uuid',
  'requested_by_user_id': actor,
  'summary': 'Done',
  'requested_at': '2026-10-29T12:00:00Z',
  'decision': 'pending',
  'reviewed_by_user_id': null,
  'reviewed_at': null,
  'rejection_reason': null,
};

void main() {
  test(
    'request payload, revision and immutable authenticated history',
    () async {
      final keys = <String>[];
      final repo = await repository((r) async {
        if (r.method == 'POST') {
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          expect(body.keys.toSet(), {
            'summary',
            'expected_revision',
            'submission_id',
          });
          expect(body['summary'], 'Done');
          keys.add(body['submission_id'] as String);
          return jsonResponse({
            'work': started(status: 'awaitingCompletionApproval', revision: 3),
            'request': requestJson(),
          }, 201);
        }
        if (r.url.path.endsWith('/completion-requests')) {
          return jsonResponse([requestJson()]);
        }
        return jsonResponse(started());
      });
      expect(repo.supportsCompletionRequests, isTrue);
      expect(repo.supportsCompletion, isTrue);
      await repo.getWorkById(workId: 'work-uuid', actorUserId: actor);
      final request = SubmitTechnicalWorkCompletionRequest(
        workId: 'work-uuid',
        summary: 'Done',
      );
      final first = await repo.submitCompletionRequest(
        request: request,
        actorUserId: actor,
      );
      await repo.submitCompletionRequest(request: request, actorUserId: actor);
      expect(keys.toSet().length, 1);
      expect(first.requestedAt.toUtc(), DateTime.utc(2026, 10, 29, 12));
      final history = await repo.getCompletionRequests(
        workId: 'work-uuid',
        actorUserId: actor,
      );
      expect(history.single.id, first.id);
      expect(() => history.clear(), throwsUnsupportedError);
    },
  );

  test(
    'typed request denial and secure history deny raw existing/missing detail',
    () async {
      final repo = await repository((r) async {
        if (r.url.path.endsWith('/work-uuid')) return jsonResponse(started());
        return jsonResponse({
          'detail': {
            'code': r.method == 'POST'
                ? 'technical_work_completion_not_allowed'
                : 'technical_work_read_not_allowed',
          },
        }, 403);
      });
      await repo.getWorkById(workId: 'work-uuid', actorUserId: actor);
      await expectLater(
        repo.submitCompletionRequest(
          request: SubmitTechnicalWorkCompletionRequest(
            workId: 'work-uuid',
            summary: 'Done',
          ),
          actorUserId: actor,
        ),
        throwsA(isA<TechnicalWorkCompletionNotAllowedException>()),
      );
      for (final id in ['work-uuid', 'missing']) {
        await expectLater(
          repo.getCompletionRequests(workId: id, actorUserId: actor),
          throwsA(isA<TechnicalWorkDetailReadNotAllowedException>()),
        );
      }
    },
  );

  test(
    'controller double submit is blocked, lost response retry keeps key, one history entry',
    () async {
      final gate = Completer<http.Response>();
      final keys = <String>[];
      final repo = await repository((r) async {
        if (r.method == 'POST') {
          keys.add(jsonDecode(r.body)['submission_id'] as String);
          return keys.length == 1
              ? gate.future
              : jsonResponse({
                  'work': started(
                    status: 'awaitingCompletionApproval',
                    revision: 3,
                  ),
                  'request': requestJson(),
                }, 201);
        }
        if (r.url.path.endsWith('/pending')) return jsonResponse([]);
        if (r.url.path.endsWith('/completion-requests')) {
          return jsonResponse([]);
        }
        if (r.url.path.endsWith('/capabilities')) {
          return jsonResponse({'can_request_completion': true});
        }
        return jsonResponse(started());
      });
      final controller = TechnicalWorkCompletionController(
        repository: repo,
        participantNameSource: const Names(),
      );
      addTearDown(controller.dispose);
      await repo.getWorkById(workId: 'work-uuid', actorUserId: actor);
      await controller.loadForWork(workId: 'work-uuid', userId: actor);
      expect(controller.canRequestCompletion, isTrue);
      final first = controller.submit('Done');
      await Future<void>.delayed(Duration.zero);
      expect(controller.isSubmittingRequest, isTrue);
      expect(await controller.submit('Done'), isFalse);
      expect(keys.length, 1);
      gate.complete(
        jsonResponse({
          'detail': {'code': 'unknown'},
        }, 500),
      );
      expect(await first, isFalse);
      expect(controller.detailStatus, TechnicalWorkCompletionStatus.failure);
      expect(await controller.submit('Done'), isTrue);
      expect(keys.toSet().length, 1);
      expect(controller.history.single.id, 'request-id');
      expect(controller.userName(actor), 'İş Yürüten');
      expect(controller.canRequestCompletion, isFalse);
      expect(controller.detailStatus, TechnicalWorkCompletionStatus.success);
      expect(controller.supportsReview, isTrue);
      await controller.loadPending(actor);
      expect(controller.queueStatus, TechnicalWorkCompletionStatus.loaded);
    },
  );

  test(
    'late submission after logout cannot restore previous history or names',
    () async {
      final gate = Completer<http.Response>();
      final repo = await repository((r) async {
        if (r.method == 'POST') return gate.future;
        if (r.url.path.endsWith('/completion-requests')) {
          return jsonResponse([]);
        }
        if (r.url.path.endsWith('/capabilities')) {
          return jsonResponse({'can_request_completion': true});
        }
        return jsonResponse(started());
      });
      final controller = TechnicalWorkCompletionController(
        repository: repo,
        participantNameSource: const Names(),
      );
      addTearDown(controller.dispose);
      await repo.getWorkById(workId: 'work-uuid', actorUserId: actor);
      await controller.loadForWork(workId: 'work-uuid', userId: actor);
      final submission = controller.submit('Done');
      await Future<void>.delayed(Duration.zero);
      controller.resetSession();
      gate.complete(
        jsonResponse({
          'work': started(status: 'awaitingCompletionApproval', revision: 3),
          'request': requestJson(),
        }, 201),
      );
      expect(await submission, isFalse);
      expect(controller.history, isEmpty);
      expect(controller.userName(actor), isNull);
      expect(controller.detailStatus, TechnicalWorkCompletionStatus.initial);
      expect(controller.isSubmittingRequest, isFalse);
    },
  );

  test(
    'parallel history/capability failures are safely caught and no empty-success state is exposed',
    () async {
      final repo = await repository(
        (r) async => jsonResponse({
          'detail': {'code': 'technical_work_read_not_allowed'},
        }, 403),
      );
      final controller = TechnicalWorkCompletionController(
        repository: repo,
        participantNameSource: const Names(),
      );
      addTearDown(controller.dispose);
      await controller.loadForWork(workId: 'work-uuid', userId: actor);
      expect(controller.detailStatus, TechnicalWorkCompletionStatus.failure);
      expect(controller.history, isEmpty);
      expect(controller.canRequestCompletion, isFalse);
      expect(controller.errorMessage, 'Tamamlama geçmişi yüklenemedi.');
    },
  );
}
