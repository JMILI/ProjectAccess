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
- rust-thread-async-memory（Rust 内存/线程教程）

## 前置条件（一条命令体检）

```bash
cd /home/ubuntu2404/code_jm/deployProject/ProjectAccess
bash pa.sh doctor          # node / npm / cargo / java / mvn / sealtun / docker + 各端口
```

缺什么补什么（本机已装好的版本）：

| 依赖 | 用途 | 本机现状 |
| --- | --- | --- |
| Node 18 + npm | 全部前端（vite / vue-cli） | `/opt/node/bin`（v18.20.4） |
| Rust stable | hub、encoding、offer、rust-compile | `~/.cargo/bin`（1.99.1；README 旧版 1.75 读不了 lockfile v4） |
| Rust nightly | rust-compile 后端（`backend/rust-toolchain.toml`） | 1.101.0-nightly |
| **JDK 8** | WestChina-Cloud 后端（Spring Cloud） | `/usr/lib/jvm/java-8-openjdk-amd64`，`~/tools/jdk8` 是软链 |
| Maven 3.8 | 首次构建 WestChina 后端（`mvn package`） | `apt install maven` |
| Docker | wisdom / WestChina 的 mysql·redis·nacos·rabbit·minio | 中间件容器常驻 |
| Sealtun | 公网隧道 | **锁 0.0.40**（0.0.41/0.0.42 云端镜像 404，起不来） |

> Sealtun 版本一定要 0.0.40：`npm i -g sealtun@0.0.40`。0.0.42 生成的 Pod 会 `ImagePullBackOff`（`ghcr.io/gitlayzer/sealtun:0.0.42` 已被删除），表现为 `wait for ready: context deadline exceeded`。

## 快速开始（pa.sh 一键）

```bash
cd /home/ubuntu2404/code_jm/deployProject/ProjectAccess

bash pa.sh up                 # 默认 8 个项目：本地 + 隧道（wisdom 未恢复，见下）
bash pa.sh up wisdom          # 显式点名才会尝试 wisdom
bash pa.sh up light           # 轻量组合（跳过 wisdom / WestChina）
bash pa.sh up encoding offer hub   # 只起这几个（可任意组合）
bash pa.sh status             # 端口 + 隧道状态
bash pa.sh url                # 打印本地与公网链接
bash pa.sh down               # 停所选项目（默认全部）：先停隧道再停本地
bash pa.sh down rust-thread   # 只停一个
bash pa.sh restart offer      # 重启单个
```

`pa.sh` 只是对 `start_all.sh` / `stop_all.sh` / `tunnel.sh` / `status_all.sh` 的薄封装，参数与它们一致，方便记忆；老命令仍然可用。

常用环境变量（传给底层脚本）：

| 变量 | 作用 |
| --- | --- |
| `SKIP_TUNNEL=1` | 只起本地（等价 `bash pa.sh up-local`） |
| `KEEP_TUNNEL=1` | 只停本地，保留隧道（等价 `bash pa.sh down-local`） |
| `RESTART_SEALTUN=1` | 起服务前强杀并重启 sealtun daemon |
| `ALLOW_PARTIAL=1` | 部分失败也算成功（退出码 0） |

## 项目与端口一览

| 项目 | 本地 | 公网隧道 |
| --- | --- | --- |
| ProjectAccess hub | http://127.0.0.1:18200/ | https://sealtun-project-access-ns-km83ebvo.sealosgzg.site/ |
| encoding_practice（教程 + 试验台） | http://127.0.0.1:3000/ | https://sealtun-encoding-practice-web-ns-km83ebvo.sealosgzg.site/ |
| cPlusBook | http://127.0.0.1:4001/ | https://sealtun-cplusbook-ui-ns-km83ebvo.sealosgzg.site/ |
| offer（求职工作台） | http://127.0.0.1:4000/ | https://sealtun-offer-ui-ns-km83ebvo.sealosgzg.site/ |
| rust-compile-web（前端/后端） | http://127.0.0.1:5175/ · API http://127.0.0.1:18080/ | https://sealtun-rust-compile-web-ui-ns-km83ebvo.sealosgzg.site/ |
| fengsheng（风声） | http://127.0.0.1:5173/ | https://sealtun-fengsheng-vue-ns-km83ebvo.sealosgzg.site/ |
| rust-thread-async-memory | http://127.0.0.1:5180/ | https://sealtun-rust-thread-async-memory-ui-ns-km83ebvo.sealosgzg.site/ |
| WestChina-Cloud | http://127.0.0.1:5000/main/ · /administrator/ · /ct/ | https://sealtun-westchina-ui-ns-km83ebvo.sealosgzg.site/main/ |
| wisdom | http://127.0.0.1:9527/ | https://sealtun-wisdom-ui-ns-km83ebvo.sealosgzg.site/ |

> `wisdom` 目前在 `deployProject/wisdom/` 下只剩 `front/`，代码未恢复，跑不起来；因此 `pa.sh up` 的默认集合是上表 **去掉 wisdom 的 8 个**。
> 恢复后想带上它，用 `bash pa.sh up wisdom` 或 `bash start_all.sh wisdom`。

实测结论（2026-10-31）：**VPN 开 / 关都不影响**本地 `127.0.0.1` 与公网隧道访问 —— WSL 是 mirrored 网络（`.wslconfig` 由 devnet 生成），Windows 代理 bypass 里含 `localhost;127.*;192.168.*`，隧道域名走公网直连。

## 网络层（VPN 开/关 + 本地预览 + 隧道）

多项目端口与 Sealtun 隧道依赖本机直连；GitHub 出站才需要代理。统一用仓库旁路 **`~/code_jm/devnet`**：

```bash
cd ~/code_jm/devnet && chmod +x bin/net
./bin/net install              # 开终端自动探测 Windows 代理
./bin/net wslconfig --apply    # 推荐镜像网络；PowerShell 再执行 wsl --shutdown
net doctor                     # 体检
net git-clone https://github.com/JMILI/ProjectAccess.git   # 有/无 VPN 都能 clone
```

原则：`http_proxy` 只给 GitHub/npm；`NO_PROXY` 保护 `127.0.0.1` 与 `*.sealos*`。详见 [`../../devnet/README.md`](../../devnet/README.md)。

**是否并入本文档：不并入，保持 devnet 独立。** 理由：devnet 是"机器级网络层"（代理探测、WSL mirrored、git 镜像），影响所有项目而不只 ProjectAccess；合并会让本仓库的部署文档掺进与项目无关的网络配置。这里只保留「先跑 `net doctor` 再起项目」的调用约定：

```bash
cd ~/code_jm/devnet && ./bin/net auto     # 按当前是否开 VPN 自动切代理策略
./bin/net status                          # 看当前 proxy / NO_PROXY
```

## 快速启动

```bash
cd /home/ubuntu2404/code_jm/deployProject/ProjectAccess
bash start.sh
```

### 一键启动 / 停止全部项目

**默认行为：本地 + 隧道一起启停。** 只有显式加参数才跳过隧道。

管理 ProjectAccess 卡片中的项目 + 中心 Hub：

```bash
cd /home/ubuntu2404/code_jm/deployProject/ProjectAccess

# ① 先确保 Sealtun 可用（Workspace 不能是 unavailable）
sealtun login gzg

# ② 推荐：本地 + 隧道一起起（默认）
bash start_all.sh cplusbook encoding rust-compile WestChina fengsheng hub
bash start_all.sh cplusbook encoding rust-compile WestChina  hub
# 仅本地（显式跳过隧道）
# SKIP_TUNNEL=1 bash start_all.sh cplusbook encoding rust-compile WestChina fengsheng hub

# 隧道全 stale / 刚充值后：可强制重启 daemon 再恢复
# RESTART_SEALTUN=1 bash start_all.sh cplusbook encoding rust-compile WestChina fengsheng hub

# 停止：默认停隧道 + 本地
bash stop_all.sh cplusbook encoding rust-compile WestChina fengsheng hub

# 只停本地、保留隧道
# KEEP_TUNNEL=1 bash stop_all.sh cplusbook encoding rust-compile WestChina fengsheng hub
bash stop_all.sh cplusbook && bash start_all.sh cplusbook
# 查看各端口与隧道状态
bash status_all.sh

# 启动全部 8 个（WestChina + 轻量项目 + Hub + fengsheng + rust-thread；wisdom 需显式指定）
bash start_all.sh

# 仅启动轻量项目（跳过 wisdom / WestChina，省内存）
bash start_all.sh light

# 停止全部
bash stop_all.sh

# 停止并关闭 Docker 中间件（wisdom / WestChina）
STOP_DOCKER=1 bash stop_all.sh wisdom westchina
```

`start_all` **退出码**：所选本地全 UP 且隧道全 active → `0`；否则 → `1`（除非 `ALLOW_PARTIAL=1` 或 `SKIP_TUNNEL=1` 且本地 OK）。

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

4. **`wait for ready: context deadline exceeded`（所有新隧道都这样）** — 看云端事件确认是不是镜像拉不下来（`sealtun` 0.0.42/0.0.41 的 GHCR 镜像已被删除）：

```bash
# 本地版本 → 0.0.40（镜像仍存在）
npm i -g sealtun@0.0.40
sealtun --version
# 清掉旧会话残留锁，然后逐条 apply（一次 apply 多条容易互相等超时）
pkill -f sealtun; rm -f ~/.sealtun/sessions.lock ~/.sealtun/tunnel-*.lock
sealtun apply -f <(printf 'version: v1\ntunnels:\n  - name: offer-ui\n    localPort: 4000\n    protocol: https\n')
```

5. **WestChina 5000 只有 404** — 本地 UI 进程在跑，但 `deploymentServer/ui-dist` 为空（前端没构建过）。首次需要构建后端 + 前端：

```bash
cd /home/ubuntu2404/code_jm/deployProject/WestChina-Cloud
mvn -B -Dmaven.test.skip=true package          # 产出各模块 jar（JDK8）
bash scripts/build.sh frontend-only            # 或逐个：westChina-ui/{main,administrator,ct} npm i && vue-cli-service build
# 产物拷贝到 deploymentServer/ui-dist/<module> 后重启 UI
bash start_all.sh ui-only
```

`~/tools/jdk8` 必须存在（`scripts/env.sh` 优先用它）：`ln -s /usr/lib/jvm/java-8-openjdk-amd64 ~/tools/jdk8`。

`westChina-ui/ct`（阅片系统，路由 `/ct/`）单独构建时有两个坑，已在仓库里修好/补齐，换机器复现时照做：

```bash
# ① ct 的 webpack alias 指向 .vendor-src/（源码目录，不是 npm 包），而这三个包是 git+ssh 依赖，没有 SSH key 装不上：
#    用 HTTPS 拉下来放进 .vendor-src
git clone --depth 1 https://github.com/JMILI/cornerstoneTools.git       /tmp/cs-cornerstoneTools
git clone --depth 1 https://github.com/JMILI/cornerstoneFileImageLoader.git /tmp/cs-cornerstoneFileImageLoader
git clone --depth 1 https://github.com/JMILI/cornerstoneWADOImageLoader.git /tmp/cs-cornerstoneWADOImageLoader
cd westChina-ui/ct && mkdir -p .vendor-src
rsync -a --exclude .git --exclude node_modules /tmp/cs-cornerstoneTools/ .vendor-src/cornerstoneTools/
rsync -a --exclude .git --exclude node_modules /tmp/cs-cornerstoneFileImageLoader/ .vendor-src/cornerstoneFileImageLoader/
rsync -a --exclude .git --exclude node_modules /tmp/cs-cornerstoneWADOImageLoader/ node_modules/cornerstone-wado-image-loader/

# ② minio 7.1+ 的 dist 用了 class field，webpack4 解析不了：vue.config.js 已把 minio alias 到 CJS 入口
#    （'minio': resolve('node_modules/minio/dist/main/minio.js')），并把 minio 固定到 7.0.32
npm i minio@7.0.32 --no-save
NODE_OPTIONS=--openssl-legacy-provider npx vue-cli-service build
cp -r dist ../../deploymentServer/ui-dist/ct
```

`/ct/` 页面能打开（200）即可；真正的阅片功能还依赖 `westChina-modules-ct.jar`（9800）与 file（9300）、minio，`bash runlocal.sh start core` 会一起起。

6. **隧道页面变成 Sealtun 的 502 页（`Your public tunnel is online, but the local client is not connected`）** — 云端隧道还在，但本地 `sealtun daemon` 被带走了（脚本/终端退出时被杀，历史 bug：daemon 用 `&` 启动没脱离会话）。

```bash
# 现在 projects_lib.sh 已用 setsid+nohup 起 daemon，重跑一次即可恢复（会话记录还在，会自己重连）
cd /home/ubuntu2404/code_jm/deployProject/ProjectAccess
RESTART_SEALTUN=1 bash pa.sh tunnel up
bash pa.sh status | tail -20
```

7. **`pa.sh down` 之后端口还占着（`status_all` 仍 OK）** — 端口上是别的用户（典型是以前用 `wsl -u root` 起过的残留）的进程，普通用户 `ss -p` 看不到 pid。`kill_port()` 已经加了 `fuser -k` 兜底，仍清不掉时：

```bash
wsl -d Ubuntu-24.04 -u root -- bash -c 'fuser -k 5173/tcp 5180/tcp 18200/tcp'
# 或者整机重启 WSL（会停掉所有服务，之后 bash pa.sh up 一把起）
```

## 命令正常 / 异常对照（看终端就能判断）

### `bash status_all.sh`

**本地已全部停止（正常停机）：**

```text
ProjectAccess managed services
----------------------------------------
  ProjectAccess hub  :18200  DOWN
  wisdom UI          :9527   DOWN
  WestChina UI       :5000   DOWN
  encoding_practice  :3000   DOWN
  offer              :4000   DOWN
  cPlusBook          :4001   DOWN
  fengsheng UI       :5173   DOWN
  rust-compile UI    :5175   DOWN
  rust-compile API   (8080/18080) DOWN
----------------------------------------
Active sealtun tunnels (named):
  (sealtun list timeout or unavailable — check: sealtun status / login gzg)
```

说明：默认 `stop_all.sh` 会先停所选 **Sealtun 隧道**，再停本地进程（`KEEP_TUNNEL=1` 可只停本地）。若 `sealtun list` 超时 / `Workspace: unavailable`，外网链接本来就打不开；本地仍应全部显示 `DOWN`。

**本地启动成功（示例，端口 OK）：**

```text
  ProjectAccess hub  :18200  OK (200)  http://127.0.0.1:18200/
  WestChina UI       :5000   OK (200)  http://127.0.0.1:5000/main/
  encoding_practice  :3000   OK (200)  http://127.0.0.1:3000/
  cPlusBook          :4001   OK (200)  http://127.0.0.1:4001/
  fengsheng UI       :5173   OK (200)  http://127.0.0.1:5173/
  rust-compile UI    :5175   OK (200)  http://127.0.0.1:5175/
  rust-compile API   :8080   OK (200)  http://127.0.0.1:8080/
```

**隧道也正常时**，底部应出现类似：

```text
Active sealtun tunnels (named):
  NAME                    STATUS
  project-access          active
  westchina-ui            active
  encoding-practice-web   active
  ...
```

### `bash stop_all.sh`

**正常结束应看到：**

```text
[HH:MM:SS] === stop ProjectAccess (18200) ===
[HH:MM:SS] stopped hub (pid ...)
...
[HH:MM:SS] === stop_all done ===
```

然后 `status_all` 各端口均为 `DOWN`（见上）。  
若只要再停 Docker 中间件：`STOP_DOCKER=1 bash stop_all.sh wisdom westchina`。

### `sealtun status` / `sealtun login gzg`

**可用（隧道可恢复）：**

```text
  Logged in: yes
  Workspace: ns-km83ebvo          # 或具体可用命名空间，绝不能是 unavailable
  Daemon
    Running: yes
```

**当前常见异常（你终端里就是这种）：**

```text
  Logged in: yes
  Authenticated at: 2026-09-16T...
  Workspace: unavailable             # 可能只是登录元数据缺失，不等于一定欠费
  Namespace: ns-km83ebvo             # 若有这一行，隧道仍可能可用
```

说明：`Workspace: unavailable` 在 sealtun 里表示 `auth.json` 没写下 `current_workspace`（登录时拉工作区列表失败也会这样），**不是**实时欠费探测。充值并重新登录后，只要下面仍有 `Namespace: ns-...`，可直接 `sealtun start ...` / `bash start_all.sh ...` 试隧道。

若登录成功时应看到类似：`Logged in to workspace: ns-…`；没有这行时 status 会一直显示 unavailable，可再执行一次 `sealtun login gzg`。

```text
# 真正连不上云端时常见：
failed to request device authorization: ... context deadline exceeded
```

处理：打开 https://gzg.sealos.run 充值并确认命名空间可用 → 网络通后再 `sealtun login gzg` →  
`SKIP_TUNNEL=1` 可先只起本地；隧道恢复后再去掉该变量或跑 `bash tunnel.sh apply ...`。

### `bash start_all.sh cplusbook encoding rust-compile WestChina fengsheng hub`

**正常应连续刷日志（已改：轻量项目先起，WestChina 最后；等待端口每 10 秒心跳）：**

```text
[HH:MM:SS] mode=all ...
[HH:MM:SS] === encoding_practice (port 3000) ===
[HH:MM:SS] waiting for encoding:3000 (up to 90s)...
[HH:MM:SS] ready encoding:3000 (Ns)
...
[HH:MM:SS] === ProjectAccess hub (port 18200) ===
[HH:MM:SS] ready hub:18200 (Ns)
[HH:MM:SS] === WestChina-Cloud (port 5000) ===
[HH:MM:SS] starting WestChina core in background (Docker + Java + UI; often 1–3 min)
[HH:MM:SS] live log: tail -f .../ProjectAccess/.run/westchina.log
[HH:MM:SS] waiting for westchina:5000 (up to 180s)...
[HH:MM:SS] still waiting westchina:5000... 10/180s ...
[HH:MM:SS] ready westchina:5000 (Ns)
[HH:MM:SS] === sealtun tunnels ...   # 若 Workspace unavailable 会 WARN 并跳过隧道
[HH:MM:SS] === start_all done ===
# 最后自动打印 status_all
```

**你之前「没反应」的原因：**

1. 旧脚本把 **WestChina 放在第一个**，后台日志进 `.run/westchina.log`，前台 `wait_port` **最多静默等 180 秒**，看起来像卡住。
2. 你按了 `^C`，整批启动被中断，后面的 encoding / hub / 隧道都没跑到。
3. 同时 `sealtun login` 超时 + `Workspace: unavailable`，即使本地起完，外网隧道也不会恢复。

**不要 Ctrl+C 硬断。** 若西华在等：另开终端 `tail -f .run/westchina.log`。中断后请再执行一次 `bash stop_all.sh`（后台 Java/前端可能仍在起）。

**只想先验证本地、跳过隧道：**

```bash
SKIP_TUNNEL=1 bash start_all.sh cplusbook encoding rust-compile WestChina fengsheng hub
```

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
