$input_json = $input | ConvertFrom-Json
$cmd = $input_json.tool_input.command
if ($cmd -notmatch '^git commit') { exit 0 }
$branch = git -C 'c:\tmp\karthik-fitness' rev-parse --abbrev-ref HEAD 2>$null
if ($branch -eq 'master' -or $branch -eq 'main') {
    @{
        decision = 'block'
        reason   = "Direct commits to '$branch' are blocked. Create a feature branch: git checkout -b feature/build-N-description"
    } | ConvertTo-Json -Compress
    exit 0
}
exit 0
