import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/board_models.dart';
import '../services/auth_service.dart';
import '../services/user_record_service.dart';
import '../validation.dart';
import 'entry_form.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.auth,
    required this.records,
    required this.board,
  });
  final AuthService auth;
  final UserRecordService records;
  final Widget Function(BoardProfile, User) board;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _registerPage = false;
  bool _registering = false;
  BoardProfile? _createdProfile;
  ProfileDetails? _details;
  String? _registeredUid;

  Future<void> _register(
    String email,
    String password,
    ProfileDetails details,
  ) async {
    setState(() => _registering = true);
    try {
      final result = await widget.auth.register(email, password);
      final uid = result.user!.uid;
      _registeredUid = uid;
      _details = details;
      try {
        _createdProfile = await widget.records.saveUserRecord(uid, details);
      } catch (_) {
        // The account already exists. ProfileGate handles a retry using the same UID.
      }
      _registerPage = false;
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: widget.auth.authState,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Scaffold(
          body: Center(
            child: Text(
              'Could not check your sign-in status. Restart Common Room.',
            ),
          ),
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Checking your session',
            ),
          ),
        );
      }
      final user = snapshot.data;
      if (user != null && !_registering) {
        return _ProfileGate(
          key: ValueKey(user.uid),
          user: user,
          records: widget.records,
          signOut: widget.auth.signOut,
          initialProfile: user.uid == _registeredUid ? _createdProfile : null,
          initialDetails: user.uid == _registeredUid ? _details : null,
          board: (profile) => widget.board(profile, user),
        );
      }
      return EntryForm(
        key: ValueKey(_registerPage),
        mode: _registerPage ? EntryMode.register : EntryMode.login,
        onSubmit: _registerPage
            ? _register
            : (email, password, _) async {
                await widget.auth.signIn(email, password);
              },
        onAlternate: () => setState(() => _registerPage = !_registerPage),
      );
    },
  );
}

class _ProfileGate extends StatefulWidget {
  const _ProfileGate({
    super.key,
    required this.user,
    required this.records,
    required this.board,
    required this.signOut,
    this.initialProfile,
    this.initialDetails,
  });
  final User user;
  final UserRecordService records;
  final Widget Function(BoardProfile) board;
  final Future<void> Function() signOut;
  final BoardProfile? initialProfile;
  final ProfileDetails? initialDetails;

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late Future<BoardProfile?> _record = _load();

  Future<BoardProfile?> _load() => widget.records.load(widget.user.uid);

  Future<void> _signOut() async {
    try {
      await widget.signOut();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyError(error, 'Could not sign out. Please retry.'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialProfile;
    if (initial != null) return widget.board(initial);
    return FutureBuilder<BoardProfile?>(
      future: _record,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading profile',
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              minimum: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      friendlyError(
                        snapshot.error!,
                        'Could not load your profile.',
                      ),
                    ),
                    FilledButton(
                      onPressed: () => setState(() {
                        _record = _load();
                      }),
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: _signOut,
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final profile = snapshot.data;
        if (profile != null) return widget.board(profile);
        return EntryForm(
          mode: EntryMode.profile,
          initialDetails: widget.initialDetails,
          onSubmit: (_, _, details) async {
            final profile = await widget.records.saveUserRecord(
              widget.user.uid,
              details,
            );
            if (mounted) {
              setState(() {
                _record = Future.value(profile);
              });
            }
          },
          onAlternate: _signOut,
        );
      },
    );
  }
}
