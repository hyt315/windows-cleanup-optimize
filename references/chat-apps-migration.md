# 微信 / QQ / 钉钉：数据迁移与缓存清理（Chat Apps）

<!-- skill-doctor: allow-block SEC002（路径示例用 <用户名> / 占位，无真实用户账户路径） -->

> 聊天软件是 C 盘最大"隐形户"之一，而且**迁移按钮就在应用里**。用户说"微信/QQ 占了 40G"或"改了保存位置还是占 C 盘"——读本文。
>
> **来源标注约定（v2.1）**：只有能找到腾讯/钉钉官方页面的菜单路径才写"官方"；其余菜单路径来自社区或实测，标「存疑」，**以当前版本界面为准**，不要照搬给用户当成确定步骤。
>
> **前提共识（有依据）**：微信/QQ 用硬编码路径，**不支持 mklink/junction 迁移**（实测会损坏数据，`pitfalls.md` 58）。正确做法是**应用内的存储位置设置** + 清理遗留目录。

---

## 目录

- [微信 PC 版](#微信-pc-版)
- [QQ NT 版](#qq-nt-版)
- [钉钉](#钉钉)
- [通用排坑清单](#通用排坑清单)

---

## 微信 PC 版

### 版本区分（4.x 新版 vs 旧版，目录结构完全不同）

| 版本 | 数据目录（默认） | 配置/登录缓存目录 |
|------|----------------|-----------------|
| **4.x（新）** | 用户"文档"目录下 `\xwechat_files\wxid_xxx\`（**目录名有官方确认**，见下） | `%APPDATA%\Tencent\xwechat`（实测可近 1 GB，**常被漏掉的 C 盘占用户**；**无官方文档，社区实测**） |
| **3.9 及更早（旧）** | `Documents\WeChat Files\wxid_xxx\` | `%APPDATA%\Tencent\WeChat` |

> **官方确认的目录名**（腾讯客服 FAQ 原文）：4.0 及以上版本因架构不同，会在旧版本微信的**同盘**下新建 **`xwechat_files`** 文件夹存储聊天记录，「新旧版本数据不可混用，不可拷贝旧版本的 `WeChat Files` 数据进入 `xwechat_files`」。来源：[微信Windows版更新至4.0及以上版本常见问题](https://kf.qq.com/faq/250710MraIZj250710QniyAr.html)、[微信Windows版如何从旧电脑迁移聊天记录到新电脑](https://kf.qq.com/faq/190425ZFBzqa190425ZNNzQv.html)。
>
> 实战注意：4.x 的 `xwechat_files` 可能落在 `C:\Users\<用户名>\xwechat_files`（而非 `Documents\` 下），说明"默认文档位置"与"实际落盘位置"可能不一致——这正是"搬不干净"的一个坑。迁移前**用下文验证步骤确认真实位置**。

### 官方迁移步骤（按版本，官方 FAQ 口径）

**微信 4.x（官方入口是「账号和存储」，不是「文件管理」）**：

1. 打开微信 → **主界面右下角「设置」→「账号和存储」→「存储位置」**（腾讯客服 FAQ 原文）。
2. 选择 D 盘新目录（如 `D:\WeChatData`）→ 按提示完成迁移并重启微信。
3. **重启后验证**：登录正常、历史聊天记录可打开；任务管理器里微信进程名可能是 `Weixin.exe`（4.x，「存疑」需在实机确认）或 `WeChat.exe`，两个都查。
4. 缓存清理优先用微信自带的存储空间管理功能（「存疑」菜单名随版本变化，以当前界面为准；先确认聊天记录已备份）。

> 腾讯 FAQ 里"把新版本存储位置改到旧版本 `WeChat Files` 的同级目录"这句话，**只适用于"重装系统后打开 4.x 没有触发聊天记录导入"的情况**，不是通用迁移步骤。

**微信 3.x 及更早（官方用词是「通用设置」）**：

1. 登录 PC 微信 → **设置 → 通用设置** → 找到"微信文件默认保存位置"（官方 FAQ 原文为「设置–通用设置」；社区常用叫法"设置 → 文件管理 → 更改"是界面内选项卡名）。
2. 强烈建议（官方 FAQ 原话）**将微信文件默认保存位置更改至非系统盘**。
3. 选 D 盘目录 → 确定 → 重启微信验证。

> **官方来源**：
> - [微信Windows版更新至4.0及以上版本常见问题](https://kf.qq.com/faq/250710MraIZj250710QniyAr.html)：4.x "主界面右下角「设置」-「账号和存储」-「存储位置」"，`xwechat_files` 目录，旧记录自动导入、优先用硬连接迁移
> - [微信Windows版如何从旧电脑迁移聊天记录到新电脑](https://kf.qq.com/faq/190425ZFBzqa190425ZNNzQv.html)：3.x"设置–通用设置"，"建议微信文件默认保存位置更改至非系统盘"
> - 腾讯客服微信专区（可检索全部微信 FAQ）：https://kf.qq.com/product/weixin.html

### 缓存目录与安全清理

| 内容 | 位置 | 清理方式 |
|------|------|---------|
| 4.x 图片/视频/文件缓存 | `xwechat_files\wxid_*\cache`、`temp` | 应用内存储空间管理优先；或**完全退出微信后**用模板 7（`t07-safe-recycle.ps1 -Path … [-Apply]`）把这两个子目录移入回收站 |
| 4.x 全局缓存/日志 | `%APPDATA%\Tencent\xwechat\{log,crashinfo,dump}` | 社区实测可清：完全退出微信后用模板 7 移入回收站；**严禁动 `config`（配置）**，`xplugin`（插件沙箱）删后会重新下载 |
| 4.x 小程序运行时缓存 | `%APPDATA%\Tencent\xwechat\radium\Applet` | 在微信内删除不用的小程序，或通过存储空间管理清理（「存疑」菜单路径以当前版本为准） |
| 旧版缓存 | `WeChat Files\<wxid>\FileStorage\{Cache,Image,Video}` | 应用内清理优先；直接删会丢原图/缩略图 |

> 按 `pitfalls.md` 8：微信缓存格式私有，**优先应用内清理**，直接删文件夹可能损坏聊天记录。

### 微信 4.x 升级后旧版 `WeChat Files` 的处置

- **先弄清楚它是不是"孤岛"**：按腾讯 FAQ，4.0 及以上版本**会自动导入当前登录账户的旧版本聊天记录**，并且"**优先使用硬连接技术来迁移数据，大部分文件、图片和视频等不会占用双份空间**"。
  - 所以旧 `WeChat Files` 和新 `xwechat_files` 里很多文件是**同一份数据的两个硬链接**。资源管理器"属性"和本技能的递归统计都会**重复计算**，C 盘总量看起来比实际大。
  - **删除旧 `WeChat Files` 释放的空间可能远小于它显示的大小**（只有没被硬链接到新目录的那部分才会真正释放）。
  - 仍然可能有真正的残留：多账号里**没在 4.x 登录过的账号**、导入前就存在的旧缓存等。
- **安全处置 SOP**：
  1. **确认导入完成**：在 4.x 里打开几个老聊天，能看到旧消息和旧文件；多账号要逐个账号确认。
  2. **估算真实可释放量**（只读）：对几个大文件用 `fsutil hardlink list "<文件路径>"` 看是否同时出现在 `xwechat_files` 下；或用 WizTree 这类按文件 ID 去重的工具看。告诉用户"显示 X GB，实际大约能释放 Y GB"。
  3. **冷备观察**：把 `Documents\WeChat Files` 重命名为 `WeChat Files_old`，正常使用微信 3~7 天。
  4. **移入回收站**：用户确认后用模板 7（`t07-safe-recycle.ps1 -Path … [-Apply]`，即 `Invoke-WcoRecycle`）。它会先检查回收站是否可用、容量是否够，不够就拒绝而不是永久删除。
  5. 用户再次确认后清空回收站。**不要把旧数据拷进 `xwechat_files`**（腾讯 FAQ：新旧数据不可混用）。

### "改了保存位置占 C 盘还是涨"——逐个排查

1. 设置→账号和存储 显示的新路径是否真在 D 盘？
2. `%APPDATA%\Tencent\xwechat` 是否还在 C 盘（包含 `xplugin` 插件与日志，近 1 GB 级，**不会随迁移自动搬走**，需在退出后定期清 `log/crashinfo`）？
3. 旧 `Documents\WeChat Files` 是否还在？（注意硬链接：它显示的大小不等于删掉能释放的空间，见上节）
4. **OneDrive 冲突与 Fallback**：若用户的「文档」开启了 OneDrive 备份/同步，微信 4.x 遇到同步锁或跨驱动器冲突时会回退至 `$env:USERPROFILE\xwechat_files`，导致实际落盘位置与默认文档目录不一致。

### 迁移后验证（只读统计）

```powershell
# 确认 D 盘目标有对应体积、C 盘不再增长
# 注意：这种按文件求和的方式会把硬链接重复计算（旧 WeChat Files 与 xwechat_files 之间常见），只看量级和趋势
(Get-ChildItem "D:\WeChatData\xwechat_files" -Recurse -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum/1GB
(Get-ChildItem "$env:USERPROFILE\xwechat_files" -Recurse -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum/1GB   # 应显著变小
(Get-ChildItem "$([Environment]::GetFolderPath('MyDocuments'))\xwechat_files" -Recurse -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum/1GB
```

### "暂时无法迁移"怎么办（社区排坑）

常见原因：微信进程存活占用文件 / 目标盘空间不足 / 目标目录已有同名残留。**对策**：彻底退出微信（确认任务管理器无 `Weixin.exe` / `WeChat.exe` / `WeChatAppEx.exe`） → 换一个全新的空目录重试 → 确保 D 盘余量充足。

---

## 企业微信（WeCom / WXWork）

- **数据位置**：
  - 核心文档与文件：默认在 `Documents\WXWork\` 或 `$env:USERPROFILE\Documents\WXWork`
  - 运行时配置与缓存：`%APPDATA%\Tencent\WXWork\`
- **迁移路径**（「存疑」未找到腾讯官方页面，菜单名以当前版本界面为准）：
  - 打开企业微信 → 设置 → 找"文件存储位置/更改"类选项 → 选 D 盘目录（如 `D:\WXWorkData`）→ 按提示迁移。
- **安全清理缓存**：
  - 优先用企业微信自带的清理缓存功能（「存疑」菜单路径同上）。
  - 手动清理：彻底退出企业微信进程（`WXWork.exe`），用模板 7（`t07-safe-recycle.ps1 -Path … [-Apply]`）把 `%APPDATA%\Tencent\WXWork\Data\Crash` 及 `log` 目录移入回收站；**不要删除任何含有聊天记录的 `.db` 文件**。
- 公司管理的企业微信可能有管理员策略限制存储位置，改不了时不要绕过。

---

## QQ NT 版

### 迁移步骤（「存疑」：未找到腾讯官方页面，菜单路径来自社区/实测）

> **界面路径（QQ NT 架构，v9.9+，以当前版本为准）**：
> 1. **聊天记录存储位置**：QQ 左下角菜单 → 设置 → 存储管理（各版本名称可能不同）→ 更改存储位置 → 选择 D 盘目录（如 `D:\QQNTData`）→ 按提示迁移并重启 QQ。
> 2. **接收文件保存位置**：在设置里找"文件"相关选项修改默认接收文件夹（如 `D:\QQFiles`）。
> 3. 数据目录：用户"文档"下 `Tencent Files\<QQ号>`（腾讯 FAQ 称为"QQ 个人文件夹"）。
> 
> **排坑说明**："改了不生效/写回 C 盘"——根因通常是后台残留 `QQ.exe` 进程导致配置覆写，改完务必彻底退出并重启验证。

**可用官方参考**（只能证明目录和架构，**不含**上面的迁移菜单路径）：
- QQ 官方客服专区（FAQ 检索入口）：https://kf.qq.com/product/QQ.html
- 官方承认"QQ 个人文件夹"：[电脑端QQ登录提示"QQ个人文件夹中的文件被占用"](https://kf.qq.com/faq/230412aANFzq230412iqEr2M.html)
- 官方确认"基于 QQNT 技术架构"：[腾讯软件中心](https://pc.qq.com/detail/15/detail_35095.html)

### 缓存清理

- 优先用 QQ 自带的存储管理清理缓存；确定不再需要的旧 `Tencent Files\<QQ号>` 目录（已迁移并验证后），先重命名观察，再用模板 7 移入回收站。

---

## 钉钉

- **菜单路径**（「存疑」：未找到钉钉官方帮助页）：社区引用钉钉客服的说法是 Windows 版 **头像 → 设置与隐私 → 高级 → 清理缓存**；接收文件位置也在设置里修改。应用数据目录本身没有改盘符的选项。
- **目录**（「存疑」，版本不同名字不同）：社区报告在 `%APPDATA%\DingTalk`，部分版本为 `%LOCALAPPDATA%\DingTalk_<数字>`（Chromium/Electron 系，含 `Cache`、`Code Cache`、`GPUCache`、`Local Storage` 等）。以只读扫描实际找到的目录为准。
- **安全清理**：优先用应用内清理缓存；手动时完全退出钉钉，用模板 7 把 `Cache`、`Code Cache`、`GPUCache` 子目录移入回收站（不影响账号与组织数据）。
- **卸载残留"钉钉保镖"（AlibabaProtect）**：钉钉卸载后服务和 `C:\Program Files (x86)\AlibabaProtect` 可能仍在（`pitfalls.md` 39）。**不要直接 `sc delete` + `rd /s /q`**（`rd /s /q` 是永久删除，没有演练、备份和撤销）。按下面顺序（管理员）：
  1. 确认电脑上**没有其他阿里系软件**仍依赖它（`Get-WcoInstalledProgram -Name '*Ali*'`、`'*淘宝*'`、`'*钉钉*'` 等），有就保留。
  2. 停用并观察：`Set-WcoServiceStartType -Name AlibabaProtect -StartType disabled`（演练）→ 加 `-Apply` → 重启后确认一切正常。
  3. 删除服务：`Remove-WcoService -Name AlibabaProtect`（演练）→ 加 `-Apply`。它会先 `reg export` 服务键，撤销 = `reg import` 后重启。若被自我保护拒绝，报告给用户，不强行绕过。
  4. 目录：先重命名为 `AlibabaProtect.old` 观察，再用模板 7（`t07-safe-recycle.ps1 -Path … [-Apply]`）移入回收站。
  5. `Export-WcoUndo` 生成撤销脚本；完成后重新扫描确认。

---

## 通用排坑清单

| 坑 | 对策 |
|----|------|
| 迁移中断 | 应用内迁移中断不会立刻丢旧目录（新目录不完整可重来），但会产生新旧两份数据；手动 robocopy 中断则目标不完整，需清掉重来 |
| "改了还占 C 盘" | 应用内迁移只搬数据目录，**配置/登录缓存（如 `%APPDATA%\Tencent\xwechat`）还在 C盘**，需单独清理（见各节） |
| 与 OneDrive 冲突 | 不要用 mklink 把网盘已知文件夹指向外部盘；微信 4.x 遇 OneDrive 同步会回退到 Profile 根目录 |
| 微信 4.x 目录落在非文档位置 | 迁移前先用只读统计探测 `$env:USERPROFILE\xwechat_files` 与 `Documents\xwechat_files` 两处 |

---

## 相关文档

- 其他软件官方迁移 → `drive-migration-official.md`
- mklink 兜底（聊天软件列为不兼容）→ `mklink-migration.md`
- 缓存清理走回收站的安全封装 → `scan-scripts.md` 模板 7（`t07-safe-recycle.ps1` / `Invoke-WcoRecycle`）
- 卸载流程与残留打分 → `software-uninstall.md`

