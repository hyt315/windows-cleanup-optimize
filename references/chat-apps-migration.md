# 微信 / QQ / 钉钉：数据迁移与缓存清理（Chat Apps）

<!-- skill-doctor: allow-block SEC002（路径示例用 <用户名> / 占位，无真实用户账户路径） -->

> 聊天软件是 C 盘最大"隐形户"之一，而且**官方迁移按钮就在应用里**。用户说"微信/QQ 占了 40G"或"改了保存位置还是占 C 盘"——读本文。
>
> **前提共识（有依据）**：微信/QQ 用硬编码路径，**不支持 mklink/junction 迁移**（实测会损坏数据，`pitfalls.md` 58）。正确做法是**应用内官方"更改保存位置"** + 清理遗留目录。

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

1. **完全退出微信**（托盘图标 → 退出，确认无进程`WeChat.exe`）。
2. 打开微信 → 左下角"≡"菜单 → **设置 → 账号和存储 → 存储位置 / 更改聊天记录位置**（腾讯客服官方 FAQ 原文用词）。
3. 选择 D 盘新目录（如 `D:\WeChatData`）→ 微信自动复制数据并切换；官方建议将新版本存储位置修改到旧版本 `WeChat Files` 的同级目录。
4. 完成后用**设置 → 通用 → 存储空间管理**清理缓存（先确认聊天记录已备份）。
5. **重启微信**验证登录正常、历史聊天记录可打开。

**微信 3.x 及更早（官方用词是「通用设置」）**：

1. 登录 PC 微信 → **设置 → 通用设置** → 找到"微信文件默认保存位置"（官方 FAQ 原文为「设置–通用设置」；社区常用叫法"设置 → 文件管理 → 更改"是界面内选项卡名）。
2. 强烈建议（官方 FAQ 原话）**将微信文件默认保存位置更改至非系统盘**。
3. 选 D 盘目录 → 确定 → 重启微信验证。

> **官方来源**：
> - [微信Windows版更新至4.0及以上版本常见问题](https://kf.qq.com/faq/250710MraIZj250710QniyAr.html)：4.x "设置→账号和存储→存储位置/更改聊天记录位置"，`xwechat_files` 目录
> - [微信Windows版如何从旧电脑迁移聊天记录到新电脑](https://kf.qq.com/faq/190425ZFBzqa190425ZNNzQv.html)：3.x"设置–通用设置"，"建议微信文件默认保存位置更改至非系统盘"
> - 腾讯客服微信专区（可检索全部微信 FAQ）：https://kf.qq.com/product/weixin.html

### 缓存目录与安全清理

| 内容 | 位置 | 清理方式 |
|------|------|---------|
| 4.x 图片/视频/文件缓存 | `xwechat_files\wxid_*\cache`、`temp` | 应用内"存储空间管理"；或**退出微信后**删这两个子目录 |
| 4.x 全局缓存/日志 | `%APPDATA%\Tencent\xwechat\{log,crashinfo,dump}` | **安全可删**：完全退出微信后清理日志/崩溃转储；**严禁动 `config`（配置）**，`xplugin`（插件沙箱）手删后会触发重新下载 |
| 4.x 小程序运行时缓存 | `%APPDATA%\Tencent\xwechat\radium\Applet` | 建议在微信内「发现 → 小程序」长按删除，或通过存储空间管理清理 |
| 旧版缓存 | `WeChat Files\<wxid>\FileStorage\{Cache,Image,Video}` | 应用内清理优先；直接删会丢原图/缩略图 |

> 按 `pitfalls.md` 8：微信缓存格式私有，**优先应用内清理**，直接删文件夹可能损坏聊天记录。

### 微信 4.0 升级后旧版 3.x 孤岛残留处置（真实高频痛点）

- **产生根因**：微信 4.x 采用新架构，数据目录变更为 `xwechat_files`。用户升级 4.0 并在客户端内将存储位置迁到 D 盘后，微信 4.x **只会迁移新结构数据**。旧版 3.x 积攒在 `Documents\WeChat Files` 中的旧缓存、旧附件（动辄 30GB~80GB）**不会被 4.0 自动清除，也不会在 4.0 界面中显示**，成为永久占满 C 盘的"幽灵孤岛"。
- **安全处置 SOP（借鉴 CleanMyWechat 最佳实践）**：
  1. **只读核验**：确认微信 4.x 已在新目录（如 `D:\WeChatData\xwechat_files`）正常运行，聊天记录与最近联系人均正常加载。
  2. **冷备缓冲（二选一）**：
     - *方案 A（推荐）*：将 `Documents\WeChat Files` 临时重命名为 `WeChat Files_old`，观察使用微信 3~7 天。
     - *方案 B*：使用 `SafeRecycle` 脚本移入 Windows 回收站（保留可随时一键放回的原样撤回能力）。
  3. **彻底释放**：经用户确认无重要未另存的历史离线文档后，清空回收站彻底释放空间。

### "改了保存位置占 C 盘还是涨"——逐个排查

1. 设置→账号和存储 显示的新路径是否真在 D 盘？
2. `%APPDATA%\Tencent\xwechat` 是否还在 C 盘（包含 `xplugin` 插件与日志，近 1 GB 级，**不会随迁移自动搬走**，需在退出后定期清 `log/crashinfo`）？
3. 旧 `Documents\WeChat Files` 是否残留没删（即上述 3.x 孤岛）？
4. **OneDrive 冲突与 Fallback**：若用户的「文档」开启了 OneDrive 备份/同步，微信 4.x 遇到同步锁或跨驱动器冲突时会回退至 `$env:USERPROFILE\xwechat_files`，导致实际落盘位置与默认文档目录不一致。

### 迁移后验证（只读统计）

```powershell
# 确认 D 盘目标有对应体积、C 盘不再增长
(Get-ChildItem "D:\WeChatData\xwechat_files" -Recurse -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum/1GB
(Get-ChildItem "$env:USERPROFILE\xwechat_files" -Recurse -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum/1GB   # 应显著变小
(Get-ChildItem "$([Environment]::GetFolderPath('MyDocuments'))\xwechat_files" -Recurse -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum/1GB
```

### "暂时无法迁移"怎么办（社区排坑）

常见原因：微信进程存活占用文件 / 目标盘空间不足 / 目标目录已有同名残留。**对策**：彻底退出微信（确认任务管理器无 `WeChat.exe` / `WeChatAppEx.exe`） → 换一个全新的空目录重试 → 确保 D 盘余量充足。

---

## 企业微信（WeCom / WXWork）

- **数据位置**：
  - 核心文档与文件：默认在 `Documents\WXWork\` 或 `$env:USERPROFILE\Documents\WXWork`
  - 运行时配置与缓存：`%APPDATA%\Tencent\WXWork\`
- **官方迁移路径**：
  - 打开企业微信 → 左下角三道杠/齿轮 → **设置 → 文档/文件管理 → 更改文件存储位置** → 选 D 盘目录（如 `D:\WXWorkData`）→ 确认后软件自动复制并切换。
- **安全清理缓存**：
  - 优先在企业微信内使用「设置 → 通用 → 清理缓存」。
  - 手动安全清理：彻底退出企业微信进程（`WXWork.exe`），使用 `SafeRecycle` 清理 `%APPDATA%\Tencent\WXWork\Data\Crash` 及 `log` 目录；**不要删除任何含有聊天记录的 `.db` 文件**。

---

## QQ NT 版

### 官方迁移步骤（"更改默认存储路径"）

> **确切界面路径（QQ NT 架构，v9.9+）**：
> 1. **聊天记录存储位置迁移**：点击 QQ 左下角菜单/齿轮 → **设置 → 存储管理**（或通用设置） → 在「聊天记录存储位置」点击 **更改路径 / 迁移** → 选择 D 盘目录（如 `D:\QQNTData`）→ 确认并重启 QQ。
> 2. **接收文件保存位置**：在 **设置 → 文件管理** 中点击 **更改**，修改默认接收文件夹（如 `D:\QQFiles`）。
> 3. 旧版路径：用户"文档"下 `Tencent Files\<QQ号>`。
> 
> **排坑说明**："改了不生效/写回 C 盘"——根因通常是后台残留 `QQ.exe` 进程导致配置覆写，改完务必彻底退出并重启验证。

**可用官方参考**：
- QQ 官方客服专区（FAQ 检索入口）：https://kf.qq.com/product/QQ.html
- 官方承认"QQ 个人文件夹"：[电脑端QQ登录提示"QQ个人文件夹中的文件被占用"](https://kf.qq.com/faq/230412aANFzq230412iqEr2M.html)
- 官方确认"基于 QQNT 技术架构"：[腾讯软件中心](https://pc.qq.com/detail/15/detail_35095.html)

### 缓存清理

- 应用内"设置 → 存储管理"管理缓存；确定不再需要的旧 `Tencent Files\<QQ号>` 目录（已迁移后）可清理。

---

## 钉钉

- **官方说明**：钉钉官方支持在 **「设置 → 通用 → 文件存储」** 中将接收文件修改为 D 盘，在 **「设置 → 通用 → 清理缓存」** 中一键清理；但**不支持**将 `%LOCALAPPDATA%\DingTalk_91` 应用核心数据目录整体修改盘符。
- **目录**：数据在 `%LOCALAPPDATA%\DingTalk_91\`（Chromium/Electron 系，含 `Cache`、`Code Cache`、`GPUCache`、`Local Storage` 等）。
- **安全清理**：完全退出钉钉后，删除 `Cache`、`Code Cache`、`GPUCache` 子目录**内容**（不影响账号与组织数据）。
- **卸载残留**：内核守护服务"钉钉保镖"`C:\Program Files (x86)\AlibabaProtect` 卸载后仍残留，需提权删除（`pitfalls.md` 39）：
  ```cmd
  sc stop AlibabaProtect && sc delete AlibabaProtect
  rd /s /q "C:\Program Files (x86)\AlibabaProtect"
  ```

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
- 缓存清理走回收站的安全封装 → `scan-scripts.md` 模板 7（`SafeRecycle`）

