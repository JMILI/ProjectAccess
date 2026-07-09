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

## 快速启动

```bash
cd /home/ubuntu2404/code_jm/deployProject/ProjectAccess
bash start.sh
```

默认端口：`18200`  
访问：<http://127.0.0.1:18200>

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

先确保你已登录 Sealtun，例如：

```bash
sealtun login gzg
```

然后执行：

```bash
cd /home/ubuntu2404/code_jm/deployProject/ProjectAccess
bash tunnel.sh apply
bash tunnel.sh status
```

### offer / cPlusBook 隧道前置

这两个项目默认不是长驻 Web 服务。为了给卡片提供 Tunnel 入口，需要先本地启动静态文件服务：

```bash
# offer -> http://127.0.0.1:4000
python3 -m http.server 4000 --directory /home/ubuntu2404/code_jm/deployProject/offer

# cPlusBook -> http://127.0.0.1:4001
python3 -m http.server 4001 --directory /home/ubuntu2404/code_jm/deployProject/cPlusBook
```

再执行 `bash tunnel.sh apply`。

## 项目链接检查

可以用下面命令快速检查卡片里配置的 GitHub / Tunnel：

```bash
curl -sS http://127.0.0.1:18200/api/projects
```

当前 6 个项目对应关系：

| 项目 | GitHub | Tunnel |
|---|---|---|
| wisdom | https://github.com/JMILI/wisdom | https://sealtun-wisdom-ui-ns-km83ebvo.sealosgzg.site |
| WestChina-Cloud | https://github.com/JMILI/WestChina-Cloud | https://sealtun-westchina-ui-ns-km83ebvo.sealosgzg.site/main/ |
| encoding_practice | https://github.com/JMILI/encoding_practice | https://sealtun-encoding-practice-web-ns-km83ebvo.sealosgzg.site |
| cPlusBook | https://github.com/JMILI/cPlusBook | https://sealtun-cplusbook-ui-ns-km83ebvo.sealosgzg.site |
| offer | https://github.com/JMILI/offerPDF | https://sealtun-offer-ui-ns-km83ebvo.sealosgzg.site |
| rust-compile-web | https://github.com/JMILI/rust-compile-web | https://sealtun-rust-compile-web-ui-ns-km83ebvo.sealosgzg.site |

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
