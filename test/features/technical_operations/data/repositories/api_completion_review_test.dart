import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tck_yosi/features/technical_operations/domain/errors/technical_work_completion_exception.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_completion_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_completion_status.dart';
import 'api_technical_work_repository_test.dart' show repository, jsonResponse;
import 'api_technical_work_execution_test.dart' show actor, started, Names;
import 'api_completion_request_test.dart' show requestJson;

Map<String, Object?> reviewItem() => {
  'work': started(status: 'awaitingCompletionApproval', revision: 3),
  'request': requestJson(),
};
Map<String, Object?> decided({bool reject = false}) => {
  'work': {
    ...started(status: reject ? 'inProgress' : 'completed', revision: 4),
    'completed_at': reject ? null : '2026-10-29T13:00:00Z',
  },
  'request': {
    ...requestJson(),
    'decision': reject ? 'rejected' : 'approved',
    'reviewed_by_user_id': actor,
    'reviewed_at': '2026-10-29T13:00:00Z',
    'rejection_reason': reject ? 'Duzelt' : null,
  },
};

void main() {
  test(
    'older in-flight queue load cannot resurrect a confirmed decision',
    () async {
      final stale = Completer<http.Response>();
      var reads = 0;
      final repo = await repository((r) async {
        if (r.method == 'POST') return jsonResponse(decided());
        reads++;
        if (reads == 2) return stale.future;
        return jsonResponse(reads == 1 ? [reviewItem()] : []);
      });
      final controller = TechnicalWorkCompletionController(
        repository: repo,
        participantNameSource: const Names(),
      );
      addTearDown(controller.dispose);
      await controller.loadPending(actor);
      final lateLoad = controller.loadPending(actor);
      await Future<void>.delayed(Duration.zero);
      expect(await controller.approve('request-id'), isTrue);
      stale.complete(jsonResponse([reviewItem()]));
      await lateLoad;
      expect(controller.pendingCount, 0);
      expect(controller.queueStatus, TechnicalWorkCompletionStatus.success);
    },
  );
  for (final reject in [false, true]) {
    test(
      'API pending immutable and secure ${reject ? 'reject' : 'approve'} response mapping',
      () async {
        final repo = await repository((r) async {
          if (r.method == 'POST') {
            expect(r.url.path, endsWith(reject ? '/reject' : '/approve'));
            expect(jsonDecode(r.body), reject ? {'reason': 'Duzelt'} : {});
            return jsonResponse(decided(reject: reject));
          }
          return jsonResponse([reviewItem()]);
        });
        final queue = await repo.getPendingCompletionReviews(
          actorUserId: actor,
        );
        expect(queue.single.work.assignedToTeamId, 'real-team');
        expect(() => queue.clear(), throwsUnsupportedError);
        final result = reject
            ? await repo.rejectCompletionRequest(
                requestId: 'request-id',
                actorUserId: actor,
                rejectionReason: 'Duzelt',
              )
            : await repo.approveCompletionRequest(
                requestId: 'request-id',
                actorUserId: actor,
              );
        expect(result.reviewedByUserId, actor);
        expect(result.reviewedAt?.toUtc(), DateTime.utc(2026, 10, 29, 13));
        expect(result.rejectionReason, reject ? 'Duzelt' : null);
      },
    );
  }

  test('review authorization and decided failures are typed', () async {
    var code = 'not_allowed';
    final repo = await repository(
      (r) async => jsonResponse({
        'detail': {'code': code},
      }, code == 'not_allowed' ? 403 : 409),
    );
    await expectLater(
      repo.getPendingCompletionReviews(actorUserId: actor),
      throwsA(isA<TechnicalWorkCompletionReviewNotAllowedException>()),
    );
    await expectLater(
      repo.approveCompletionRequest(
        requestId: 'request-id',
        actorUserId: actor,
      ),
      throwsA(isA<TechnicalWorkCompletionReviewNotAllowedException>()),
    );
    code = 'technical_work_completion_already_decided';
    await expectLater(
      repo.approveCompletionRequest(
        requestId: 'request-id',
        actorUserId: actor,
      ),
      throwsA(isA<TechnicalWorkCompletionAlreadyDecidedException>()),
    );
  });

  test(
    'controller prevents duplicate decision; confirmed result survives queue refresh failure',
    () async {
      final gate = Completer<http.Response>();
      var reads = 0;
      var writes = 0;
      final repo = await repository((r) async {
        if (r.method == 'POST') {
          writes++;
          return gate.future;
        }
        reads++;
        return reads == 1
            ? jsonResponse([reviewItem()])
            : jsonResponse({
                'detail': {'code': 'unknown'},
              }, 500);
      });
      final controller = TechnicalWorkCompletionController(
        repository: repo,
        participantNameSource: const Names(),
      );
      addTearDown(controller.dispose);
      await controller.loadPending(actor);
      expect(controller.pendingCount, 1);
      final first = controller.approve('request-id');
      await Future<void>.delayed(Duration.zero);
      expect(controller.isReviewingAny, isTrue);
      expect(
        await controller.reject(requestId: 'request-id', reason: 'Other'),
        isFalse,
      );
      expect(writes, 1);
      gate.complete(jsonResponse(decided()));
      expect(await first, isTrue);
      expect(controller.pendingCount, 0);
      expect(controller.queueStatus, TechnicalWorkCompletionStatus.success);
      expect(controller.isReviewingAny, isFalse);
    },
  );

  test(
    'already-decided controller refreshes stale queue with safe message',
    () async {
      var reads = 0;
      final repo = await repository((r) async {
        if (r.method == 'POST') {
          return jsonResponse({
            'detail': {'code': 'technical_work_completion_already_decided'},
          }, 409);
        }
        return jsonResponse(++reads == 1 ? [reviewItem()] : []);
      });
      final controller = TechnicalWorkCompletionController(
        repository: repo,
        participantNameSource: const Names(),
      );
      addTearDown(controller.dispose);
      await controller.loadPending(actor);
      expect(await controller.approve('request-id'), isFalse);
      expect(controller.pendingCount, 0);
      expect(controller.errorMessage, contains('daha önce karara'));
    },
  );

  test('logout discards late queue and late decision responses', () async {
    final loadGate = Completer<http.Response>();
    final decisionGate = Completer<http.Response>();
    var delayed = true;
    final repo = await repository((r) async {
      if (r.method == 'POST') return decisionGate.future;
      return delayed ? loadGate.future : jsonResponse([reviewItem()]);
    });
    final controller = TechnicalWorkCompletionController(
      repository: repo,
      participantNameSource: const Names(),
    );
    addTearDown(controller.dispose);
    final first = controller.loadPending(actor);
    await Future<void>.delayed(Duration.zero);
    controller.resetSession();
    loadGate.complete(jsonResponse([reviewItem()]));
    await first;
    expect(controller.pendingCount, 0);
    expect(controller.queueStatus, TechnicalWorkCompletionStatus.initial);
    delayed = false;
    await controller.loadPending(actor);
    final review = controller.approve('request-id');
    await Future<void>.delayed(Duration.zero);
    controller.resetSession();
    decisionGate.complete(jsonResponse(decided()));
    expect(await review, isFalse);
    expect(controller.queueStatus, TechnicalWorkCompletionStatus.initial);
    expect(controller.pendingReviews, isEmpty);
  });
}
