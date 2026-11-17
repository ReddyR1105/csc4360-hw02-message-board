import 'package:flutter/material.dart';

import '../models/board_models.dart';
import '../services/board_service.dart';
import '../validation.dart';
import 'entry_form.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({
    super.key,
    required this.service,
    required this.signOut,
    required this.isDemo,
  });
  final BoardService service;
  final Future<void> Function() signOut;
  final bool isDemo;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final _composer = TextEditingController();
  final _form = GlobalKey<FormState>();
  late Stream<List<BoardMessage>> _messages = widget.service.messageBoard();
  PendingPost? _pending;
  bool _loadingDraft = true;
  bool _draftError = false;
  bool _posting = false;
  bool _signingOut = false;
  final _changing = <String>{};

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final post = await widget.service.loadPending();
      if (!mounted) return;
      setState(() {
        _pending = post;
        _composer.text = post?.text ?? '';
        _draftError = false;
      });
    } catch (_) {
      if (mounted) setState(() => _draftError = true);
    } finally {
      if (mounted) setState(() => _loadingDraft = false);
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _post() async {
    if (_posting ||
        _loadingDraft ||
        _draftError ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _posting = true);
    try {
      final post = _pending ?? await widget.service.savePending(_composer.text);
      if (mounted) setState(() => _pending = post);
      await widget.service.postMessage(post);
      if (!mounted) return;
      setState(() => _pending = null);
      _composer.clear();
      _notice('Message posted.');
    } catch (error) {
      _notice(
        friendlyError(error, 'Could not post. Retry to send the same message.'),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _signOut() async {
    if (_signingOut || _posting || _changing.isNotEmpty) return;
    setState(() => _signingOut = true);
    try {
      ScaffoldMessenger.of(context).clearSnackBars();
      await widget.signOut();
    } catch (error) {
      _notice(friendlyError(error, 'Could not sign out.'));
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Future<void> _change(BoardMessage message, {required bool remove}) async {
    if (_changing.contains(message.id) || _signingOut) return;
    if (remove) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete this message?'),
          content: const Text('It will disappear from the board for everyone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete message'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
    }
    final edited = remove
        ? null
        : await showDialog<String>(
            context: context,
            builder: (context) => _EditDialog(initial: message.text),
          );
    if (!mounted || (!remove && (edited == null || edited == message.text))) {
      return;
    }
    setState(() => _changing.add(message.id));
    try {
      if (remove) {
        await widget.service.deleteMessage(message.id);
      } else {
        await widget.service.editMessage(message.id, edited!);
      }
      _notice(remove ? 'Message deleted.' : 'Message updated.');
    } catch (error) {
      _notice(friendlyError(error, 'Could not save the change.'));
    } finally {
      if (mounted) setState(() => _changing.remove(message.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = widget.service.profile;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: const Row(
          children: [
            BrandMark(),
            SizedBox(width: 12),
            Flexible(
              child: Text('Common Room', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _posting || _signingOut || _changing.isNotEmpty
                ? null
                : _signOut,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Message board',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${profile.displayName}  ·  Member',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (widget.isDemo)
                        Text(
                          'Local Firebase emulator',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<BoardMessage>>(
                    stream: _messages,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _BoardState(
                          icon: Icons.cloud_off_outlined,
                          title: 'Board unavailable',
                          body: friendlyError(
                            snapshot.error!,
                            'Could not load messages.',
                          ),
                          action: TextButton(
                            onPressed: () => setState(
                              () => _messages = widget.service.messageBoard(),
                            ),
                            child: const Text('Retry'),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            semanticsLabel: 'Loading messages',
                          ),
                        );
                      }
                      final messages = snapshot.data!;
                      if (messages.isEmpty) {
                        return const _BoardState(
                          icon: Icons.chat_bubble_outline,
                          title: 'No messages yet',
                          body: 'Be the first to post.',
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 5, 16, 16),
                        itemCount: messages.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 9),
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return _MessageCard(
                            key: ValueKey(message.id),
                            message: message,
                            owned: message.authorUid == profile.uid,
                            busy: _changing.contains(message.id),
                            edit: () => _change(message, remove: false),
                            remove: () => _change(message, remove: true),
                          );
                        },
                      );
                    },
                  ),
                ),
                Material(
                  color: theme.colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: _draftError
                        ? TextButton(
                            onPressed: _restore,
                            child: const Text(
                              'Could not load your pending message. Retry',
                            ),
                          )
                        : Form(
                            key: _form,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_pending != null && !_posting)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      'A saved message is waiting for confirmation.',
                                    ),
                                  ),
                                TextFormField(
                                  controller: _composer,
                                  readOnly:
                                      _posting ||
                                      _pending != null ||
                                      _loadingDraft,
                                  decoration: const InputDecoration(
                                    labelText: 'New message',
                                  ),
                                  validator: messageError,
                                  maxLength: messageLimit,
                                  minLines: 1,
                                  maxLines: 3,
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.icon(
                                    onPressed:
                                        _posting || _loadingDraft || _signingOut
                                        ? null
                                        : _post,
                                    icon: _posting
                                        ? const SizedBox.square(
                                            dimension: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.send_outlined,
                                            size: 18,
                                          ),
                                    label: Text(
                                      _posting
                                          ? 'Posting…'
                                          : _pending != null
                                          ? 'Retry post'
                                          : 'Post message',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardState extends StatelessWidget {
  const _BoardState({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 38),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            Text(body, textAlign: TextAlign.center),
            ?action,
          ],
        ),
      ),
    );
  }
}

enum _MessageAction { edit, delete }

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    super.key,
    required this.message,
    required this.owned,
    required this.busy,
    required this.edit,
    required this.remove,
  });
  final BoardMessage message;
  final bool owned;
  final bool busy;
  final VoidCallback edit;
  final VoidCallback remove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = MaterialLocalizations.of(context);
    final created = message.createdAt;
    final time = created == null
        ? 'Sending…'
        : '${local.formatShortDate(created)} · ${local.formatTimeOfDay(TimeOfDay.fromDateTime(created))}';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 9, 10, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  foregroundColor: theme.colorScheme.onSecondaryContainer,
                  radius: 17,
                  child: Text(
                    message.authorName.characters.first.toUpperCase(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        owned
                            ? '${message.authorName} · You'
                            : message.authorName,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        message.editedAt == null ? time : '$time · Edited',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (owned)
                  PopupMenuButton<_MessageAction>(
                    enabled: !busy,
                    tooltip: 'Message actions',
                    onSelected: (action) =>
                        action == _MessageAction.edit ? edit() : remove(),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _MessageAction.edit,
                        child: Text('Edit message'),
                      ),
                      PopupMenuItem(
                        value: _MessageAction.delete,
                        child: Text('Delete message'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 7),
            SelectableText(message.text, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.initial});
  final String initial;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final _text = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit message'),
    scrollable: true,
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _text,
        autofocus: true,
        maxLength: messageLimit,
        maxLines: 4,
        validator: messageError,
        decoration: const InputDecoration(labelText: 'Message'),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _text.text.trim());
          }
        },
        child: const Text('Save changes'),
      ),
    ],
  );
}
