#!/usr/bin/env zsh

set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
config_file="${project_dir}/config/supabase.local.json"

if [[ ! -f "${config_file}" ]]; then
  print "Missing config/supabase.local.json."
  print "Run: cp config/supabase.local.json.example config/supabase.local.json"
  exit 1
fi

cd "${project_dir}"
flutter run --dart-define-from-file="${config_file}" "$@"
