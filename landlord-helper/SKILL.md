---
name: landlord-helper
description: 房东助手3.10 - 多Agent路由 + 催租续租工单报表合同OCR + 资源监控告警 + 管理端口安全
version: 3.10.0
author: YourName
user-invocable: true
metadata:
  {
    "openclaw": {
      "requires": {
        "bins": [],
        "env": ["ENCRYPTION_KEY"]
      },
      "emoji": "🏠"
    }
  }
---

# 🏠 房东助手 3.10 技能说明

## 一、角色定位
- 房东：审核者 / 决策者
- AI：执行者 / 汇报者 / 工单客服 / 续租协调员

## 二、核心节奏（每日两报）
- 09:00 私密催租（仅未交租户）
- 21:00 私聊房东发送《今日催租+工单+续租总结》

## 三、租户数据模型（tenants.csv）
- 催租：`status`、`overdue_days`、`last_reminded`
- 谈判：`negotiation_status`、`pending_request`
- 关怀：`city`、`birthday`、`nearby_*`
- 续租：`start_date`、`end_date`、`renew_status`、`renew_rent_offered`、`renew_notes`
- 面积：`area`、`area_unit`（用于动态计算租金单价）

## 四、催租/谈判/关怀
- 所有消息仅私聊，不拉群。
- 让步必须先经房东审核。
- 添加租客时采集：`房屋面积（可选）`、`面积单位（可选，默认平方米）`。
- 关怀动作：`send_weather_forecast`、`send_weekly_tips`、`check_holidays_and_birthdays`。

## 五、服务工单系统
- 服务意图命中 `service.categories` -> `create_service_ticket`
- 工单落盘：`evidence/repairs/repairs.json`
- 房东处理命令：`处理/解决/关闭 R...`
- 催办任务：`check_pending_tickets`（10:00）

## 六、租约到期管理与续租谈判
### 6.1 action: check_expiring_leases
- 每日检查 `end_date - today`
- 若小于等于 `renewal.advance_days` 且 `renew_status` 为空或 `pending`：
  - 向房东发送续租提醒（`renewal.remind_landlord_template`）
  - 设置 `renew_status=pending`
  - 记录到 `evidence/renewals.json`

### 6.2 on_message（房东）
- `续租 姓名 新租金`：更新 `renew_status=renewing`、`renew_rent_offered`，并向租户发邀约
- `不续租 姓名`：更新 `renew_status=not_renewing`，提醒房东到期收回

### 6.3 on_message（租户）续租处理
- 当 `renew_status=renewing`：
  - 接受：`renew_status=renewed`，通知房东确认新租约
  - 拒绝/讨价：向房东请示后继续沟通

### 6.4 续租成功处理
- 更新 `end_date`（默认顺延1年）
- 清空 `renew_rent_offered`
- 记录并通知房东

### 6.5 面积与单价计算
```python
def get_unit_price(rent, area):
    if area and area > 0:
        return round(rent / area, 2)
    return None
```
- 若 `area_unit` 非默认单位，先按 `config.area.unit_to_sqm` 换算。
- 无面积数据时返回“无面积数据”。

## 七、统计分析报告（新增）
### 7.1 报告维度
- 收租、退租、价格、租户风险、维修、续租、市场行情

### 7.2 action: generate_quarterly_report
- 参数：`year`, `quarter`
- 数据源：`tenants.csv`、`evidence/repairs/repairs.json`、`evidence/renewals.json`、`evidence/payments/`
- 输出：`evidence/reports/quarterly/YYYY-QX/report.md` + `charts/*.png`

### 7.3 action: generate_annual_report
- 参数：`year`
- 汇总全年趋势与同比
- 输出：`evidence/reports/annual/YYYY/`

### 7.4 action: resend_report / export_all_reports
- `resend_report`：归档重发
- `export_all_reports`：打包 `evidence/reports/` 为zip

### 7.5 报告单价分析
- 输出平均单价、最高/最低单价、与市场均价对比
- 按 `config.area.default_unit` 统一单位

### 7.6 手动触发
- `生成上季度报告`
- `生成2026年年度报告`
- `把2026年Q1报告再发我一次`
- `导出所有数据报表`

## 八、定时任务
- `08:00`：`send_weather_forecast`
- `09:00`：`send_rent_reminders`
- `09:00`：`check_holidays_and_birthdays`
- `09:00`：`check_expiring_leases`
- `09:00`（周一）：`send_weekly_tips`
- `10:00`：`check_pending_tickets`
- `21:00`：`generate_daily_report`
- `09:00`（周一）：`generate_weekly_summary`
- `0 9 1 1,4,7,10 *`：`generate_quarterly_report`
- `0 10 1 1 *`：`generate_annual_report`

## 九、证据与安全
- 工单：`evidence/repairs/repairs.json`
- 续租：`evidence/renewals.json`
- 报告：`evidence/reports/`
- 长期备份，不自动删除







## 十、多Agent架构与路由（新增）

### 10.1 Agent职责
- `landlord-core`：租客管理、续租谈判、工单总控、统计分析
- `rent-collector`：仅催租相关动作（提醒、逾期跟进）
- `care-agent`：仅关怀相关动作（欢迎、天气、生日、节日）

### 10.2 路由规则
- 命中“催租”意图 -> `rent-collector`
- 命中“关怀”意图 -> `care-agent`
- 其他默认 -> `landlord-core`

### 10.3 安全边界
- 三个Agent均使用 `restricted` 沙箱
- 非 `landlord-core` Agent 不得执行续租决策、工单关闭、报表导出等高权限动作
- 决策型动作统一回传 `landlord-core` 审核

## 十一、MBTI轻量人格适配（新增）

### 11.1 字段定义
在 `tenants.csv` 中使用：
- `personality_tf`：`T`（思考型） / `F`（情感型）
- `personality_ie`：`I`（内向型） / `E`（外向型）

### 11.2 on_load_tenant_profile
- 每次沟通前读取 `personality_tf` 与 `personality_ie`
- 若为空则回退 `config.personality.default_tf/default_ie`

### 11.3 action: send_reminder（人格适配）
- 先按 `personality_tf` 选择 `personality.templates.reminder`
- 再按 `personality_ie` 选择 `personality.templates.follow_up`
- `I`：优先私聊、降低频次；`E`：可更即时互动

### 11.4 action: handle_negotiation（人格适配）
- `T`：强调市场数据、合同条款、可选项
- `F`：先共情，再说明房东边界
- `I`：分步沟通，给思考时间
- `E`：节奏更快，支持即时选择
- 若命中组合模板（T+I/T+E/F+I/F+E），优先使用 `personality.templates.combo`

### 11.5 action: suggest_personality（可选）
- 扫描租户最近N条消息
- 倾向判断：
  - 逻辑词多 -> 建议 `T`
  - 情感词多 -> 建议 `F`
  - 回复简短且间隔长 -> 建议 `I`
  - 回复快且互动强 -> 建议 `E`
- 向房东发确认：`建议将张三设为 T/I，是否确认？`

### 11.6 房东指令
- `修改 张三 性格 T I`
- `查看 张三 性格`
- `为李四建议性格`

## 十二、合同扫描自动录入（Tesseract 免费版）

### 11.1 action: scan_contract
触发词：`扫描合同`、`上传合同`（仅房东可用）

流程：
1. 要求房东上传合同图片/PDF（jpg/png/pdf）
2. 文件保存到 `contract_scan.temp_dir`
3. 若为PDF，执行：
```bash
pdftoppm {pdf_path} {output_prefix} -png -f 1 -l 1
```
4. 若启用预处理，调用：
```bash
python preprocess_image.py input.png output.png
```
5. OCR识别：
```bash
tesseract {processed_image} stdout -l chi_sim --psm 6
```
6. LLM将OCR文本解析为结构化JSON（姓名/手机号/身份证/地址/起止日期/租金/押金/付款周期/面积）
7. 展示给房东核对，支持“确认”或逐项修正（如“租金改成3600”）
8. 确认后写入 `tenants.csv`
9. 原始合同加密归档到 `contract_scan.contracts_dir`
10. 清理临时文件并返回成功消息

### 11.2 提示与安全
- 引导拍摄：文字清晰、光线充足、页面平整
- 合同不上传云端，全部本地处理
- 临时文件处理后删除，归档文件加密存储

## 十三、版本历史
- v3.10.0 (2026-03-12): 新增 token 优化组合策略（官方裁剪 + Viking 路由 + QMD 记忆压缩）
- v3.9.0 (2026-03-12): 新增日志轮转建议与租户证据归档/自动归档流程
- v3.8.0 (2026-03-12): 新增管理端口访问限制（仅内网）与 Tailscale 安全隧道建议
- v3.7.0 (2026-03-12): 新增资源监控与内存阈值告警（默认80%）
- v3.6.0 (2026-03-12): 新增多Agent架构与意图路由（landlord-core / rent-collector / care-agent）
- v3.5.0 (2026-03-12): 新增MBTI轻量人格适配（T/F + I/E）用于催租与谈判策略
- v3.2.0 (2026-03-12): 新增合同扫描自动录入（Tesseract OCR + PDF转图 + 预处理 + 本地加密归档）
- v3.1.0 (2026-03-12): 新增面积字段与租金单价计算（报告单价分析、单位换算、缺失兼容）
- v3.0.0 (2026-03-12): 新增季度/年度统计分析报告（图表、归档、重发、导出）
- v2.7.0 (2026-03-12): 新增租约到期管理与续租谈判
- v2.6.0 (2026-03-12): 新增服务工单系统


## 十四、资源监控与告警（新增）

### 14.1 查看资源使用
- 推荐命令：`htop`
- 若无交互终端可改用：`top -bn1` / `free -h` / `df -h`

### 14.2 内存阈值告警
- 在 `config.json.monitoring.memory_threshold` 设置阈值（默认80）
- 超过阈值时，AI向房东通知并附带当前内存/CPU/磁盘摘要

### 14.3 运维命令
```bash
openclaw config set monitoring.memory_threshold 80
```


## 十五、管理端口安全与Tailscale（新增）

### 15.1 仅内网访问管理端口
- 默认管理端口：`18789`
- 建议仅允许内网 `10.0.0.0/8` 访问，并拒绝其他来源。

### 15.2 推荐命令
```bash
sudo ufw allow from 10.0.0.0/8 to any port 18789
sudo ufw deny 18789
openclaw gateway --tailscale serve
```

### 15.3 运维策略
- 先放行内网，再拒绝全网访问管理端口。
- 外部运维统一通过 Tailscale 隧道进入，避免公网暴露。
- 将以上策略与 `config.json.network_security` 保持一致。


## 十六、日志轮转与证据归档（新增）

### 16.1 OpenClaw 系统日志轮转
- 在 `~/.openclaw/openclaw.json` 设置 `logging.rotation`：
  - `max_size_mb=100`
  - `max_age_days=30`
  - `max_backups=10`
  - `compress=true`
- 修改后执行：`systemctl restart openclaw`

### 16.2 action: archive_tenant
- 触发词：`归档 {姓名}`（仅房东）
- 流程：
  1. 按姓名查找租户并确认租约结束/强制归档
  2. 打包 `evidence/{tenant_id}/` 为 `姓名_退租_YYYYMMDD.tar.gz`
  3. 可选加密后移动至 `config.evidence.archive_dir`
  4. 按策略删除原目录（默认删除）
  5. 更新 `tenants.csv`：`archive_status=archived`、`archive_path=...`

### 16.3 action: auto_archive_departed_tenants
- 定时任务：`0 3 * * *`
- 处理规则：
  - 找到 `end_date < today - days_after_end` 且 `archive_status != archived` 的租户
  - 逐个调用 `archive_tenant`
  - 记录归档结果到证据日志

### 16.4 证据与备份策略
- 业务证据永久保留为主，退租后迁移到归档目录。
- 备份由 `config.evidence.backup` 控制（默认周日 02:00）。
- 监控磁盘阈值（如80%）触发告警。


## 十七、Token 优化组合（新增）

### 17.1 官方基础裁剪
- 建议参数：
  - `memory.max_tokens = 2000`
  - `context.compression.enabled = true`
  - `context.compression.mode = lossless`
  - `vision.enabled = false`
  - `filesystem.allowed_paths = ["/home/admin/landlord-helper/"]`
- 生效命令：`openclaw gateway restart`

### 17.2 Viking 路由过滤
- 在主模型调用前使用轻量路由判断意图，仅加载必要工具和记忆。
- 推荐仓库：`https://github.com/adoresever/AGI_Ananans.git`（子目录 `26.2.21openclaw-viking`）

### 17.3 QMD 记忆压缩
- 使用向量检索替代全量历史注入。
- 推荐配置：
  - `memory.provider = qmd`
  - `memory.max_context_chunks = 5`

### 17.4 多 Agent 隔离
- 将催租、关怀、合同等任务路由到独立 Agent，降低单 Agent 上下文增长。
- 与现有 `multi_agent.router.rules` 配合使用。
