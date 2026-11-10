# MotionPro 透明代理

本项目用于将 MotionPro VPN 包装在容器中并提供一个 socks 代理端口以供访问。

使用的 MotionPro 版本为 `Ubuntu_x64_v1.2.18` 。

在 [Dockerfile#23](Dockerfile#23) 中重写了 `pidof` 以解决使用 QEMU 模拟 arm64 平台时 MotionPro 找不到 vpnd 报错的问题。

已在 macOS 15.x (arm64) 上验证。

## 使用

```shell
export BIND_HOST="127.0.0.1"
export HOST_PORT="23333"
export MOTIONPRO_HOST="YOUR_VPN_HOST"
export MOTIONPRO_USER="YOUR_VPN_USERNAME"
export MOTIONPRO_PASSWORD='YOUR_VPN_PASSWORD'

docker run -d \
  --name vpngate \
  --platform linux/amd64 \
  --device /dev/net/tun \
  --cap-add NET_ADMIN \
  -p "${BIND_HOST}:${HOST_PORT}:1080" \
  -e MOTIONPRO_HOST \
  -e MOTIONPRO_USER \
  -e MOTIONPRO_PASSWORD \
  --restart unless-stopped \
  motionpro-vpn
```
