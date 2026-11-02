with open('lib/core/widgets/ux_states/nova_session_expired_state.dart', 'r', encoding='utf-8') as f:
    text = f.read()

target = '''class NovaSessionExpiredState extends StatelessWidget {
  final String? preservedDraftSummary;
  final VoidCallback onSignIn;
  final VoidCallback? onSwitchAccount;

  const NovaSessionExpiredState({
    super.key,
    this.preservedDraftSummary,
    required this.onSignIn,
    this.onSwitchAccount,
  });'''

replacement = '''class NovaSessionExpiredState extends StatelessWidget {
  final bool hasUnsavedDraft;
  final String? preservedDraftSummary;
  final String? unsavedDraftDescription;
  final VoidCallback? onSignIn;
  final VoidCallback? onSignInResume;
  final VoidCallback? onSwitchAccount;

  const NovaSessionExpiredState({
    super.key,
    this.hasUnsavedDraft = true,
    this.preservedDraftSummary,
    this.unsavedDraftDescription,
    this.onSignIn,
    this.onSignInResume,
    this.onSwitchAccount,
  });'''

text = text.replace(target, replacement)

# Replace message
target_msg = "'Your security session has timed out. For your protection and compliance with financial audit logs, please authenticate again to continue.'"
repl_msg = "'Your login credentials expired. For your protection and compliance with financial audit logs, please authenticate again to continue.'"
text = text.replace(target_msg, repl_msg)

# Replace draft text
target_draft = """                      Text(
                        preservedDraftSummary ??
                            'Your current shipment inputs and delivery notes are cached locally and will be restored immediately after sign-in.',"""
repl_draft = """                      Text(
                        (unsavedDraftDescription != null)
                            ? 'Unsaved Draft Preserved: $unsavedDraftDescription'
                            : (preservedDraftSummary ?? 'Your current shipment inputs and delivery notes are cached locally and will be restored immediately after sign-in.'),"""
text = text.replace(target_draft, repl_draft)

# Replace onSignIn
target_signin = "                onPressed: onSignIn,"
repl_signin = "                onPressed: onSignInResume ?? onSignIn,"
text = text.replace(target_signin, repl_signin)

with open('lib/core/widgets/ux_states/nova_session_expired_state.dart', 'w', encoding='utf-8') as f:
    f.write(text)
print('Updated nova_session_expired_state.dart!')

