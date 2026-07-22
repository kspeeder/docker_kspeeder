# Docker KSpeeder

Docker KSpeeder 将 `linkease/kspeeder` 打包进轻量 Alpine 容器，方便在 Docker Compose 或纯 Docker 运行模式下部署加速/监控能力。它内置多架构构建支持、配置模板，并在容器启动时自动生成 `nodes.yaml`，让 Docker 镜像加速、domainfold 处理、代理节点等功能即刻可用。

## KSpeeder 核心特性
- 最核心是带宽叠加，把 socks5/http 以及各种 mirrors 进行带宽叠加
- 支持 Cloudflare 优选 IP 加速
- 支持日常开发需要的 Docker, Github, Golang, nodejs, python, java 加速等等
- 节点缓存 & 测量：accelnodemgr 会持续刷新节点 inventory、测速结果与 CFIP 信息，减少冷启动时的网络抖动；`KS_USER_NODES_CONFIG` 支持 `docker`、`domainfold`、`proxies` 统一配置源节点。
- 多架构 & CI 支持：提供 `buildx` 脚本 (`howto.md`) 以及 `nodes.sample.yaml` 模板，帮助你构建从 x86_64 到 ARM64 的镜像，并内置了 entrypoint 监控/重启逻辑。

### 通用节点叠加加速支持：
![通用节点叠加加速支持](https://www.koolcenter.com/uploads/default/original/3X/6/0/605267351beb7adef6f78c1476cdc6f4302df887.png)

### Docker CF 优选支持
![Docker CF 优选支持](https://www.koolcenter.com/uploads/default/original/3X/c/f/cf41c699399d925922cbbabaec2087018b5aa01f.png)

### GITHUB 克隆或者下载支持
![GITHUB 克隆或者下载支持](https://www.koolcenter.com/uploads/default/original/3X/7/e/7e823c357a9f6b61a939b766c9f239eb04fe740c.png)

<!-- keep quick start section unchanged after features? -->

## 快速上手

## 镜像版本选择

kspeeder 镜像支持多种标签（tag），可按稳定性/新特性需求选择：

1. 最新稳定版：`linkease/kspeeder:latest`
2. 最新公测版：`linkease/kspeeder:beta`
3. 指定版本：`linkease/kspeeder:0.7.1`（示例）

### 1. 快速部署（推荐）
```yaml
services:
  kspeeder:
    image: linkease/kspeeder:latest
    container_name: kspeeder
    ports:
      - "5443:5443"
      - "5003:5003"
    volumes:
      - ./kspeeder-data:/kspeeder-data
      - ./kspeeder-config:/kspeeder-config
    restart: unless-stopped
```
```bash
docker-compose up -d
```
初始化时容器会在 `./kspeeder-config/nodes.yaml` 生成示例（来自 `/usr/share/kspeeder/nodes.yaml.sample`），编辑或替换当前文件即可让节点/镜像源生效。

### 2. 单容器调试
```bash
docker run -d \
  --name kspeeder \
  -p 5443:5443 -p 5003:5003 \
  -v "$(pwd)/kspeeder-data:/kspeeder-data" \
  -v "$(pwd)/kspeeder-config:/kspeeder-config" \
  --restart unless-stopped \
  linkease/kspeeder:latest
```
更多环境变量（`KSPEEDER_PORT` / `KSPEEDER_ADMIN_PORT` / `KSPEEDER_DATA` / `KS_USER_NODES_CONFIG`）可以在 Compose 或 `docker run` 时追加。

## 端口受限场景：Docker CONNECT 代理模式（5443 写不进 / 443 被占用）

适用场景：

- NAS / 群晖 Docker UI 不能填写 `:5443`（只能填 `https://...` 默认走 443），导致镜像源“写不进/不生效”
- 宿主机 `:443` 已被其它服务占用，无法让 kspeeder 监听 `:443`

解决思路：

- Docker 的 `registry-mirrors` 目标保持写成 `https://registry.linkease.net`（不带端口，等价 `:443`）
- 同时把 Docker daemon 的 `HTTP_PROXY/HTTPS_PROXY` 指向 kspeeder 管理端口（默认 `:5003`，支持 CONNECT 隧道）
- kspeeder 会将 `registry.linkease.net:443` 的 CONNECT 自动转接到本机 kspeeder TLS 端口（默认 `:5443`），从而不依赖宿主机 `:443`，也不要求 UI 支持填写 `:5443`

### 1) docker-compose 部署（只暴露 5003）

```yaml
services:
  kspeeder:
    image: linkease/kspeeder:latest
    container_name: kspeeder
    ports:
      - "5003:5003" # Docker HTTP/HTTPS Proxy 指向这里
    volumes:
      - ./kspeeder-data:/kspeeder-data
      - ./kspeeder-config:/kspeeder-config
    restart: unless-stopped
    environment:
      - TZ=Asia/Shanghai
      - KSPEEDER_PORT=5443
      - KSPEEDER_ADMIN_PORT=5003
      - KSPEEDER_CONFIG=/kspeeder-config
      - KSPEEDER_DATA=/kspeeder-data
      - KS_USER_NODES_CONFIG=/kspeeder-config/nodes.yaml
      # 为空会禁用 CONNECT 代理；建议务必设置
      - KSPEEDER_PROXY_AUTH=user:pass
```

### 2) docker run 部署（只暴露 5003）

```bash
docker run -d \
  --name kspeeder \
  -p 5003:5003 \
  -e TZ=Asia/Shanghai \
  -e KSPEEDER_PROXY_AUTH="user:pass" \
  -v "$(pwd)/kspeeder-data:/kspeeder-data" \
  -v "$(pwd)/kspeeder-config:/kspeeder-config" \
  --restart unless-stopped \
  linkease/kspeeder:latest
```

### 3) Docker daemon 设置（mirror + proxy）

1) `registry-mirrors`（目标直接填，不带端口）：

```json
{
  "registry-mirrors": [
    "https://registry.linkease.net"
  ]
}
```

2) Docker 的 HTTP/HTTPS 代理（必须带认证信息）：

```text
http://user:pass@<kspeeder-host>:5003
```

> 注意：镜像拉取请求是由 **dockerd** 发起，代理需要配置在 **Docker daemon/service**（不是只在 `docker compose` 给业务容器加 `HTTP_PROXY`）。

Linux systemd 示例（参考用法）：

1) 创建 `/etc/systemd/system/docker.service.d/proxy.conf`：

```ini
[Service]
Environment="HTTP_PROXY=http://user:pass@<kspeeder-host>:5003"
Environment="HTTPS_PROXY=http://user:pass@<kspeeder-host>:5003"
Environment="NO_PROXY=127.0.0.1,localhost"
```

2) 重启 Docker：

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

更完整说明见：`kspeeder/docs/docker-connect-proxy-mode.md`。

## 节点与配置
- `KS_USER_NODES_CONFIG`：默认 `/kspeeder-config/nodes.yaml`，推荐 `docker` + `proxies` + `domainfold` 块联合配置镜像 & proxy 节点。
- `KS_USER_MIRROR_CONFIG`：兼容旧 `mirrors.yaml` 配置，不建议添加新项；优先写入 `nodes.yaml`。

## 配置说明
- 端口配置：`KSPEEDER_PORT` / `KSPEEDER_ADMIN_PORT` 默认分别监听 5443/5003。
- 数据卷：`/kspeeder-data` 保存缓存和测量结果，`/kspeeder-config` 保存 `kspeeder.yml` 和 `nodes.yaml` 等配置文件。
- 节点配置：自动从 `/usr/share/kspeeder/nodes.yaml.sample` 拷贝 `nodes.yaml`（可用 `KS_USER_NODES_CONFIG` 重写），建议在 `docker`/`ghcr`/`domainfold`/`proxies` block 中统一填写自定义节点；`KS_USER_MIRROR_CONFIG` 只在兼容 legacy `mirrors.yaml` 时使用，已标记废弃。

## 使用说明
- 配置节点/镜像源后可通过 `docker info | grep "registry.linkease.net"` 验证代理生效。
- 更改 `nodes.yaml` 或镜像源后可运行 `docker-compose restart kspeeder`（或 `docker restart kspeeder`）快速重载。

## 开发与多架构构建
- 官方镜像：`linkease/kspeeder`
- 常用构建流程：
  ```bash
  docker run --rm --privileged docker/binfmt:a7996909642ee92942dcd6cff44b9b95f08dad64
  docker buildx create --name mybuilder --driver docker-container
  docker buildx use mybuilder
  docker buildx build --platform linux/amd64,linux/arm/v6,linux/arm/v7,linux/arm64 \
    -t linkease/kspeeder:latest -f ./Dockerfile.architecture --push .
  ```

- [`howto.md`](./howto.md) 介绍 buildx 预配置、构建、更新等操作。

## Docker Hub 手工发布

发布镜像固定为 `linkease/kspeeder`。发布前，`kspeeder` 主项目 release 会把 Docker/NAS
公开下载需要的 assets 同步到本仓库同版本 GitHub Release：

- `iStoreEnhance-binary-<version>.tar.gz`
- `iStoreEnhance-linux.amd64`
- `iStoreEnhance-linux.arm`
- `iStoreEnhance-linux.arm64`
- `version.txt`

Docker 发布脚本要求显式传入 `VERSION`，默认从本仓库 GitHub Release 下载二进制：

```text
https://github.com/kspeeder/docker_kspeeder/releases/download/v${VERSION}/
```

本地发布：

```bash
VERSION=0.7.14 DOCKER_USERNAME=<docker-user> DOCKER_PAT=<docker-pat> ./build.sh
```

脚本会推送两个 tag：

```text
linkease/kspeeder:${VERSION}
linkease/kspeeder:latest
```

如果需要临时回退到其它二进制源，可以覆盖 `KSPEEDER_BIN_BASE_URL`：

```bash
VERSION=0.7.14 KSPEEDER_BIN_BASE_URL=https://kspeeder.com/bin ./prepare-dl.sh
```

Woodpecker 手工发布 workflow 位于 `.woodpecker/release-docker.yml`，只响应 `manual`
event。首次配置需要允许 Docker socket volume 和 privileged step，并添加 Docker Hub
secret：

```bash
woodpecker-cli repo update kspeeder/docker_kspeeder --trusted-volumes --trusted-security --unsafe
woodpecker-cli repo secret add --repository kspeeder/docker_kspeeder --name docker_username --value <docker-user> --event manual --image docker:27-cli
woodpecker-cli repo secret add --repository kspeeder/docker_kspeeder --name docker_pat --value <docker-pat> --event manual --image docker:27-cli
```

手工触发：

```bash
woodpecker-cli pipeline create kspeeder/docker_kspeeder --branch main --var VERSION=0.7.14
```

## 注意事项
- 首次启动时请确保配置目录与数据目录可写。
- 修改端口或新增环境变量需同步更新 Compose/YAML 配置。
- 推荐使用 `docker-compose` 管理并启用 `restart: unless-stopped` 保障可用性。
