with open('lib/core/widgets/ux_states/nova_permission_denied_state.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("final effectiveReq = onGrantPermission ?? onRequestPermission;\n", "")
text = text.replace("final config = _getConfig();", "final config = _getConfig();\n    final effectiveReq = onGrantPermission ?? onRequestPermission;")

with open('lib/core/widgets/ux_states/nova_permission_denied_state.dart', 'w', encoding='utf-8') as f:
    f.write(text)
print('Fixed effectiveReq in nova_permission_denied_state.dart!')

