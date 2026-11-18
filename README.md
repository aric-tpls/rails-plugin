# Rails Plugin Template

Rails plugin 模板仓库：在任意空目录内通过容器执行 `rails plugin new`，生成自带 Docker / Compose / just 工具链的 mountable Engine 骨架。宿主机只需 `git` / `just` / `docker`，不安装任何 Ruby 工具。

## 技术栈

- Rails 8.1.4.1 + Ruby 4.0.9（仅存在于容器内）
- 生成产物：mountable Engine + dummy app + 示例 helper，gem 源走清华镜像（可覆盖）

## 使用

```bash
# 1. clone 模板仓库（任意位置），构建 generator 镜像一次
git clone <repo-url> && cd rails-plugin && just build

# 2. 建好目标目录并进入（必须为空，允许 .git）
mkdir ~/github/my_widgets && cd ~/github/my_widgets

# 3. 生成，产物直接落当前目录，插件名取自目录名
just -f ~/github/aric-tpls/rails-plugin/justfile new
```

生成后目录内可用命令：

| 命令 | 说明 |
|---|---|
| `just up` / `just up -d` | 启动 dummy app（默认 3000 端口，`PORT=3001 just up` 可换） |
| `just build` | 重建开发镜像 |
| `just down` | 停止 |
| `just test` | 跑 engine 测试 |
| `just ci` | 跑 `bin/ci` |
| `just console` / `just sh` / `just rake '...'` / `just logs` | 容器内 console / shell / rake / 日志 |

验证：`curl localhost:3000/up` 返回 200。

## 网络说明

默认国内镜像源（DaoCloud 基础镜像 + 清华 gem 源 / Aliyun apt 源）。gem 源缺新版本 gem 时可覆盖：

```bash
just build  # 模板仓库内，generator 镜像同理可加 build-arg
docker compose build --build-arg GEM_MIRROR=https://rubygems.org/ \
  --build-arg http_proxy=http://host.docker.internal:9090 \
  --build-arg https_proxy=http://host.docker.internal:9090
```

## 生成器内部（模板仓库开发者）

- `Dockerfile` — generator 镜像（ruby + rails 8.1.4.1）
- `template.rb` — Rails application template：复制 `scaffold/`、参数化 gemspec 路径、`bundle lock`、生成示例 helper 及测试、追加 dummy `/up` 路由
- `scaffold/` — 生成产物的静态文件（Dockerfile / compose / justfile / bin/ci / README 等）
- `just new` — 非空目录校验 + `docker run` 挂载 `$PWD` 执行生成

设计与实现细节见 `docs/superpowers/`。

## 明确不做

gem 发布、生产部署、rubocop/brakeman 等静态检查、多数据库适配。
