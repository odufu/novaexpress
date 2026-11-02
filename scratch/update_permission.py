with open('lib/core/widgets/ux_states/nova_permission_denied_state.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if 'if (onRequestPermission != null)' in line:
        new_lines.append('                  final effectiveReq = onGrantPermission ?? onRequestPermission;\n')
        new_lines.append('                  if (effectiveReq != null)\n')
    elif 'onPressed: onRequestPermission,' in line:
        new_lines.append('                      onPressed: effectiveReq,\n')
    elif "'Open Settings'" in line:
        new_lines.append(line.replace("'Open Settings'", "'Open App Settings'"))
    else:
        new_lines.append(line)

with open('lib/core/widgets/ux_states/nova_permission_denied_state.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print('Permission denied lines updated successfully!')

