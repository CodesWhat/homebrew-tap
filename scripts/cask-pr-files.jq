# Turns a GitHub compare API response into the line format that
# cask-pr-eligible.sh reads. Used as `jq -r -f scripts/cask-pr-files.jq`.
#
# Output is one line per changed file, and every line is built from values
# checked here, on the JSON side, before anything is serialized:
#   "<added|modified> Casks/<name>.rb"   only when status is added or modified
#                                        and the filename matches the pattern
#   "reject <reason>"                    for anything else
# The pattern is anchored with \A and \z. Oniguruma's ^ and $ match at line
# breaks, so they would accept "Casks/x.rb\n<anything>". The pattern excludes
# every character that could break a line or a record, so an emitted filename
# can never contain a newline, tab or space. Reject reasons embed filenames
# only through @json, which escapes newlines, so they stay on one line too.
#
# The compare API returns at most 300 files and gives no flag saying it cut the
# list, so 300 or more is treated as truncated and rejected. A missing or
# non-array .files is rejected as well.
def cask_re: "\\ACasks/[a-z0-9-]+\\.rb\\z";

if (.files | type) != "array" then
  "reject the compare response has no file list"
elif (.files | length) >= 300 then
  "reject the compare response lists 300 or more files and may be truncated"
elif (.files | length) == 0 then
  empty
else
  .files[]
  | if (.filename | type) != "string" or (.status | type) != "string" then
      "reject a file entry has no usable name or status"
    elif (.status != "added" and .status != "modified") then
      "reject \(.filename | @json) has status \(.status | @json)"
    elif (.filename | test(cask_re)) then
      "\(.status) \(.filename)"
    else
      "reject \(.filename | @json) is not a top-level Casks/<name>.rb file"
    end
end
