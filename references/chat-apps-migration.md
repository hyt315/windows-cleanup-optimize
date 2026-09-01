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
| 4.x 全局缓存/日志 | `%APPDATA%\Tencent\xwechat\{log,crashinfo,…}` | 退出微信后清理；**勿动 `config`、`login`** |
| 旧版缓存 | `WeChat Files\<wxid>\FileStorage\{Cache,Image,Video}` | 应用内清理优先；直接删会丢原图/缩略图 |

> 按 `pitfalls.md` 8：微信缓存格式私有，**优先应用内清理**，直接删文件夹可能损坏聊天记录。

### "改了保存位置占 C 盘还是涨"——逐个排查

1. 设置→文件管理 显示的新路径是否真在 D 盘？
2. `%APPDATA%\Tencent\xwechat` 是否还在 C 盘（近 1 GB 级，**不会随迁移自动搬走**，需手动/定期清）？
3. 旧 `Documents\WeChat Files` 是否残留没删？
4. 是否开了 OneDrive 同步"文档"目录 → 微信数据跟着被同步/搬移冲突（社区多篇提及）。

### 迁移后验证（只读统计）

```powershell
# 确认 D 盘目标有对应体积、C 盘不再增长
(Get-ChildItem "D:\WeChatData\xwechat_files" -Recurse -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum/1GB
(Get-ChildItem "$env:USERPROFILE\xwechat_files" -Recurse -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum/1GB   # 应显著变小
```

### "暂时无法迁移"怎么办（社区排坑）

常见原因：微信进程存活占用文件 / 目标盘空间不足 / 目标目录已有同名残留。**对策**：彻底退出微信 → 换一个全新的空目录重试 → 确保 D 盘余量充足。

---

## QQ NT 版

### 官方迁移步骤（"更改默认存储路径"）

> **官方口径**：腾讯官方**未公开**"PC 端更改默认存储路径"的网页文档（kf.qq.com QQ 专区已逐类排查，无此条目；im.qq.com 为 JS 单页无帮助文本）。官方仅在登录 FAQ 中承认"QQ 个人文件夹"概念。**以下步骤为社区验证，标注"官方未公开文档"**，以客户端实际界面为准。

- 新版 QQ（NT 内核）：左下角菜单 → **设置 → 文件管理/存储** → 更改默认存储路径（数据/聊天文件）→ 选 D 盘。
- 旧版路径：用户"文档"下 `Tencent Files\<QQ号>`。
- **坑（社区常见）**："改了不生效"——多是没完全退出 QQ / 下一次启动被写回，改完务必重启 QQ 验证。

**可用官方参考**：
- QQ 官方客服专区（FAQ 检索入口）：https://kf.qq.com/product/QQ.html
- 官方承认"QQ 个人文件夹"：[电脑端QQ登录提示"QQ个人文件夹中的文件被占用"](https://kf.qq.com/faq/230412aANFzq230412iqEr2M.html)
- 官方确认"基于 QQNT 技术架构"：[腾讯软件中心](https://pc.qq.com/detail/15/detail_35095.html)

### 缓存清理

- 应用内"设置 → 存储"管理缓存；确定不再需要的旧 `Tencent Files\<QQ号>` 目录（已迁移后）可清理。

---

## 钉钉

- **官方说明**：钉钉官方**没有**"PC 缓存目录迁移/清理"的公开文档（帮助中心无此条目），以下为社区经验 + 实测。
- **目录**：数据在 `%LOCALAPPDATA%\DingTalk_91\`（Chromium/Electron 系，含 `Cache`、`Code Cache`、`GPUCache`、`Local Storage` 等）；钉钉**不支持**改缓存盘符（社区共识）。
- **安全清理**：完全退出钉钉后，删除 `Cache`、`Code Cache`、`GPUCache` 子目录**内容**（不影响账号与组织数据）。
- **卸载残留**：内核服务"钉钉保镖"`C:\Program Files (x86)\AlibabaProtect` 卸载后仍残留，需提权删除（`pitfalls.md` 39）。

---

## 通用排坑清单

| 坑 | 对策 |
|----|------|
| 迁移中断 | 应用内迁移中断不会立刻丢旧目录（新目录不完整可重来），但会产生新旧两份数据；手动 robocopy 中断则目标不完整，需清掉重来 |
| "改了还占 C 盘" | 应用内迁移只搬数据目录，**配置/登录缓存（如 `%APPDATA%\Tencent\xwechat`）还在 C 盘**，需单独清理（见各节） |
| 与 OneDrive 冲突 | 不要用 mklink 把网盘已知文件夹指向外部盘；先关微信/QQ 再迁移 |
| 微信 4.x 目录落在非文档位置 | 迁移前先用只读统计确认真实位置，别按"文档目录"默认路径想当然 |

---

## 相关文档

- 其他软件官方迁移 → `drive-migration-official.md`
- mklink 兜底（聊天软件列为不兼容）→ `mklink-migration.md`
- 缓存清理走回收站的安全封装 → `scan-scripts.md` 模板 7（`SafeRecycle`）

