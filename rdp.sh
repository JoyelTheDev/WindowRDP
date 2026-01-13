#!/bin/bash
# ============================================
# 🚀 Auto Installer: Windows 11 on Docker + Cloudflare Tunnel
# ============================================

set -e

echo "=== 🔧 Menjalankan sebagai root ==="
if [ "$EUID" -ne 0 ]; then
  echo "This script requires root access. Run with: sudo bash install-windows11-cloudflare.sh"
  exit 1
fi

echo
echo "=== 📦 Update & Install Docker Compose ==="
apt update -y
apt install docker-compose -y

systemctl enable docker
systemctl start docker

echo
echo "=== 📂 Creating a dockercom working directory ==="
mkdir -p /root/dockercom
cd /root/dockercom

echo
echo "=== 🧾 Make file windows.yml ==="
cat > windows.yml <<'EOF'
version: "3.9"
services:
  windows:
    image: dockurr/windows
    container_name: windows
    environment:
      VERSION: "11"
      USERNAME: "MASTER"
      PASSWORD: "admin@123"
      RAM_SIZE: "7G"
      CPU_CORES: "4"
    devices:
      - /dev/kvm
      - /dev/net/tun
    cap_add:
      - NET_ADMIN
    ports:
      - "8006:8006"
      - "3389:3389/tcp"
      - "3389:3389/udp"
    volumes:
      - /tmp/windows-storage:/storage
    restart: always
    stop_grace_period: 2m

EOF

echo
echo "=== ✅ Windows.yml file created successfully ==="
cat windows.yml

echo
echo "=== 🚀 Running Windows 11 containers ==="
docker-compose -f windows.yml up -d

echo
echo "=== ☁️ Cloudflare Tunnel Installation ==="
if [ ! -f "/usr/local/bin/cloudflared" ]; then
  wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared
  chmod +x /usr/local/bin/cloudflared
fi

echo
echo "=== 🌍 Create a public tunnel for web & RDP access ==="
nohup cloudflared tunnel --url http://localhost:8006 > /var/log/cloudflared_web.log 2>&1 &
nohup cloudflared tunnel --url tcp://localhost:3389 > /var/log/cloudflared_rdp.log 2>&1 &
sleep 6

CF_WEB=$(grep -o "https://[a-zA-Z0-9.-]*\.trycloudflare\.com" /var/log/cloudflared_web.log | head -n 1)
CF_RDP=$(grep -o "tcp://[a-zA-Z0-9.-]*\.trycloudflare\.com:[0-9]*" /var/log/cloudflared_rdp.log | head -n 1)

echo
echo "=============================================="
echo "🎉 Installation Complete!"
echo
if [ -n "$CF_WEB" ]; then
  echo "🌍 Web Console (NoVNC / UI):"
  echo "    ${CF_WEB}"
else
  echo "⚠️ Could not find Cloudflare web link (port 8006)"
  echo "    Check log: tail -f /var/log/cloudflared_web.log"
fi

if [ -n "$CF_RDP" ]; then
  echo
  echo "🖥️  Remote Desktop (RDP) through Cloudflare:"
  echo "    ${CF_RDP}"
else
  echo "⚠️ Could not find Cloudflare RDP link (port 3389)"
  echo "    Check log: tail -f /var/log/cloudflared_rdp.log"
fi

echo
echo "🔑 Username: MASTER"
echo "🔒 Password: admin@123"
echo
echo "To see the status of the container:"
echo "  docker ps"
echo
echo "To stop the VM:"
echo "  docker stop windows"
echo
echo "To view the Windows log:"
echo "  docker logs -f windows"
echo
echo "To view the Cloudflare link:"
echo "  grep 'trycloudflare' /var/log/cloudflared_*.log"
echo
echo "=== ✅ Windows 11 on Docker is ready to go! ==="
echo "=============================================="
