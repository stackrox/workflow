#!/usr/bin/env zsh
set -eo pipefail

help_start_line=$(awk '/roxhelp-start/{ print NR; exit }' README.md)
help_end_line=$(awk '/roxhelp-end/{ print NR; exit }' README.md)
roxhelp_text=$(roxhelp --list-all)

echo "\`\`\`bash\n$ roxhelp --list-all\n$roxhelp_text\n\`\`\`"

