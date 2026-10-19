# ObsidianNote 图床

这个仓库是 [ObsidianNote](https://github.com/hxy123666/ObsidianNote1) 笔记的图片图床，通过 GitHub Pages 把图片变成可直接引用的外链，笔记里就不再需要存放图片文件。

- 在线浏览全部图片：<https://hxy123666.github.io/ObsidianNote-pages/>
- 笔记中的引用形式：`![](https://hxy123666.github.io/ObsidianNote-pages/操作系统/assets/第1章/xxxx.jpg)`

## 目录结构

与 Obsidian vault 保持一致（课程名 / assets / 章节）：

```
操作系统/assets/第1章/*.jpg
计算机系统导论/assets/第1章/*.jpg
计算机系统导论/assets/第2章/*.jpg
```

图片文件名是 Obsidian 自动生成的内容哈希，不会重复，也不会冲突。

## 日常使用

在 Obsidian 里正常粘贴截图（图片照旧落在 vault 的 assets 文件夹里），然后运行：

```powershell
D:\资料\新建文件夹\pages\sync.ps1
```

脚本会自动完成 5 件事：

1. **上传**：把 vault 里的新图片复制到本仓库，按课程归档
2. **改写**：把笔记里的 `assets/xxx.jpg` 相对链接改成上面的绝对网址
3. **索引**：重新生成 `index.html` 图片画廊（即上面那个在线浏览页）
4. **推送**：提交并推送本仓库（GitHub Pages 约 1 分钟后生效）
5. **清理**：删除 vault 里已被外链替换的本地图片，Obsidian 的 git 插件会自动提交这次删除

常用参数：

| 参数 | 作用 |
| --- | --- |
| `-KeepLocal` | 只上传和改写链接，保留 vault 本地图片 |
| `-NoPush` | 只做本地改动，不提交推送 |
| `-Vault <路径>` | 指定 vault 目录（默认取上级目录的 `ObsidianNote`） |
| `-BaseUrl <网址>` | 更换图床域名，比如换成 jsdelivr 加速 |

## 注意事项

- 删除本地图片后，Obsidian 里显示图片**需要联网**（换电脑、清缓存后也是如此）。
- GitHub Pages 有软性流量限制（约 100GB/月），个人笔记用量远低于此。
- 国内访问 `github.io` 偶尔偏慢，需要加速时把 `-BaseUrl` 换成 `https://cdn.jsdelivr.net/gh/hxy123666/ObsidianNote-pages@main` 并重新跑一遍脚本即可（链接内容不变，只是域名前缀不同）。
