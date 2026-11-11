$ErrorActionPreference = "Continue"
$out = "D:\资料\新建文件夹\pages\.disk-search.txt"
$lines = New-Object System.Collections.Generic.List[string]
$targets = @(
    "57aa524a3d965fd9ff53fd4a3b91ad871e3c2a5385d90d54df20d88f6fd0b9b1.jpg",
    "78750ef30ff00cb4ef4afe95fb5f7e9ff0c6083a376f775085d52332e0c8a261.jpg",
    "823eefe2c75654be16c9022b409d8f46e34898689b00c99b6cb3fb326c59c17e.jpg"
)
# 先搜用户资料目录和常用位置
$roots = @("D:\资料", "C:\Users\hxy\Documents", "C:\Users\hxy\Desktop", "C:\Users\hxy\Downloads", "C:\Users\hxy\OneDrive")
foreach ($root in $roots) {
    if (-not (Test-Path $root)) { continue }
    foreach ($t in $targets) {
        try {
            $found = Get-ChildItem -Path $root -Recurse -Filter $t -File -ErrorAction SilentlyContinue
            foreach ($f in $found) { $lines.Add("[找到] $($f.FullName)  ($([math]::Round($f.Length/1KB))KB)") }
        } catch {}
    }
    $lines.Add("[搜索完成] $root")
}
# Obsidian trash 目录
foreach ($trash in @("D:\资料\新建文件夹\ObsidianNote\.trash")) {
    if (Test-Path $trash) {
        $lines.Add("[存在] $trash :")
        Get-ChildItem $trash -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $lines.Add("    $($_.FullName)  ($([math]::Round($_.Length/1KB))KB)") }
    } else { $lines.Add("[不存在] $trash") }
}
[System.IO.File]::WriteAllLines($out, $lines, (New-Object System.Text.UTF8Encoding($false)))
"磁盘搜索完成"
