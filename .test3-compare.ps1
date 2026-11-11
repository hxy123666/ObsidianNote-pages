$ErrorActionPreference = "Stop"
$out = "D:\资料\新建文件夹\pages\.test3-compare.txt"
$lines = New-Object System.Collections.Generic.List[string]

function Get-ImgRefs($path) {
    $r = @()
    if (Test-Path -LiteralPath $path) {
        $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
        foreach ($m in [regex]::Matches($text, '\]\(([^)]+\.(?:jpg|jpeg|png|gif|webp))\)')) {
            $u = $m.Groups[1].Value
            $n = [System.Uri]::UnescapeDataString($u.Substring($u.LastIndexOf('/') + 1))
            if ($r -notcontains $n) { $r += $n }
        }
    }
    return ,$r
}

$srcRefs = Get-ImgRefs "D:\资料\操作系统\test3.md"
$vaultRefs = Get-ImgRefs "D:\资料\新建文件夹\ObsidianNote\操作系统\test3.md"
$lines.Add("源 test3.md 图片引用数: $($srcRefs.Count)")
$lines.Add("vault test3.md 图片引用数: $($vaultRefs.Count)")

$srcDir = "D:\资料\操作系统\assets\第3章"
$srcFiles = @()
if (Test-Path $srcDir) { $srcFiles = @(Get-ChildItem $srcDir -File | ForEach-Object { $_.Name }) }
$lines.Add("源 第3章 文件数: $($srcFiles.Count)")

$bedDir = "D:\资料\新建文件夹\pages\操作系统\assets\第3章"
$bedFiles = @()
if (Test-Path $bedDir) { $bedFiles = @(Get-ChildItem $bedDir -File | ForEach-Object { $_.Name }) }
$lines.Add("图床 第3章 文件数: $($bedFiles.Count)")
$lines.Add("")
$lines.Add("--- vault test3.md 引用逐个核对 ---")
foreach ($n in $vaultRefs) {
    $inSrc = $srcFiles -contains $n
    $inBed = $bedFiles -contains $n
    $lines.Add("  $n  源=$inSrc  图床=$inBed")
}
$lines.Add("")
$lines.Add("--- 源 test3.md 引用（不在 vault 引用里的）---")
foreach ($n in $srcRefs) {
    if ($vaultRefs -notcontains $n) { $lines.Add("  仅源引用: $n  (源文件存在=$($srcFiles -contains $n))") }
}
[System.IO.File]::WriteAllLines($out, $lines, (New-Object System.Text.UTF8Encoding($false)))
"对比完成"
