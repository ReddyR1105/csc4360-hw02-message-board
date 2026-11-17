import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_board/main.dart';
import 'package:message_board/models/board_models.dart';
import 'package:message_board/screens/board_screen.dart';
import 'package:message_board/screens/entry_form.dart';
import 'package:message_board/screens/splash_screen.dart';
import 'package:message_board/services/board_service.dart';
import 'package:message_board/validation.dart';

void main() {
  test(
    'F01 validators normalize email and reject invalid field boundaries',
    () {
      expect(emailError(' broken '), isNotNull);
      expect(emailError(' member@example.test '), isNull);
      expect(nameError(' '), isNotNull);
      expect(nameError('A\nB'), isNotNull);
      expect(passwordError('1234567', registering: true), isNotNull);
      expect(passwordError('12345678', registering: true), isNull);
      expect(passwordError('short', registering: false), isNull);
      expect(messageError('   \n'), isNotNull);
      expect(messageError('a' * 500), isNull);
      expect(messageError('a' * 501), isNotNull);
    },
  );

  test('F02 locally persisted post preserves ID and original payload', () {
    const original = PendingPost('abcdefghijklmnopqrst', 'A quote: "hello"');
    final restored = PendingPost.decode(original.encode());
    expect(restored.id, original.id);
    expect(restored.text, original.text);
  });

  testWidgets(
    'F03 splash stores initialization future, retries, and transitions',
    (tester) async {
      final first = Completer<Widget>();
      final retry = Completer<Widget>();
      var attempts = 0;
      final splash = SplashScreen(
        initialize: () => ++attempts == 1 ? first.future : retry.future,
      );
      await tester.pumpWidget(MaterialApp(theme: boardTheme(), home: splash));
      expect(find.text('Connecting to the message board…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(attempts, 1);
      first.completeError(StateError('test initialization failure'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(attempts, 2);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      retry.complete(const Scaffold(body: Text('Auth gate ready')));
      await tester.pumpAndSettle();
      expect(find.text('Auth gate ready'), findsOneWidget);
    },
  );

  testWidgets(
    'F04 invalid registration blocks submission and reports field errors',
    (tester) async {
      var sends = 0;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(480, 1050);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: boardTheme(),
          home: EntryForm(
            mode: EntryMode.register,
            onSubmit: (_, _, _) async => sends++,
          ),
        ),
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Maya');
      await tester.enterText(fields.at(1), 'Chen');
      await tester.enterText(fields.at(2), 'invalid');
      await tester.enterText(fields.at(3), '123');
      await tester.enterText(fields.at(4), '456');
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(find.text('Enter the same password.'), findsOneWidget);
      expect(sends, 0);
    },
  );

  testWidgets(
    'F05 repeated login tap sends once and credentials errors are readable',
    (tester) async {
      final response = Completer<void>();
      var sends = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: boardTheme(),
          home: EntryForm(
            mode: EntryMode.login,
            onSubmit: (email, secret, ProfileDetails _) {
              expect(email, 'member@example.test');
              expect(secret, 'example-pass');
              sends++;
              return response.future;
            },
          ),
        ),
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, ' member@example.test ');
      await tester.enterText(fields.last, 'example-pass');
      await tester.tap(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(sends, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      response.completeError(
        FirebaseException(plugin: 'auth', code: 'invalid-credential'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Check your email and password and try again.'),
        findsOneWidget,
      );
      expect(find.text('Sign in'), findsOneWidget);
    },
  );
  testWidgets('F06 stream error recovers and board subscriptions dispose', (
    tester,
  ) async {
    var listening = 0;
    var cancelled = 0;
    StreamController<List<BoardMessage>> controller() => StreamController(
      onListen: () => listening++,
      onCancel: () {
        cancelled++;
      },
    );
    final first = controller();
    final retry = controller();
    final service = _BoardStreamStub([first.stream, retry.stream]);
    await tester.pumpWidget(
      MaterialApp(
        theme: boardTheme(),
        home: BoardScreen(
          service: service,
          signOut: () async {},
          isDemo: false,
        ),
      ),
    );
    expect(listening, 1);
    first.addError(FirebaseException(plugin: 'firestore', code: 'unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Board unavailable'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(listening, 2);
    expect(cancelled, 1);
    retry.add([]);
    await tester.pumpAndSettle();
    expect(find.text('No messages yet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(cancelled, 2);
    unawaited(first.close());
    unawaited(retry.close());
  });
}

class _BoardStreamStub implements BoardService {
  _BoardStreamStub(this.streams);
  final List<Stream<List<BoardMessage>>> streams;
  var calls = 0;

  @override
  final profile = const BoardProfile('sample-uid', 'Sample', 'Member');

  @override
  Future<PendingPost?> loadPending() async => null;

  @override
  Stream<List<BoardMessage>> messageBoard() => streams[calls++];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
