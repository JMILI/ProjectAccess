use axum::extract::Path;
use axum::http::StatusCode;
use axum::response::{Html, IntoResponse};
use axum::routing::get;
use axum::{Json, Router};
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fs;
use std::sync::OnceLock;

#[derive(Clone, Serialize)]
struct TechItem {
    name: String,
    purpose: String,
}

#[derive(Clone, Serialize)]
struct ProjectDetail {
    id: String,
    title: String,
    subtitle: String,
    summary: String,
    local_url: Option<String>,
    github_url: Option<String>,
    tunnel_url: Option<String>,
    architecture_markdown: String,
    business_markdown: String,
    tags: Vec<String>,
    technologies: Vec<TechItem>,
}

#[derive(Clone, Serialize)]
struct ProjectCard {
    id: String,
    title: String,
    subtitle: String,
    summary: String,
    tags: Vec<String>,
    github_url: Option<String>,
    tunnel_url: Option<String>,
}

#[derive(Serialize)]
struct HubInfo {
    local_url: String,
    tunnel_setup_hint: String,
}

#[derive(Clone, Deserialize, Default)]
struct ProjectDisplayConfig {
    show_project_ids: Option<Vec<String>>,
    hide_project_ids: Vec<String>,
}

static PROJECT_DISPLAY_CONFIG: OnceLock<ProjectDisplayConfig> = OnceLock::new();

fn project_display_config() -> &'static ProjectDisplayConfig {
    PROJECT_DISPLAY_CONFIG.get_or_init(|| {
        let path = "projects-config.json";
        match fs::read_to_string(path) {
            Ok(content) => match serde_json::from_str::<ProjectDisplayConfig>(&content) {
                Ok(config) => config,
                Err(err) => {
                    eprintln!("[config] parse {path} failed: {err}. fallback to default.");
                    ProjectDisplayConfig::default()
                }
            },
            Err(_) => ProjectDisplayConfig::default(),
        }
    })
}

fn projects() -> Vec<ProjectDetail> {
    let config = project_display_config();
    let show_set = config
        .show_project_ids
        .as_ref()
        .map(|ids| ids.iter().map(String::as_str).collect::<HashSet<_>>());
    let hide_set = config
        .hide_project_ids
        .iter()
        .map(String::as_str)
        .collect::<HashSet<_>>();

    all_projects()
        .into_iter()
        .filter(|p| {
            show_set
                .as_ref()
                .map_or(true, |ids| ids.contains(p.id.as_str()))
        })
        .filter(|p| !hide_set.contains(p.id.as_str()))
        .collect()
}

fn all_projects() -> Vec<ProjectDetail> {
    vec![
        ProjectDetail {
            id: "wisdom".into(),
            title: "wisdom".into(),
            subtitle: "党建管理系统".into(),
            summary: "党内申请、活动审批、资料发布和组织关系管理的一体化系统。".into(),
            local_url: Some("http://127.0.0.1:9527".into()),
            github_url: Some("https://github.com/JMILI/wisdom".into()),
            tunnel_url: Some("https://sealtun-wisdom-ui-ns-km83ebvo.sealosgzg.site".into()),
            architecture_markdown: r#"```mermaid
flowchart TB
  UI["Vue2 前端 :9527"] --> GW["Gateway :8088"]
  GW --> OAUTH["OAuth2"]
  GW --> SVC["Spring Cloud + Dubbo 服务"]
  SVC --> MYSQL["MySQL"]
  SVC --> REDIS["Redis"]
  SVC --> MQ["RabbitMQ"]
  UI --> FDFS["go-fastdfs 文件服务"]
```"#
                .into(),
            business_markdown: r#"| 业务域 | 说明 |
|---|---|
| 党内申请 | 学生/教师发起申请，多级审批流转 |
| 活动申请 | 党支部提交活动，按组织逐级审核 |
| 新闻资料 | 按组织发布和汇总 |
| 文件管理 | 前端直传文件服务，业务表保存路径 |
"#
            .into(),
            tags: vec!["Vue2".into(), "Spring Cloud".into(), "Dubbo".into(), "Nacos".into()],
            technologies: vec![
                TechItem {
                    name: "Vue2 + Element UI".into(),
                    purpose: "构建后台和审批业务界面".into(),
                },
                TechItem {
                    name: "Spring Cloud Gateway".into(),
                    purpose: "统一 API 入口和路由分发".into(),
                },
                TechItem {
                    name: "OAuth2".into(),
                    purpose: "登录认证、角色鉴权和 token 管理".into(),
                },
            ],
        },
        ProjectDetail {
            id: "westChina".into(),
            title: "WestChina-Cloud".into(),
            subtitle: "CT 阅片多租户管理系统".into(),
            summary: "多租户影像云平台，包含 main/administrator/ct 三大系统与 AI 病灶识别能力。".into(),
            local_url: Some("http://127.0.0.1:5000/main/".into()),
            github_url: Some("https://github.com/JMILI/WestChina-Cloud".into()),
            tunnel_url: Some("https://sealtun-westchina-ui-ns-km83ebvo.sealosgzg.site/main/".into()),
            architecture_markdown: r#"```mermaid
flowchart TB
  UI["westChina-ui"] --> GW["Gateway"]
  GW --> AUTH["Auth"]
  GW --> SYS["System/Tenant/CT 微服务"]
  SYS --> MYSQL["MySQL"]
  SYS --> REDIS["Redis"]
  SYS --> MQ["RabbitMQ"]
  SYS --> MINIO["MinIO"]
  AI["AI FastAPI"] --> SYS
```"#
                .into(),
            business_markdown: r#"| 模块 | 业务价值 |
|---|---|
| main | 平台管理、租户和策略配置 |
| administrator | 租户侧组织、权限和运营管理 |
| ct | DICOM 阅片、病灶识别与标注 |
| ai-service | 异步病灶识别，支持多方案推理 |
"#
            .into(),
            tags: vec!["Vue2".into(), "Spring Cloud".into(), "AI".into(), "多租户".into()],
            technologies: vec![
                TechItem {
                    name: "Spring Cloud".into(),
                    purpose: "拆分核心业务服务并统一治理".into(),
                },
                TechItem {
                    name: "RabbitMQ".into(),
                    purpose: "CT 与 AI 推理异步解耦".into(),
                },
                TechItem {
                    name: "Python FastAPI".into(),
                    purpose: "提供 AI 推理服务接口".into(),
                },
            ],
        },
        ProjectDetail {
            id: "encoding_practice".into(),
            title: "encoding_practice".into(),
            subtitle: "UDP 编解码交互实验台".into(),
            summary: "以 Rust Axum 实现的协议组包、解包、位流可视化实验工具。".into(),
            local_url: Some("http://127.0.0.1:3000/".into()),
            github_url: Some("https://github.com/JMILI/encoding_practice".into()),
            tunnel_url: Some("https://sealtun-encoding-practice-web-ns-km83ebvo.sealosgzg.site/".into()),
            architecture_markdown: r#"```mermaid
flowchart LR
  WEB["Axum Web"] --> CODEC["协议编解码模块"]
  CODEC --> UDP["UDP 仿真发送"]
  WEB --> GUIDE["位域图解页面"]
```"#
                .into(),
            business_markdown: r#"| 能力 | 说明 |
|---|---|
| 组包 | 根据字段生成二进制协议 |
| 拆包 | 解析十六进制字节流并还原字段 |
| 可视化 | 位流/位域图帮助理解编码规则 |
"#
            .into(),
            tags: vec!["Rust".into(), "Axum".into(), "UDP".into(), "协议".into()],
            technologies: vec![
                TechItem {
                    name: "Rust".into(),
                    purpose: "保障编码逻辑安全和性能".into(),
                },
                TechItem {
                    name: "Axum".into(),
                    purpose: "提供实验台和教程页面服务".into(),
                },
            ],
        },
        ProjectDetail {
            id: "cPlusBook".into(),
            title: "cPlusBook".into(),
            subtitle: "C++ 系统教程工程".into(),
            summary: "按主题组织的 C++ 深度学习资料，适合长期知识沉淀和面试回顾。".into(),
            local_url: Some("http://127.0.0.1:4001/".into()),
            github_url: Some("https://github.com/JMILI/cPlusBook".into()),
            tunnel_url: Some("https://sealtun-cplusbook-ui-ns-km83ebvo.sealosgzg.site/".into()),
            architecture_markdown: r#"```mermaid
flowchart TB
  CONTENT["Markdown 教程内容"] --> BUILD["mdbook build"]
  BUILD --> WEB["静态 HTTP 服务 :4001"]
  WEB --> TUNNEL["Sealtun 隧道"]
```"#
                .into(),
            business_markdown: r#"| 分类 | 说明 |
|---|---|
| 基础语法 | 类型、作用域、函数重载 |
| 进阶特性 | 继承、虚函数、模板、异常 |
| 现代 C++ | move 语义、智能指针、标准库 |
"#
            .into(),
            tags: vec!["C++".into(), "教程".into(), "文档工程".into()],
            technologies: vec![TechItem {
                name: "Markdown".into(),
                purpose: "组织知识章节并版本化维护".into(),
            }],
        },
        ProjectDetail {
            id: "offer".into(),
            title: "offer".into(),
            subtitle: "简历查看与导出".into(),
            summary: "Rust 启动器 + resume.html，快速预览与导出 PDF。".into(),
            local_url: Some("http://127.0.0.1:4000/".into()),
            github_url: Some("https://github.com/JMILI/offerPDF".into()),
            tunnel_url: Some("https://sealtun-offer-ui-ns-km83ebvo.sealosgzg.site/".into()),
            architecture_markdown: r#"```mermaid
flowchart LR
  HTML["resume.html / Axum"] --> SVC["简历服务 :4000"]
  SVC --> API["/api/resumes → MySQL"]
  SVC --> TUNNEL["Sealtun 隧道"]
```"#
                .into(),
            business_markdown: r#"| 功能 | 说明 |
|---|---|
| 预览简历 | 本地 :4000 或 Sealtun 隧道 |
| 导出 PDF | 浏览器打印为 A4 PDF |
| 版本持久化 | 保存/查看历史简历（MySQL） |
"#
            .into(),
            tags: vec!["Rust".into(), "Resume".into()],
            technologies: vec![TechItem {
                name: "open crate".into(),
                purpose: "调用系统默认浏览器打开简历文件".into(),
            }],
        },
        ProjectDetail {
            id: "fengsheng".into(),
            title: "风声".into(),
            subtitle: "村规版在线桌游 · 界面原型".into(),
            summary: "《风声》村规版玩家端 Vue 原型：当前仅支持 快速试玩 功能，支持人机对战。其余功能有待开发...".into(),
            local_url: Some("http://127.0.0.1:5173/".into()),
            github_url: None,
            tunnel_url: Some(
                "https://sealtun-fengsheng-vue-ns-km83ebvo.sealosgzg.site/".into(),
            ),
            architecture_markdown: r#"```mermaid
flowchart LR
  UI["Vue3 玩家端原型 :5173"] --> CORE["对局模块 / 裁决 / 同步"]
  CORE --> AI["人机替身与 CoT 提示"]
  UI --> TUNNEL["Sealtun 隧道"]
```"#
                .into(),
            business_markdown: r#"| 模块 | 说明 |
|---|---|
| 大厅与开房 | 创建房间、邀请链接、快速试玩 |
| 对局流程 | 开局→出牌→传递→争夺→结算的村规 FSM |
| 技能交互 | 角色技能、功能牌、识破链与有效位裁决 |
| 人机替身 | 本地 AI 替身参与对局，辅助联调与演示 |
"#
            .into(),
            tags: vec!["Vue3".into(), "桌游".into(), "原型".into()],
            technologies: vec![
                TechItem {
                    name: "Vue3 + Vite".into(),
                    purpose: "玩家端界面原型与交互演示".into(),
                },
                TechItem {
                    name: "Sealtun".into(),
                    purpose: "公网隧道试玩入口".into(),
                },
            ],
        },
        ProjectDetail {
            id: "rust-compile-web".into(),
            title: "rust-compile-web".into(),
            subtitle: "Rust 编译阶段可视化".into(),
            summary: "输入源码后可查看 AST/HIR/MIR/LLVM IR/汇编等编译阶段结果。".into(),
            local_url: Some("http://127.0.0.1:5175".into()),
            github_url: Some("https://github.com/JMILI/rust-compile-web".into()),
            tunnel_url: Some("https://sealtun-rust-compile-web-ui-ns-km83ebvo.sealosgzg.site/".into()),
            architecture_markdown: r#"```mermaid
flowchart LR
  UI["Vue3 前端 :5175"] --> API["Rust 后端 API"]
  API --> RUSTC["nightly rustc"]
  API --> RESULT["阶段输出聚合"]
```"#
                .into(),
            business_markdown: r#"| 阶段 | 用途 |
|---|---|
| AST/HIR/MIR | 理解编译器中间表示演进 |
| LLVM IR | 观察优化前后的 IR 形态 |
| Assembly | 对应最终机器层指令输出 |
"#
            .into(),
            tags: vec!["Rust".into(), "Compiler".into(), "Vue3".into()],
            technologies: vec![
                TechItem {
                    name: "Rust nightly".into(),
                    purpose: "导出更多编译阶段信息".into(),
                },
                TechItem {
                    name: "Vue3".into(),
                    purpose: "构建交互式阶段对比界面".into(),
                },
            ],
        },
    ]
}

async fn health() -> &'static str {
    "ok"
}

async fn hub_info() -> Json<HubInfo> {
    let port = std::env::var("PORT").unwrap_or_else(|_| "18200".to_string());
    Json(HubInfo {
        local_url: format!("http://127.0.0.1:{port}"),
        tunnel_setup_hint: "bash tunnel.sh apply && bash tunnel.sh status".into(),
    })
}

async fn list_projects() -> Json<Vec<ProjectCard>> {
    let cards = projects()
        .into_iter()
        .map(|p| ProjectCard {
            id: p.id,
            title: p.title,
            subtitle: p.subtitle,
            summary: p.summary,
            tags: p.tags,
            github_url: p.github_url,
            tunnel_url: p.tunnel_url,
        })
        .collect::<Vec<_>>();
    Json(cards)
}

async fn get_project(Path(id): Path<String>) -> impl IntoResponse {
    let found = projects().into_iter().find(|p| p.id == id);
    match found {
        Some(p) => (StatusCode::OK, Json(p)).into_response(),
        None => (
            StatusCode::NOT_FOUND,
            Json(serde_json::json!({ "error": "project not found" })),
        )
            .into_response(),
    }
}

async fn index() -> Html<&'static str> {
    Html(INDEX_HTML)
}

#[tokio::main]
async fn main() {
    let port = std::env::var("PORT").unwrap_or_else(|_| "18200".to_string());
    let addr = format!("0.0.0.0:{port}");

    let app = Router::new()
        .route("/", get(index))
        .route("/api/health", get(health))
        .route("/api/info", get(hub_info))
        .route("/api/projects", get(list_projects))
        .route("/api/projects/{id}", get(get_project));

    let listener = tokio::net::TcpListener::bind(&addr)
        .await
        .unwrap_or_else(|e| panic!("bind {addr} failed: {e}"));
    println!("Project Access running: http://127.0.0.1:{port}");
    axum::serve(listener, app).await.expect("server failed");
}

const INDEX_HTML: &str = r##"<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Project Access</title>
  <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
  <script type="module">
    import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
    window.__mermaid = mermaid;
  </script>
  <style>
    :root { --bg:#020817; --card:#0b1224; --line:#1e2a44; --text:#e2e8f0; --muted:#8ea1bd; --accent:#38bdf8; }
    * { box-sizing: border-box; }
    body { margin: 0; background: radial-gradient(circle at 15% 0%, #0b1d47 0%, var(--bg) 45%); color: var(--text); font-family: Inter, system-ui, sans-serif; }
    .wrap { max-width: 1200px; margin: 0 auto; padding: 28px 20px 40px; }
    .hero h1 { margin: 0; font-size: 42px; letter-spacing: .5px; text-shadow: 0 0 18px rgba(56,189,248,.25); }
    .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(290px, 1fr)); gap: 18px; margin-top: 20px; }
    .card { position: relative; background: linear-gradient(180deg, rgba(15,23,42,.95), rgba(8,15,30,.95)); border: 1px solid var(--line); border-radius: 16px; padding: 16px 16px 14px; cursor: pointer; transition: .18s ease; overflow: hidden; }
    .card:hover { transform: translateY(-3px); border-color: var(--accent); box-shadow: 0 14px 36px rgba(8,145,178,.22); }
    .card::after { content:''; position:absolute; right:-60px; top:-60px; width:130px; height:130px; border-radius:50%; background: radial-gradient(circle, rgba(56,189,248,.18), rgba(56,189,248,0)); }
    .card h3 { margin: 0 0 6px; font-size: 30px; font-weight: 700; }
    .muted { color: var(--muted); }
    .card p { margin: 10px 0 0; line-height: 1.55; min-height: 70px; }
    .tags { margin-top: 12px; display: flex; gap: 8px; flex-wrap: wrap; }
    .tag { border: 1px solid #2c3d5f; background: #111c34; border-radius: 999px; padding: 4px 10px; font-size: 12px; color: #c7d2fe; }
    .links { display: flex; gap: 10px; margin-top: 14px; position: relative; z-index: 1; }
    .links a { text-decoration: none; color: #081420; background: linear-gradient(120deg, #67e8f9, #22d3ee); font-size: 12px; padding: 6px 10px; border-radius: 999px; font-weight: 700; }
    .links .ghost { border: 1px dashed #35527a; color: #93c5fd; background: transparent; }
    .panel { background: #0a1328; border: 1px solid #22314e; border-radius: 16px; padding: 18px; margin-top: 18px; }
    .btn { background: #0ea5e9; color: #082f49; border: 0; border-radius: 10px; padding: 8px 14px; font-weight: 700; cursor: pointer; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #304564; padding: 8px; text-align: left; }
    th { background: #13213e; }
    code { color: #bae6fd; }
    @media (max-width: 640px) { .hero h1 { font-size: 34px; } }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="hero">
      <h1>Project Access</h1>
    </div>
    <div id="viewCards">
      <div id="cards" class="grid"></div>
    </div>
    <div id="viewDetail" style="display:none;">
      <button class="btn" onclick="goHome()">返回项目列表</button>
      <div id="detail" class="panel"></div>
    </div>
  </div>
<script>
  const state = { projects: [] };
  const cards = document.getElementById('cards');
  const detail = document.getElementById('detail');
  const viewCards = document.getElementById('viewCards');
  const viewDetail = document.getElementById('viewDetail');

  async function init() {
    const pRes = await fetch('/api/projects');
    state.projects = await pRes.json();
    renderCards();
    routeByHash();
    window.addEventListener('hashchange', routeByHash);
  }

  function renderCards() {
    cards.innerHTML = '';
    state.projects.forEach(p => {
      const node = document.createElement('article');
      node.className = 'card';
      node.innerHTML = `
        <h3>${p.title}</h3>
        <div class="muted">${p.subtitle}</div>
        <p>${p.summary}</p>
        <div class="tags">${p.tags.map(t => `<span class="tag">${t}</span>`).join('')}</div>
        <div class="links">
          ${p.github_url ? `<a href="${p.github_url}" target="_blank">GitHub</a>` : `<span class="ghost">GitHub 未配置</span>`}
          ${p.tunnel_url ? `<a href="${p.tunnel_url}" target="_blank">Tunnel</a>` : ''}
        </div>
      `;
      node.querySelectorAll('a').forEach(link => {
        link.addEventListener('click', e => e.stopPropagation());
      });
      node.addEventListener('click', () => { location.hash = `#/project/${p.id}`; });
      cards.appendChild(node);
    });
  }

  async function renderDetail(id) {
    const res = await fetch(`/api/projects/${id}`);
    if (!res.ok) {
      detail.innerHTML = '<h2>项目不存在</h2>';
      return;
    }
    const p = await res.json();
    const stackRows = p.technologies.map(t => `<tr><td>${t.name}</td><td>${t.purpose}</td></tr>`).join('');
    detail.innerHTML = `
      <h2>${p.title}</h2>
      <div class="muted">${p.subtitle}</div>
      <p>${p.summary}</p>
      <p>
        ${p.github_url ? `<a href="${p.github_url}" target="_blank">GitHub 仓库</a>` : 'GitHub 未配置'}
        ${p.tunnel_url ? ` | <a href="${p.tunnel_url}" target="_blank">隧道访问</a>` : ''}
        ${p.local_url ? ` | <a href="${p.local_url}" target="_blank">本地访问</a>` : ''}
      </p>
      <h3>技术栈及用途</h3>
      <table>
        <thead><tr><th>技术</th><th>用途</th></tr></thead>
        <tbody>${stackRows}</tbody>
      </table>
      <h3>架构说明</h3>
      <div id="archMd"></div>
      <h3>业务逻辑</h3>
      <div id="bizMd"></div>
    `;
    document.getElementById('archMd').innerHTML = marked.parse(p.architecture_markdown);
    document.getElementById('bizMd').innerHTML = marked.parse(p.business_markdown);
    try {
      if (window.__mermaid) {
        window.__mermaid.initialize({ startOnLoad: false, theme: 'dark' });
        await window.__mermaid.run({ nodes: detail.querySelectorAll('.language-mermaid') });
      }
    } catch (e) {
      console.error(e);
    }
  }

  async function routeByHash() {
    const m = location.hash.match(/^#\/project\/([^/]+)$/);
    if (!m) {
      viewCards.style.display = '';
      viewDetail.style.display = 'none';
      return;
    }
    viewCards.style.display = 'none';
    viewDetail.style.display = '';
    await renderDetail(m[1]);
  }
  function goHome() { location.hash = ''; }
  window.goHome = goHome;
  init().catch(err => { cards.innerHTML = `<div class="panel">加载失败: ${err.message}</div>`; });
</script>
</body>
</html>"##;
