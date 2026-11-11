$ErrorActionPreference = "Stop"
$vault = "D:\资料\新建文件夹\ObsidianNote"
$bed = "D:\资料\新建文件夹\pages"
$src = "D:\资料\汇编语言与接口技术"
$out = "D:\资料\新建文件夹\pages\.audit.txt"
$lines = New-Object System.Collections.Generic.List[string]

# 图床现有文件（相对路径集合）
$bedSet = @{}
foreach ($f in (Get-ChildItem -Path $bed -Recurse -File -Include *.jpg,*.jpeg,*.png,*.gif,*.webp,*.svg,*.pdf)) {
    $bedSet[$f.FullName.Substring($bed.Length + 1) -replace '\\', '/'] = $true
}

$lines.Add("=== 全 vault 笔记图片链接审计 ===")
$lines.Add("图床现有文件总数: $($bedSet.Count)")
$lines.Add("")
$lines.Add("--- 外链(URL)引用检查 ---")
$bad = 0; $okUrl = 0; $relLinks = 0
foreach ($md in (Get-ChildItem -Path $vault -Recurse -Filter *.md)) {
    if ($md.FullName -match '[\\/]\.obsidian[\\/]') { continue }
    $rel = $md.FullName.Substring($vault.Length + 1)
    $course = ($rel -split '[\\/]')[0]
    $text = [System.IO.File]::ReadAllText($md.FullName, [System.Text.Encoding]::UTF8)
    foreach ($m in [regex]::Matches($text, '\]\((https://hxy123666\.github\.io/ObsidianNote-pages/[^)\s]+)\)')) {
        $u = [System.Uri]::UnescapeDataString($m.Groups[1].Value)
        $p = $u.Substring("https://hxy123666.github.io/ObsidianNote-pages/".Length)
        if ($bedSet.ContainsKey($p)) { $okUrl++ }
        else { $bad++; $lines.Add("[图床缺失] $rel -> $p") }
    }
    foreach ($m in [regex]::Matches($text, '\]\((assets/[^)\s]+)\)')) {
        $relLinks++
        $lines.Add("[还是相对链接] $rel -> $($m.Groups[1].Value)")
    }
}
$lines.Add("外链检查: 正常 $okUrl 个, 图床缺失 $bad 个; 未改写的相对链接 $relLinks 个")
$lines.Add("")
$lines.Add("=== 源文件夹图片清单 ($src) ===")
if (Test-Path $src) {
    $srcImgs = Get-ChildItem -Path $src -Recurse -File -Include *.jpg,*.jpeg,*.png,*.gif,*.webp
    $lines.Add("源图片总数: $($srcImgs.Count)")
    foreach ($f in $srcImgs) { $lines.Add("  $($f.FullName.Substring($src.Length + 1))  ($([math]::Round($f.Length/1KB))KB)") }
} else {
    $lines.Add("源文件夹不存在!")
}
$lines.Add("")
$lines.Add("=== D:\资料 下的课程文件夹 ===")
Get-ChildItem "D:\资料" -Directory | ForEach-Object { $lines.Add("  $($_.Name)") }
[System.IO.File]::WriteAllLines($out, $lines, (New-Object System.Text.UTF8Encoding($false)))
"审计完成: 外链正常 $okUrl / 缺失 $bad / 相对 $relLinks"
