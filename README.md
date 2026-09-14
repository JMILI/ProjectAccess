# ProjectAccess

基于 Rust + Axum 的项目管理中心，用卡片统一管理多个 Web 项目，并提供项目详情页：

- 项目介绍
- 架构图（Mermaid）
- 技术栈与用途（表格）
- 业务逻辑说明（Markdown 表格）
- 本地链接与隧道链接

当前已接入项目：

- wisdom
- westChina (WestChina-Cloud)
- encoding_practice
- cPlusBook
- offer
- rust-compile-web
- fengsheng（风声）

## 快速启动

```bash
cd /home/ubuntu2404/code_jm/deployProject/ProjectAccess
bash start.sh
```

### 一键启动 / 停止全部项目

管理 ProjectAccess 卡片中的 7 个项目 + 中心 Hub：

```bash
cd /home/ubuntu2404/code_jm/deployProject/ProjectAccess

# ① 先确保 Sealtun 登录有效（过期会出现 Unauthorized / 隧道全是 stale）
sealtun login gzg

# ② 推荐：本地 + 隧道一起起（含风声 :5173）
# 注意：隧道已有部分 active 时不要加 RESTART_SEALTUN=1（会误杀 daemon）
bash start_all.sh cplusbook encoding rust-compile WestChina fengsheng hub

# 隧道全 stale / 刚充值后：可强制重启 daemon 再恢复
# RESTART_SEALTUN=1 bash start_all.sh cplusbook encoding rust-compile WestChina fengsheng hub

# 仅补隧道（本地已在跑时）
# bash tunnel.sh apply cplusbook encoding rust-compile WestChina fengsheng hub

# 启动全部（wisdom + WestChina + 轻量项目 + Hub + fengsheng）
bash start_all.sh

# 仅启动轻量项目（跳过 wisdom / WestChina，省内存）
bash start_all.sh light

# 仅本地、不开隧道
SKIP_TUNNEL=1 bash start_all.sh light

# 查看各端口与隧道状态
bash status_all.sh

# 停止全部（本地进程；隧道会话仍保留为 stale/stopped）
bash stop_all.sh

# 仅停止轻量项目
bash stop_all.sh light

# 停止并关闭 Docker 中间件（wisdom / WestChina）
STOP_DOCKER=1 bash stop_all.sh wisdom westchina
```

日志与 PID 文件目录：`.run/`

默认端口：`18200`  
访问：<http://127.0.0.1:18200>

#### 隧道打不开（本地 OK、外网 `no healthy upstream` / 全是 `stale`/`error`）

**域名一般不会变**：仍是 `https://sealtun-<隧道名>-ns-km83ebvo.sealosgzg.site/`（与卡片里一致）。打不开通常不是换了链接。

按优先级排查：

1. **登录过期** — `sealtun status` 里 `Authenticated at` 很旧；`.run/sealtun-ensure.log` 有 `Unauthorized`  
   → `sealtun login gzg` 后重跑 `RESTART_SEALTUN=1 bash start_all.sh ...`

2. **Sealos 欠费 / 空间无权限**（你说费用用完时最常见）— 已重新登录仍 `Unauthorized`，且 `Workspace: unavailable`；daemon 连 WSS 一直 `connection reset by peer`  
   → 打开 https://gzg.sealos.run → 费用中心充值 → 确认命名空间 `ns-km83ebvo` 仍可用  
   → 再执行：

```bash
cd /home/ubuntu2404/code_jm/deployProject/ProjectAccess
sealtun login gzg
RESTART_SEALTUN=1 bash start_all.sh cplusbook encoding rust-compile WestChina fengsheng hub
bash status_all.sh
curl -sk -o /dev/null -w '%{http_code}\n' https://sealtun-project-access-ns-km83ebvo.sealosgzg.site/
```

3. 仅本地可用时先用：`http://127.0.0.1:18200/` 等本机地址。

失败日志：`.run/sealtun-ensure.log`

## 修改配置后重启

当你改了 `projects-config.json`（例如隐藏/显示项目）后，需要重启服务才会生效。

### 一条命令重启（推荐）

```bash
cd /home/ubuntu2404/code_jm/deployProject/ProjectAccess
PID=$(ss -tlnp | awk '/:18200/ {print $NF}' | awk -F'pid=' '{print $2}' | awk -F',' '{print $1}' | head -n 1); [ -n "$PID" ] && kill "$PID"; bash start.sh
```

### 分步重启

```bash
cd /home/ubuntu2404/code_jm/deployProject/ProjectAccess
# 1) 停服务（如果有）
PID=$(ss -tlnp | awk '/:18200/ {print $NF}' | awk -F'pid=' '{print $2}' | awk -F',' '{print $1}' | head -n 1)
[ -n "$PID" ] && kill "$PID"
# 2) 启服务
bash start.sh
```

## 构建

```bash
cd /home/ubuntu2404/code_jm/deployProject/ProjectAccess
bash build.sh
```

## 隧道访问（Sealtun）

`start_all.sh` 在本地端口就绪后，会按所选项目自动 `sealtun start`（已存在的隧道只 start，不 cleanup）。

**登录会过期。** `sealtun status` 显示 `Logged in: yes` 仍可能 `Unauthorized`——看 `Workspace:` 是否 `unavailable`，或看 `.run/sealtun-ensure.log` 是否有 `Unauthorized`。

```bash
# 登录（过期后必须重做）
sealtun login gzg

# 本地 + 隧道（含风声）
cd /home/ubuntu2404/code_jm/deployProject/ProjectAccess
RESTART_SEALTUN=1 bash start_all.sh cplusbook encoding rust-compile WestChina fengsheng hub
```

单独管隧道：

```bash
bash tunnel.sh apply                          # 对当前已监听端口恢复隧道
bash tunnel.sh apply cplusbook encoding hub fengsheng
bash tunnel.sh status
SKIP_TUNNEL=1 bash start_all.sh ...           # 只起本地
```

> **风声：** 单独 `npm run dev` 不开隧道。用 `start_all.sh ... fengsheng` 会起 `:5173` 并恢复 `fengsheng-vue`。  
> 浏览器 `no healthy upstream` = 域名在、本机 daemon/登录没连上 → 先 `sealtun login gzg`，再 `RESTART_SEALTUN=1 bash start_all.sh ...`。

### offer / cPlusBook 隧道前置

这两个项目通过**静态 HTTP 服务**提供隧道入口（无需后端 API）：

- **offer**：`cargo run` 启动 Axum（简历页 + `/api/resumes`），监听 `:4000`（与 Sealtun 一致）
- **cPlusBook**：先 `mdbook build` 生成 `book/`，再托管该目录，监听 `:4001`

一键启动（含构建与静态服务）：

```bash
bash start_all.sh offer cplusbook
```

手动启动：

```bash
# offer -> http://127.0.0.1:4000/
cd /home/ubuntu2404/code_jm/deployProject/offer
cp resume.html index.html
OPEN_BROWSER=0 cargo run
# 或：bash start_all.sh offer

# cPlusBook -> http://127.0.0.1:4001/
cd /home/ubuntu2404/code_jm/deployProject/cPlusBook && bash build.sh
python3 -m http.server 4001 --directory book --bind 0.0.0.0
```

再执行 `bash tunnel.sh apply`。

## 项目链接检查

可以用下面命令快速检查卡片里配置的 GitHub / Tunnel：

```bash
curl -sS http://127.0.0.1:18200/api/projects
```

也可以使用一键健康检查脚本（会逐项目检测 GitHub/Tunnel 是否可访问并给出失败项）：

```bash
cd /home/ubuntu2404/code_jm/deployProject/ProjectAccess
bash check_links.sh
```

当前 7 个项目对应关系：

| 项目 | GitHub | Tunnel |
|---|---|---|
| 风声 | — | https://sealtun-fengsheng-vue-ns-km83ebvo.sealosgzg.site/ |
| wisdom | https://github.com/JMILI/wisdom | https://sealtun-wisdom-ui-ns-km83ebvo.sealosgzg.site |
| WestChina-Cloud | https://github.com/JMILI/WestChina-Cloud | https://sealtun-westchina-ui-ns-km83ebvo.sealosgzg.site/main/ |
| encoding_practice | https://github.com/JMILI/encoding_practice | https://sealtun-encoding-practice-web-ns-km83ebvo.sealosgzg.site/ |
| cPlusBook | https://github.com/JMILI/cPlusBook | https://sealtun-cplusbook-ui-ns-km83ebvo.sealosgzg.site/ |
| offer | https://github.com/JMILI/offerPDF | https://sealtun-offer-ui-ns-km83ebvo.sealosgzg.site/ |
| rust-compile-web | https://github.com/JMILI/rust-compile-web | https://sealtun-rust-compile-web-ui-ns-km83ebvo.sealosgzg.site/ |

## API

- `GET /api/health`
- `GET /api/info`
- `GET /api/projects`
- `GET /api/projects/{id}`

## 项目显示开关配置

你可以通过 `projects-config.json` 决定页面展示哪些项目。

```json
{
  "show_project_ids": null,
  "hide_project_ids": []
}
```

字段说明：

- `show_project_ids`: 白名单；为 `null` 时表示不过滤（展示全部）
- `hide_project_ids`: 黑名单；会从最终展示结果里排除

项目 ID（可用于配置）：

- `wisdom`
- `westChina`
- `encoding_practice`
- `cPlusBook`
- `offer`
- `rust-compile-web`
- `fengsheng`

示例 1（只展示两个项目）：

```json
{
  "show_project_ids": ["wisdom", "westChina"],
  "hide_project_ids": []
}
```

示例 2（展示全部，但隐藏一个）：

```json
{
  "show_project_ids": null,
  "hide_project_ids": ["offer"]
}
```

## 后续可扩展

如果你希望自动从每个项目目录读取 `README.md` 生成详情页，可在后端新增“配置文件扫描 + markdown 解析”逻辑，避免手工维护项目信息。
