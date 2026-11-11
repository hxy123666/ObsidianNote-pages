$ErrorActionPreference = "Stop"
$vault = "D:\资料\新建文件夹\ObsidianNote"
$bed = "D:\资料\新建文件夹\pages"
$out = "D:\资料\新建文件夹\pages\.search.txt"
$lines = New-Object System.Collections.Generic.List[string]

# 1. 提取笔记里引用的图片文件名
$names = @()
foreach ($md in @("test1.md","test2.md")) {
    $f = Join-Path $vault "汇编语言与接口技术\$md"
    if (-not (Test-Path -LiteralPath $f)) { continue }
    $text = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8)
    foreach ($m in [regex]::Matches($text, 'https://hxy123666\.github\.io/ObsidianNote-pages/[^)\s]+')) {
        $u = $m.Value
        $n = [System.Uri]::UnescapeDataString($u.Substring($u.LastIndexOf('/') + 1))
        if ($names -notcontains $n) { $names += $n }
    }
}
$lines.Add("笔记引用的图片文件数: $($names.Count)")
foreach ($n in $names) { $lines.Add("  文件名: $n") }

# 2. 本地图床搜索
$localFiles = Get-ChildItem -Path $bed -Recurse -File -Include *.jpg,*.png,*.gif,*.webp
$lines.Add("")
$lines.Add("=== 本地图床搜索 ===")
foreach ($n in $names) {
    $hit = @($localFiles | Where-Object { $_.Name -eq $n })
    if ($hit.Count) { $lines.Add("[本地有] $($hit[0].FullName.Substring($bed.Length+1))") }
    else { $lines.Add("[本地无] $n") }
}

# 3. 远端搜索（按文件名）
$cred = "protocol=https`nhost=github.com`n" | git credential fill
$token = ($cred -split "`n" | Where-Object { $_ -like "password=*" }) -replace "password=", ""
$headers = @{ Authorization = "Bearer $token"; Accept = "application/vnd.github+json"; "User-Agent" = "setup-script" }
$t = Invoke-RestMethod -Uri "https://api.github.com/repos/hxy123666/ObsidianNote-pages/git/trees/main?recursive=1" -Headers $headers
$lines.Add("")
$lines.Add("=== 远端仓库搜索 ===")
foreach ($n in $names) {
    $hit = @($t.tree | Where-Object { $_.path -match "/$([regex]::Escape($n))$" })
    if ($hit.Count) { $lines.Add("[远端有] $($hit[0].path)") }
    else { $lines.Add("[远端无] $n") }
}
$lines.Add("")
$lines.Add("=== 远端顶层目录 ===")
foreach ($e in @($t.tree | Where-Object { $_.type -eq "tree" -and $_.path -notmatch "/" })) { $lines.Add("  $($e.path)") }
[System.IO.File]::WriteAllLines($out, $lines, (New-Object System.Text.UTF8Encoding($false)))
"完成"
