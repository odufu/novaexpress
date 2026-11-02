path = 'lib/features/dc_console/presentation/pages/dc_finance_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

target = """          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  if (tooltip != null) ...[
                    const SizedBox(width: 4),
                    NovaInfoIcon(tooltip: tooltip, size: 13),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),"""

replacement = """          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    if (tooltip != null) ...[
                      const SizedBox(width: 4),
                      NovaInfoIcon(tooltip: tooltip, size: 13),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),"""

# Normalize line endings for replacement
text_normalized = text.replace('\r\n', '\n')
target_normalized = target.replace('\r\n', '\n')
replacement_normalized = replacement.replace('\r\n', '\n')

if target_normalized in text_normalized:
    text_normalized = text_normalized.replace(target_normalized, replacement_normalized)
    with open(path, 'w', encoding='utf-8', newline='\r\n') as f:
        f.write(text_normalized)
    print("SUCCESS: replaced successfully")
else:
    print("ERROR: target not found")

