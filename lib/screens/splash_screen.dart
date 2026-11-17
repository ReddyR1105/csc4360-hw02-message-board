import 'package:flutter/material.dart';

import 'entry_form.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.initialize});
  final Future<Widget> Function() initialize;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late Future<Widget> _startup;

  @override
  void initState() {
    super.initState();
    _startup = widget.initialize();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
    future: _startup,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          snapshot.hasData) {
        return snapshot.data!;
      }
      final failed =
          snapshot.connectionState == ConnectionState.done && snapshot.hasError;
      final theme = Theme.of(context);
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(large: true),
                  const SizedBox(height: 22),
                  Text(
                    'Common Room',
                    style: theme.textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    failed
                        ? 'Could not start the board. Check your connection and Firebase setup.'
                        : 'Connecting to the message board…',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (failed)
                    FilledButton(
                      onPressed: () => setState(() {
                        _startup = widget.initialize();
                      }),
                      child: const Text('Retry'),
                    )
                  else
                    const CircularProgressIndicator(
                      semanticsLabel: 'Connecting',
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
