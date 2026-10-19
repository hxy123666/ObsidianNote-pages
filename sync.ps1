<#
.SYNOPSIS
  ObsidianNote 图床同步脚本（Windows PowerShell 5.1 兼容）

.DESCRIPTION
  把 Obsidian vault 里的图片上传到本图床仓库，并把笔记中的相对链接改写为
  GitHub Pages 绝对网址，然后提交推送图床仓库，最后清理 vault 本地图片。

  步骤：
    1. 上传  ：vault 中的图片  -> 图床仓库（按 课程/assets/章节 原样归档）
    2. 改写  ：笔记里 ](assets/xxx.jpg) -> ](<BaseUrl>/课程/assets/xxx.jpg)
    3. 索引  ：重新生成 index.html 图片画廊
    4. 推送  ：git add / commit / push 图床仓库
    5. 清理  ：删除 vault 中已被外链替换的本地图片

.PARAMETER Vault
  Obsidian vault 目录，默认取图床上级目录下的 ObsidianNote

.PARAMETER Bed
  图床仓库目录，默认为脚本所在目录

.PARAMETER BaseUrl
  图床网址前缀，默认 https://hxy123666.github.io/ObsidianNote-pages

.PARAMETER KeepLocal
  保留 vault 本地图片，只上传和改写链接

.PARAMETER NoPush
  只做本地改动，不提交推送

.EXAMPLE
  .\sync.ps1
.EXAMPLE
  .\sync.ps1 -KeepLocal
.EXAMPLE
  .\sync.ps1 -BaseUrl "https://cdn.jsdelivr.net/gh/hxy123666/ObsidianNote-pages@main"
#>
param(
    [string]$Vault,
    [string]$Bed,
    [string]$BaseUrl = "https://hxy123666.github.io/ObsidianNote-pages",
    [switch]$KeepLocal,
    [switch]$NoPush
)

$ErrorActionPreference = "Stop"
$ImageExt = @(".jpg", ".jpeg", ".png", ".gif", ".webp", ".svg", ".pdf")
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$LinkPattern = '\]\((assets/[^)\s]+)\)'

if (-not $Bed)   { $Bed = $PSScriptRoot }
if (-not $Vault) { $Vault = Join-Path (Split-Path $Bed -Parent) "ObsidianNote" }
$BaseUrl = $BaseUrl.TrimEnd("/")

if (-not (Test-Path -LiteralPath $Vault)) { throw "找不到 vault 目录: $Vault" }
if (-not (Test-Path -LiteralPath $Bed))   { throw "找不到图床目录: $Bed" }

Write-Host "vault    : $Vault"
Write-Host "图床     : $Bed"
Write-Host "网址前缀 : $BaseUrl"
Write-Host ""

# ---------- 收集 vault 中的图片 ----------
$vaultImages = @()
foreach ($f in (Get-ChildItem -Path $Vault -Recurse -File)) {
    if ($f.FullName -match '[\\/]\.obsidian[\\/]') { continue }
    if ($ImageExt -contains $f.Extension.ToLower()) { $vaultImages += $f }
}

# ---------- 1. 上传图片 ----------
$uploaded = 0
$existed = 0
foreach ($img in $vaultImages) {
    $rel = $img.FullName.Substring($Vault.Length + 1)
    $dest = Join-Path $Bed $rel
    if (Test-Path -LiteralPath $dest) { $existed++; continue }
    $dir = Split-Path $dest -Parent
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    Copy-Item -LiteralPath $img.FullName -Destination $dest
    $uploaded++
    Write-Host "  + $rel"
}
Write-Host "[1/5] 图片上传：新增 $uploaded 张，已存在 $existed 张"

# ---------- 2. 改写笔记中的相对链接 ----------
$mdFiles = @()
foreach ($f in (Get-ChildItem -Path $Vault -Recurse -Filter *.md)) {
    if ($f.FullName -match '[\\/]\.obsidian[\\/]') { continue }
    $mdFiles += $f
}
$changedFiles = 0
$changedLinks = 0
foreach ($file in $mdFiles) {
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    $rel = $file.FullName.Substring($Vault.Length + 1)
    $parts = $rel -split '[\\/]'
    $course = ""
    if ($parts.Count -ge 2) { $course = $parts[0] }
    $prefix = "$BaseUrl/"
    if ($course) { $prefix = "$BaseUrl/$course/" }

    $n = ([regex]::Matches($text, $LinkPattern)).Count
    if ($n -eq 0) { continue }
    $newText = [regex]::Replace($text, $LinkPattern, { param($m) "]($prefix$($m.Groups[1].Value))" })
    if ($newText -eq $text) { continue }

    $out = [System.Text.Encoding]::UTF8.GetBytes($newText)
    if ($hasBom) { $out = @([byte]0xEF, [byte]0xBB, [byte]0xBF) + $out }
    [System.IO.File]::WriteAllBytes($file.FullName, $out)
    $changedFiles++
    $changedLinks += $n
    Write-Host "  ~ $rel （$n 处）"
}
Write-Host "[2/5] 链接改写：$changedFiles 个笔记，共 $changedLinks 处"

# ---------- 3. 生成 index.html 画廊 ----------
$bedImages = @()
foreach ($f in (Get-ChildItem -Path $Bed -Recurse -File)) {
    if ($ImageExt -contains $f.Extension.ToLower()) { $bedImages += $f }
}
$bedImages = $bedImages | Sort-Object FullName

$groups = @{}
foreach ($img in $bedImages) {
    $rel = $img.FullName.Substring($Bed.Length + 1)
    $p = $rel -split '[\\/]'
    $course = $p[0]
    $chapter = ""
    if ($p.Count -ge 4) { $chapter = $p[2] }
    elseif ($p.Count -ge 3) { $chapter = $p[1] }
    if (-not $chapter) { $chapter = "其他" }
    $key = "$course|$chapter"
    if (-not $groups.ContainsKey($key)) { $groups[$key] = @() }
    $groups[$key] += $img
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("<!DOCTYPE html>")
[void]$sb.AppendLine('<html lang="zh-CN">')
[void]$sb.AppendLine("<head>")
[void]$sb.AppendLine('<meta charset="utf-8">')
[void]$sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1">')
[void]$sb.AppendLine("<title>ObsidianNote 图床</title>")
[void]$sb.AppendLine("<style>")
[void]$sb.AppendLine(":root{color-scheme:light dark}")
[void]$sb.AppendLine("body{font-family:system-ui,-apple-system,'Segoe UI','Microsoft YaHei',sans-serif;max-width:1080px;margin:0 auto;padding:24px;line-height:1.6}")
[void]$sb.AppendLine("h1{font-size:1.4rem;margin-bottom:.2rem}")
[void]$sb.AppendLine(".meta{color:#888;font-size:.85rem;margin-bottom:1.5rem}")
[void]$sb.AppendLine("h2{font-size:1.1rem;margin:2rem 0 .8rem;padding-bottom:.3rem;border-bottom:1px solid #8884}")
[void]$sb.AppendLine("h3{font-size:.95rem;color:#888;margin:1.2rem 0 .6rem}")
[void]$sb.AppendLine(".grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:14px}")
[void]$sb.AppendLine("figure{margin:0}")
[void]$sb.AppendLine("img{width:100%;height:auto;display:block;border-radius:6px;background:#8881}")
[void]$sb.AppendLine("figcaption{font-size:.72rem;color:#888;word-break:break-all;margin-top:4px}")
[void]$sb.AppendLine("a{color:inherit;text-decoration:none}")
[void]$sb.AppendLine("</style>")
[void]$sb.AppendLine("</head>")
[void]$sb.AppendLine("<body>")
[void]$sb.AppendLine("<h1>ObsidianNote 图床</h1>")
[void]$sb.AppendLine("<p class='meta'>共 $($bedImages.Count) 张图片 &middot; 更新于 $(Get-Date -Format 'yyyy-MM-dd HH:mm') &middot; <a href='https://github.com/hxy123666/ObsidianNote-pages'>仓库地址</a></p>")

$currentCourse = $null
foreach ($key in ($groups.Keys | Sort-Object)) {
    $kv = $key -split '\|'
    $course = $kv[0]
    $chapter = $kv[1]
    if ($course -ne $currentCourse) {
        if ($currentCourse -ne $null) { [void]$sb.AppendLine("</section>") }
        [void]$sb.AppendLine("<h2>$course</h2>")
        [void]$sb.AppendLine("<section>")
        $currentCourse = $course
    }
    [void]$sb.AppendLine("<h3>$chapter</h3>")
    [void]$sb.AppendLine("<div class='grid'>")
    foreach ($img in $groups[$key]) {
        $rel = $img.FullName.Substring($Bed.Length + 1) -replace '\\', '/'
        [void]$sb.AppendLine("<figure><a href='$rel' target='_blank'><img loading='lazy' src='$rel' alt='$($img.Name)'></a><figcaption>$($img.Name)</figcaption></figure>")
    }
    [void]$sb.AppendLine("</div>")
}
if ($currentCourse -ne $null) { [void]$sb.AppendLine("</section>") }
[void]$sb.AppendLine("</body>")
[void]$sb.AppendLine("</html>")

[System.IO.File]::WriteAllText((Join-Path $Bed "index.html"), $sb.ToString(), $Utf8NoBom)
Write-Host "[3/5] index.html 画廊已生成（$($bedImages.Count) 张）"

# ---------- 4. 提交并推送图床仓库 ----------
$pushOk = $true
if ($NoPush) {
    Write-Host "[4/5] -NoPush 已指定，跳过提交推送"
} else {
    git -C $Bed add -A | Out-Null
    $dirty = git -C $Bed status --porcelain
    if (-not $dirty) {
        Write-Host "[4/5] 图床仓库无改动"
    } else {
        $msg = "image sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        git -C $Bed commit -q -m $msg
        git -C $Bed push -q origin main
        if ($LASTEXITCODE -ne 0) {
            $pushOk = $false
            Write-Warning "[4/5] 推送失败（exit=$LASTEXITCODE），请检查网络或 GitHub 登录状态"
        } else {
            Write-Host "[4/5] 已提交并推送：$msg"
        }
    }
    # 保险：本地若有未推送的提交，也不删 vault 图片
    git -C $Bed rev-parse --verify -q origin/main | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $unpushed = git -C $Bed log --format="%h" origin/main..main
        if ($unpushed) {
            $pushOk = $false
            Write-Warning "[4/5] 检测到未推送的提交，暂不删除 vault 本地图片"
        }
    } else {
        $pushOk = $false
        Write-Warning "[4/5] 图床仓库尚未关联 origin/main，暂不删除 vault 本地图片"
    }
}

# ---------- 5. 清理 vault 本地图片 ----------
if ($KeepLocal) {
    Write-Host "[5/5] -KeepLocal 已指定，保留 vault 本地图片"
} elseif (-not $pushOk) {
    Write-Host "[5/5] 推送未成功，保留 vault 本地图片"
} else {
    $deleted = 0
    foreach ($img in $vaultImages) {
        if (Test-Path -LiteralPath $img.FullName) {
            Remove-Item -LiteralPath $img.FullName -Force
            $deleted++
        }
    }
    $dirs = @(Get-ChildItem -Path $Vault -Recurse -Directory |
        Where-Object { $_.FullName -notmatch '[\\/]\.obsidian' } |
        Sort-Object { $_.FullName.Length } -Descending)
    foreach ($d in $dirs) {
        if (-not (Get-ChildItem -LiteralPath $d.FullName -Recurse -File -Force | Select-Object -First 1)) {
            Remove-Item -LiteralPath $d.FullName -Force
        }
    }
    Write-Host "[5/5] 已删除 vault 本地图片 $deleted 张（Obsidian 的 git 插件会自动提交这次删除）"
}

Write-Host ""
Write-Host "同步完成。"
