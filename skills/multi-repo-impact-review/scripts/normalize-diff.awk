#!/usr/bin/awk -f

# Normalize a unified diff into a small JSON change manifest. The caller passes:
#   -v source=git|patch -v base=... -v head=... -v diff_file=...
#   -v list_file=/absolute/path/to/changed-files.txt

function json_escape(value,    result) {
  result = value
  gsub(/\\/, "\\\\", result)
  gsub(/\"/, "\\\"", result)
  gsub(/\r/, "", result)
  gsub(/\t/, "\\t", result)
  return result
}

function clean_path(value) {
  sub(/\r$/, "", value)
  sub(/\t.*$/, "", value)
  if (value ~ /^\".*\"$/) {
    sub(/^\"/, "", value)
    sub(/\"$/, "", value)
  }
  if (value ~ /^[ab]\//) value = substr(value, 3)
  return value
}

function begin_file() {
  current = ++file_count
  old_path[current] = ""
  new_path[current] = ""
  status[current] = "modified"
  hunk_count[current] = 0
}

function parse_range(spec, starts, counts, file_index, hunk_index,    parts) {
  split(spec, parts, ",")
  starts[file_index, hunk_index] = parts[1] + 0
  counts[file_index, hunk_index] = (parts[2] == "" ? 1 : parts[2] + 0)
}

BEGIN {
  file_count = 0
  current = 0
  if (list_file != "") printf "" > list_file
}

/^diff --git / {
  begin_file()
  next
}

/^--- / {
  if (current == 0 || new_path[current] != "") begin_file()
  old_path[current] = clean_path(substr($0, 5))
  next
}

/^\+\+\+ / {
  if (current == 0) begin_file()
  new_path[current] = clean_path(substr($0, 5))
  next
}

/^new file mode / {
  if (current == 0) begin_file()
  status[current] = "added"
  next
}

/^deleted file mode / {
  if (current == 0) begin_file()
  status[current] = "deleted"
  next
}

/^rename from / {
  if (current == 0) begin_file()
  old_path[current] = clean_path(substr($0, 13))
  status[current] = "renamed"
  next
}

/^rename to / {
  if (current == 0) begin_file()
  new_path[current] = clean_path(substr($0, 11))
  status[current] = "renamed"
  next
}

/^@@ -/ {
  if (current == 0) begin_file()
  header = $0
  sub(/^@@ -/, "", header)
  split(header, fields, " ")
  old_spec = fields[1]
  new_spec = fields[2]
  sub(/^\+/, "", new_spec)
  hunk = ++hunk_count[current]
  parse_range(old_spec, old_start, old_count, current, hunk)
  parse_range(new_spec, new_start, new_count, current, hunk)
  section = $0
  sub(/^@@ [^@]*@@[ ]?/, "", section)
  hunk_section[current, hunk] = section
  next
}

END {
  printf "{\n"
  printf "  \"schemaVersion\": 1,\n"
  printf "  \"source\": \"%s\",\n", json_escape(source)
  printf "  \"base\": \"%s\",\n", json_escape(base)
  printf "  \"head\": \"%s\",\n", json_escape(head)
  printf "  \"diffFile\": \"%s\",\n", json_escape(diff_file)
  printf "  \"files\": ["
  emitted = 0
  for (i = 1; i <= file_count; i++) {
    old_value = old_path[i]
    new_value = new_path[i]
    if (old_value == "/dev/null") status[i] = "added"
    if (new_value == "/dev/null") status[i] = "deleted"
    if (status[i] == "modified" && old_value != "" && new_value != "" && old_value != new_value) status[i] = "renamed"
    path_value = (new_value != "" && new_value != "/dev/null") ? new_value : old_value
    if (path_value == "" || path_value == "/dev/null") continue

    if (emitted > 0) printf ","
    printf "\n    {\"status\":\"%s\",\"oldPath\":\"%s\",\"path\":\"%s\",\"hunks\":[", \
      json_escape(status[i]), json_escape(old_value), json_escape(path_value)
    for (j = 1; j <= hunk_count[i]; j++) {
      if (j > 1) printf ","
      printf "{\"oldStart\":%d,\"oldCount\":%d,\"newStart\":%d,\"newCount\":%d,\"section\":\"%s\"}", \
        old_start[i, j], old_count[i, j], new_start[i, j], new_count[i, j], json_escape(hunk_section[i, j])
    }
    printf "]}"
    if (list_file != "") print path_value >> list_file
    emitted++
  }
  if (emitted > 0) printf "\n  "
  printf "]\n}\n"
}
