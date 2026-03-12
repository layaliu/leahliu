# 🏠 房东助手 3.10 - 使用说明书

## 核心理念
- 房东 = 审核者 / 决策者
- AI = 执行者 / 汇报者 / 工单客服 / 续租协调员

## 每日两报机制
- **早上9点**：AI私聊催租 + 到期租约检查
- **晚上9点**：AI私聊房东汇总催租 + 工单 + 续租待办

## 新增：租约到期管理与续租谈判

当租约到期前30天，AI会自动提醒房东。

房东可直接回复：
- `续租 张三 3800`
- `不续租 张三`

若租户讨价还价，AI会请示房东：
- `同意降价至3700`
- `维持原价`
- `不续租`

租户接受后，AI会通知房东确认并更新新租期。

## 续租证据存档
- 续租沟通日志：`evidence/renewals.json`
- 工单日志：`evidence/repairs/repairs.json`

## 安装
```bash
cd ~/.openclaw/skills/landlord-helper
chmod +x install.sh
./install.sh
systemctl restart openclaw
```


## 新增：统计分析报告（季度/年度）

系统支持自动生成季度与年度经营分析报告（收租、退租、价格、租户风险、维修、续租、市场对比）。

支持指令：
- `生成上季度报告`
- `生成2026年年度报告`
- `把2026年Q1报告再发我一次`
- `导出所有数据报表`

报告归档目录：
- `evidence/reports/quarterly/`
- `evidence/reports/annual/`
- `evidence/reports/archive/`


## 新增：租金单价分析（面积字段）

新增字段：`area`、`area_unit`，用于动态计算单价（元/㎡或换算后单位）。

录入示例：
- 租金：3500
- 房屋面积：45
- 面积单位：平方米

报告中新增：
- 平均单价
- 最高/最低单价
- 与周边均价对比

若租户缺失面积数据，报告会标记“无面积数据”。


## 新增：合同扫描自动录入（本地OCR）

支持房东发送“扫描合同”后上传图片/PDF，系统将使用本地 Tesseract OCR 自动提取字段并请房东确认后写入租户数据。

处理流程：
- PDF转图片（`pdftoppm`）
- 图像预处理（`preprocess_image.py`）
- OCR识别（`tesseract`）
- 字段结构化与人工确认
- 合同加密归档到 `evidence/contracts/`

特点：零云依赖、数据本地化、可追溯。


## 新增：MBTI智能沟通（T/F + I/E）

系统支持按租户性格偏好自动调整催租与谈判话术：
- `T` 思考型：偏数据与条款
- `F` 情感型：偏共情与关系
- `I` 内向型：私聊、低频、给思考时间
- `E` 外向型：即时互动、快速反馈

房东可手动设置：
- `修改 张三 性格 T I`

系统也可自动建议：
- `为张三建议性格`


## 新增：多Agent路由架构

系统内置三个Agent，按意图分流：
- `landlord-core`：核心管理与决策
- `rent-collector`：仅催租
- `care-agent`：仅关怀

路由规则：
- 催租 -> `rent-collector`
- 关怀 -> `care-agent`
- 其他 -> `landlord-core`

这样可实现更强隔离：催租Agent不会触发续租决策或报表导出。


## 运维监控（资源与内存告警）

查看资源：
```bash
htop
```

设置内存告警阈值（>80%通知）：
```bash
openclaw config set monitoring.memory_threshold 80
```


## 管理端口安全（仅内网 + Tailscale）

建议限制 OpenClaw 管理端口（`18789`）仅允许内网访问，并通过 Tailscale 暴露安全隧道：

```bash
sudo ufw allow from 10.0.0.0/8 to any port 18789
sudo ufw deny 18789
openclaw gateway --tailscale serve
```

说明：
- 第一条规则允许内网网段访问管理端口。
- 第二条规则拒绝其他来源访问管理端口。
- 第三条命令使用 Tailscale 网关提供安全访问路径（推荐）。


## 日志轮转与证据归档（推荐）

### 1) OpenClaw 系统日志轮转（写入 `~/.openclaw/openclaw.json`）

```json
{
  "logging": {
    "level": "info",
    "encoding": "json",
    "output_paths": ["stdout", "/var/log/openclaw/openclaw.log"],
    "rotation": {
      "max_size_mb": 100,
      "max_age_days": 30,
      "max_backups": 10,
      "compress": true
    }
  }
}
```

应用配置：
```bash
systemctl restart openclaw
```

### 2) 业务证据归档（永久留存 + 退租归档）

- 运行证据：`~/landlord-helper/evidence/`
- 归档目录：`/archive/tenants/`
- 备份目录：`/backup/evidence/`

支持动作：
- `归档 张三`（手动归档单租户证据）
- 定时任务 `auto_archive_departed_tenants`（默认每天 03:00）

策略建议：
- 系统日志可轮转与清理；
- 业务证据默认不删除，退租后迁移归档；
- 磁盘 >80% 时结合监控告警处理。


## Token 优化组合（Viking + QMD + 官方裁剪）

推荐按以下顺序落地，先做官方安全配置，再逐步引入增强组件。

### 1) 官方基础配置（低成本、快速见效）

```bash
openclaw config set memory.max_tokens 2000
openclaw config set context.compression.enabled true
openclaw config set context.compression.mode "lossless"
openclaw config set vision.enabled false
openclaw config set filesystem.allowed_paths '["/home/admin/landlord-helper/"]'
openclaw gateway restart
```

### 2) Viking 路由过滤（按意图加载工具/记忆）

```bash
git clone https://github.com/adoresever/AGI_Ananans.git
cd AGI_Ananans/26.2.21openclaw-viking
pnpm install
pnpm build
cp -r config/* ~/.openclaw/
openclaw gateway restart
```

验证示例：
```bash
grep "token_usage" ~/.openclaw/logs/requests.log
```

### 3) QMD 记忆压缩（向量召回替代全量上下文）

```bash
pip install qdrant-client sentence-transformers
mkdir -p ~/.openclaw/skills/qmd
```

并在 `config.yaml` 设置：
```yaml
memory:
  provider: "qmd"
  qmd_path: "/home/admin/.openclaw/skills/qmd/qmd.py"
  max_context_chunks: 5
```

### 4) 多 Agent 隔离（可选）

将催租、关怀、合同等能力拆分到独立 Agent，并在 `router.yaml` 按意图分流，可进一步降低上下文膨胀。
