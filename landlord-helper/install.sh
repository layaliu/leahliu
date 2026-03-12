#!/bin/bash

# 房东助手技能包安装脚本

echo "🦞 开始安装房东助手技能包..."

# 0. 检查 OpenClaw 是否已安装
if ! command -v openclaw >/dev/null 2>&1; then
  echo "⚠️ 未检测到 openclaw，请先安装：curl -fsSL https://openclaw.ai/install.sh | bash"
fi

# 1. 创建技能目录
SKILL_DIR="$HOME/.openclaw/skills/landlord-helper"
mkdir -p "$SKILL_DIR"
echo "✅ 创建技能目录: $SKILL_DIR"

# 2. 创建证据目录
EVIDENCE_DIR="$HOME/landlord-helper/evidence"
mkdir -p "$EVIDENCE_DIR"
echo "✅ 创建证据目录: $EVIDENCE_DIR"
mkdir -p "/archive/tenants"
mkdir -p "/backup/evidence"
echo "✅ 创建证据归档与备份目录"
mkdir -p "/tmp/contract_scan"
mkdir -p "$HOME/landlord-helper/evidence/contracts"
echo "✅ 创建合同扫描临时目录与加密归档目录"
mkdir -p "$HOME/landlord-helper/agents/landlord-core"
mkdir -p "$HOME/landlord-helper/agents/rent-collector"
mkdir -p "$HOME/landlord-helper/agents/care-agent"
echo "✅ 创建多Agent工作目录"


# 2.1 安装合同OCR依赖（Debian/Ubuntu）
if command -v apt >/dev/null 2>&1; then
  sudo apt update
  sudo apt install -y tesseract-ocr tesseract-ocr-chi-sim poppler-utils
fi
if command -v pip3 >/dev/null 2>&1; then
  pip3 install opencv-python pillow pytesseract pdf2image
fi

# 3. 复制文件（假设脚本和文件在同一目录）
cp SKILL.md "$SKILL_DIR/"
cp config.json "$SKILL_DIR/"
cp tenants.csv "$SKILL_DIR/"
cp preprocess_image.py "$SKILL_DIR/"
chmod +x "$SKILL_DIR/preprocess_image.py"
echo "✅ 复制技能文件"

# 4. 生成加密密钥（如果不存在）
ENCRYPTION_KEY=$(openssl rand -base64 32)
echo "export ENCRYPTION_KEY='$ENCRYPTION_KEY'" >> "$HOME/.bashrc"
echo "✅ 生成加密密钥（已保存到.bashrc）"

# 4.1 多平台凭证占位（按需配置）
if ! grep -q "WHATSAPP_ACCESS_TOKEN" "$HOME/.bashrc"; then
  echo "export WHATSAPP_ACCESS_TOKEN='your-whatsapp-token'" >> "$HOME/.bashrc"
fi
if ! grep -q "INSTAGRAM_ACCESS_TOKEN" "$HOME/.bashrc"; then
  echo "export INSTAGRAM_ACCESS_TOKEN='your-instagram-token'" >> "$HOME/.bashrc"
fi
if ! grep -q "DISCORD_BOT_TOKEN" "$HOME/.bashrc"; then
  echo "export DISCORD_BOT_TOKEN='your-discord-bot-token'" >> "$HOME/.bashrc"
fi
echo "✅ 已写入 WhatsApp/Instagram/Discord 环境变量模板（请改为真实值）"

# 5. 提示配置OpenClaw
echo ""
echo "⚠️  请手动在 ~/.openclaw/openclaw.json 中添加以下配置："
echo ""
cat << EOF2
{
  "agents": {
    "landlord-helper": {
      "sandbox": {
        "mode": "restricted",
        "allowed_paths": ["$HOME/landlord-helper/", "/tmp/"],
        "allowed_commands": []
      }
    }
  },
  "skills": {
    "entries": {
      "landlord-helper": {
        "enabled": true,
        "env": {
          "ENCRYPTION_KEY": "$ENCRYPTION_KEY"
        }
      }
    }
  }
}
EOF2

echo ""
echo "6. 重启OpenClaw服务："
echo "   systemctl restart openclaw"
echo ""
echo "🎉 安装完成！房东侧与租户侧均可通过钉钉/飞书/QQ/Telegram/WhatsApp/Instagram/Discord 使用助手。"


# 7. 可选：设置内存告警阈值
if command -v openclaw >/dev/null 2>&1; then
  openclaw config set monitoring.memory_threshold 80 || true
  echo "✅ 已尝试设置内存告警阈值为80%"
fi


# 8. 可选：管理端口安全加固（仅内网 + Tailscale）
if [ "${ENABLE_NETWORK_HARDENING:-false}" = "true" ]; then
  if command -v ufw >/dev/null 2>&1; then
    sudo ufw allow from 10.0.0.0/8 to any port 18789 || true
    sudo ufw deny 18789 || true
    echo "✅ 已尝试配置 UFW：仅允许 10.0.0.0/8 访问 18789，并拒绝其他来源"
  else
    echo "⚠️ 未检测到 ufw，请手动执行端口访问限制命令"
  fi

  if command -v openclaw >/dev/null 2>&1; then
    openclaw gateway --tailscale serve || true
    echo "✅ 已尝试启用 Tailscale 安全隧道"
  fi
else
  echo "ℹ️ 如需启用管理端口加固，请执行：ENABLE_NETWORK_HARDENING=true ./install.sh"
  echo "   sudo ufw allow from 10.0.0.0/8 to any port 18789"
  echo "   sudo ufw deny 18789"
  echo "   openclaw gateway --tailscale serve"
fi


echo ""
echo "ℹ️ 建议在 ~/.openclaw/openclaw.json 增加 logging.rotation（100MB/30天/10备份/压缩）"


# 9. 可选：官方 Token 优化基线
if [ "${ENABLE_TOKEN_OPTIMIZATION:-false}" = "true" ]; then
  if command -v openclaw >/dev/null 2>&1; then
    openclaw config set memory.max_tokens 2000 || true
    openclaw config set context.compression.enabled true || true
    openclaw config set context.compression.mode "lossless" || true
    openclaw config set vision.enabled false || true
    openclaw config set filesystem.allowed_paths '["/home/admin/landlord-helper/"]' || true
    openclaw gateway restart || true
    echo "✅ 已尝试应用官方 Token 优化基线配置"
  else
    echo "⚠️ 未检测到 openclaw，请手动执行 token 优化命令"
  fi
else
  echo "ℹ️ 如需启用 token 优化，请执行：ENABLE_TOKEN_OPTIMIZATION=true ./install.sh"
fi

