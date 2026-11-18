# Rails Plugin 模板设计规格

## 目标

把「用 Rails plugin 开发常用组件」这件事做成一个可复用的 Rails application template。开发者在**任意目标目录**内通过容器内执行 `rails plugin new` 生成 mountable Engine 骨架，产物自带 Docker / Compose / justfile 工具链，开发者宿主机不安装任何 Ruby 相关工具。

本仓库（`aric-tpls/rails-plugin`）是**模板仓库**，不是具体的组件库。它负责生成骨架，不承载业务代码。

## 技术栈

- Rails 8.1.4.1，Ruby 4.0.9。
- Docker 基础镜像 `ruby:4.0.9-slim`（经 DaoCloud 代理 `m.daocloud.io/docker.io/library/ruby` 拉取），Aliyun apt / gem 镜像源，与 `aric-tpls/rails-blueprint` 同源；全部可通过 build-arg 覆盖为官方源 + 代理。
- 宿主机只需 `git` / `just` / `docker`；Ruby、Rails、Bundler 全部只存在于容器内。
- 生成方式：`rails plugin new /output --mountable --skip-bundle -m /template/template.rb`，全部在 generator 容器内执行。

## 使用方式（核心交互）

```bash
# 1. 模板仓库 clone 一次（任意位置），构建 generator 镜像一次
cd ~/github/aric-tpls/rails-plugin && just build

# 2. 建好目标目录并进入（目录必须为空）
mkdir ~/github/my_widgets && cd ~/github/my_widgets

# 3. 指定模板路径执行生成，产物直接落当前目录
just -f ~/github/aric-tpls/rails-plugin/justfile new
```

- 目标目录固定为 `$PWD`，plugin 名从目录名推导（`my_widgets` → 模块 `MyWidgets`），无 name 参数。
- 前置校验：目标目录为空（允许存在 `.git`）才执行；非空时 `rails plugin new` 自身会报错，模板不额外做覆盖逻辑，**绝不自动删除已有文件**。
- justfile 通过 `justfile_directory()` 定位模板仓库自身，因此可以在任何目录以 `-f` 调用。

## 本仓库结构

```
aric-tpls/rails-plugin/
├── template.rb                  # Rails plugin 模板入口，负责叠加自定义内容
├── scaffold/                    # 待复制进新 plugin 的静态文件
│   ├── Dockerfile               # base / development / test 三阶段，国内镜像源可覆盖
│   ├── docker-compose.dev.yml   # 源码挂载 + bundle 缓存卷 + dummy app server
│   ├── justfile                 # up/build/down/console/sh/rake/test/logs
│   ├── bin/ci                   # rake test
│   ├── .ruby-version            # 4.0.9
│   ├── .gitignore               # 含 .superpowers / *.gem
│   └── README.md                # 中文启动说明
├── Dockerfile                   # generator 专用镜像（ruby:4.0.9-slim + rails gem）
├── justfile                     # build / new / sh（docker run，不用 compose）
├── .gitignore                   # 含 .superpowers
└── docs/superpowers/specs/      # 本设计文档
```

与初稿的差异：**去掉 generator 的 docker-compose.yml**。compose 的相对挂载路径以 compose 文件所在目录为准，从目标目录 `just -f` 调用会挂错目录；改用 justfile 内直接 `docker run` + `justfile_directory()` 挂载，语义清晰。同时去掉 `generated/` 输出目录（产物直接落目标目录），以及 scaffold 中的 rubocop 相关内容（见「生成后的 plugin 项目结构」）。

`scaffold/` 中的文件是可直接编辑的真实文件，不放进 heredoc。`template.rb` 只保留流程逻辑：复制静态文件、补齐 Gemfile 依赖、生成示例组件与测试、创建 `docs/superpowers/` 占位。

## Generator 镜像与模板仓库 justfile

**Dockerfile**（generator 专用）：

```dockerfile
ARG BASE_IMAGE=m.daocloud.io/docker.io/library/ruby:4.0.9-slim
FROM ${BASE_IMAGE}

# Aliyun apt mirror（与 rails-blueprint 相同的 sed 替换）
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config sqlite3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ARG GEM_MIRROR=https://mirrors.aliyun.com/rubygems/
RUN gem sources --remove https://rubygems.org/ && \
    gem sources --add ${GEM_MIRROR} && \
    gem install rails -v 8.1.4.1 --no-document

WORKDIR /output
```

**justfile**（模板仓库）：

```just
_default:
    @just --list

# Build the generator image once
build:
    docker build -t rails-plugin-generator {{justfile_directory()}}

# Generate a new plugin into the CURRENT directory (must be empty).
# Run from any directory: just -f /path/to/rails-plugin/justfile new
new:
    #!/usr/bin/env bash
    set -euo pipefail
    target="$PWD"
    if [ -n "$(ls -A "$target" | grep -v '^\.git$')" ]; then
      echo "Error: target directory is not empty: $target" >&2; exit 1
    fi
    docker run --rm -it \
      -v "{{justfile_directory()}}:/template:ro" \
      -v "$target:/output" \
      rails-plugin-generator \
      rails plugin new /output --mountable --skip-bundle -m /template/template.rb

# Shell into the generator image (for debugging)
sh:
    docker run --rm -it -v "{{justfile_directory()}}:/template:ro" -v "$PWD:/output" rails-plugin-generator bash
```

`new` 用 shebang recipe 以便做非空校验并拿到 `$PWD`。海外网络 fallback 与 rails-blueprint 相同：`docker build --build-arg GEM_MIRROR=https://rubygems.org/ --build-arg http_proxy=... --build-arg https_proxy=...`。

## template.rb 流程逻辑

Rails generator 先生成标准 mountable Engine 骨架（module / engine / version / `test/dummy/`），随后应用 `template.rb`。模块名推导：取 `File.basename(Dir.pwd)` 做 snake_case → CamelCase（`my_widgets` → `MyWidgets`），全部动态拼接，无硬编码名字。

```
1. 复制静态文件（copy_file）：
   /template/scaffold/Dockerfile            → Dockerfile
   /template/scaffold/docker-compose.dev.yml→ docker-compose.dev.yml
   /template/scaffold/justfile              → justfile
   /template/scaffold/bin/ci                → bin/ci（chmod +x）
   /template/scaffold/.ruby-version         → .ruby-version
   /template/scaffold/.gitignore            → .gitignore（追加到 plugin new 生成内容之后）
   /template/scaffold/README.md             → README.md

2. Gemfile 补齐（append 至文件末尾）：
   gem "sqlite3", ">= 2.1"                  # dummy app 数据库
   然后 bundle lock（不 install）生成 Gemfile.lock，
   源走容器内已配置的 Aliyun gem mirror。

3. 生成示例组件：
   app/helpers/<name>/example_helper.rb     # 模块 <CamelName>，一个最小 helper 方法
   test/example_helper_test.rb              # ActiveSupport::TestCase，断言 helper 返回值

4. 占位目录：
   docs/superpowers/specs/.keep
   docs/superpowers/plans/.keep
```

**回退方案**：若 `rails plugin new` 不接受 `-m/--template`，改为两步——先 `rails plugin new /output`，再 `cd /output && bin/rails app:template LOCATION=/template/template.rb`。对用户的使用方式无影响（justfile `new` recipe 内部切换，对外命令不变）。

## 生成后的 plugin 项目结构

- Rails 原生 mountable Engine 骨架：`lib/<name>/engine.rb` / `version.rb` / `<name>.rb`、`<name>.gemspec`
- `test/dummy/`：Rails 生成的测试应用，用于启动与手动验证组件
- `app/helpers/<name>/example_helper.rb`：最小示例组件，证明链路可跑通
- `test/example_helper_test.rb`：示例组件测试
- `Dockerfile` / `docker-compose.dev.yml` / `justfile` / `bin/ci` / `.ruby-version` / `.gitignore` / `README.md`：来自 scaffold
- 不含 rubocop：Gemfile 无 rubocop-rails-omakase，无 `.rubocop.yml`，`bin/ci` 只跑 `bundle exec rake test`

### scaffold 文件要点

**Dockerfile**（产物）：三阶段，与 rails-blueprint 同构但裁剪：

- `base`：DaoCloud 基础镜像 + Aliyun apt，装 `sqlite3`（运行 dummy 需要）、libjemalloc；`BUNDLE_PATH=/usr/local/bundle`；`WORKDIR /plugin`
- `development`：build-essential / git / libyaml-dev / pkg-config；`ARG GEM_MIRROR` 默认 Aliyun；`COPY Gemfile Gemfile.lock` + `bundle install`；`COPY . .`（含 test/dummy）
- `test`：继承 development，`ENV RAILS_ENV=test`；无 assets 预编译、无生产 stage、无非 root 用户（开发工具链场景，YAGNI）

**docker-compose.dev.yml**（产物）：

```yaml
services:
  web:
    build:
      context: .
      target: development
      args:
        - BASE_IMAGE=m.daocloud.io/docker.io/library/ruby:4.0.9-slim
    command: sh -c "rm -f test/dummy/tmp/pids/server.pid && (bundle check || bundle install) && cd test/dummy && bin/rails server -b 0.0.0.0"
    volumes:
      - .:/plugin
      - bundle_cache:/usr/local/bundle
    ports:
      - "${PORT:-3000}:3000"
    stdin_open: true
    tty: true
    environment:
      - RAILS_ENV=development
volumes:
  bundle_cache:
```

**justfile**（产物）：

| 命令 | 说明 |
|---|---|
| `just up *flags` | `docker compose -f docker-compose.dev.yml up --build {{flags}}`，启动 dummy app server |
| `just build` | 重建开发镜像 |
| `just down` | 停止 |
| `just test` | `docker compose run --rm -e RAILS_ENV=test web bash -c "cd test/dummy && bin/rails db:prepare && cd ../.. && bundle exec rake test"` —— 无需 up 中的 server 常驻 |
| `just ci` | `docker compose run --rm web ./bin/ci`（即 rake test） |
| `just console` | `exec web bash -c "cd test/dummy && bin/rails console"` |
| `just sh` | `exec web bash` |
| `just rake *args` | `exec web bash -c "cd test/dummy && bin/rails '{{args}}'"` |
| `just logs` | `logs -f web` |

注：`up` 的 command 与 `test` 都先 `bundle check || bundle install`（up 内）或 `db:prepare`（test 内），与 bundle_cache 卷自愈逻辑一致。`test` 具体写法在实现时以实际跑通为准，约束是：不依赖 dev server 常驻、test 环境 db 先 prepare。

**bin/ci**（产物）：

```bash
#!/usr/bin/env bash
set -e
bundle exec rake test
```

**.gitignore**（产物）：在 Rails 生成的 engine 默认内容基础上，追加：

```
.superpowers
*.gem
```

**README.md**（产物）：中文说明，三步启动：`just build`（可复用模板仓库镜像命令）→ `just up` → `just test` / `just ci`，附 just 命令表与 PORT 环境变量说明。

## 测试与验收

1. 模板仓库 `just build` 成功，generator 容器内 `rails -v` 输出 8.1.4.1。
2. 在空目录执行 `just -f <模板路径>/justfile new` 成功，产物包含上述全部文件，且宿主机无任何 Ruby 进程/依赖。
3. 非空目录执行 `new` 直接报错退出，不改动任何已有文件。
4. `cd <产物目录> && just test` 通过（示例 helper 测试在容器内跑通）。
5. `just up` 后 `curl localhost:3000/up` 返回 200。
6. `just ci` 全绿。
7. 换第二个目录名（如 `my_widgets`）再生成一次：模块名（`MyWidgets`）、`app/helpers/my_widgets/`、gemspec 名随之变化，无 `demo_plugin` / `DemoPlugin` 硬编码残留。

## 明确不做（YAGNI）

- gem 发布 / release-it / gem push
- 生产部署与生产 compose 文件
- rubocop / brakeman / bundler-audit 等静态检查（用户明确不需要）
- 业务组件实现（本仓库只产骨架与一个示例 helper）
- 复杂 CI 矩阵、多数据库适配
- 在宿主机安装或配置 Ruby 的任何步骤
- name 参数与非空目录覆盖逻辑（固定 `$PWD` + 空目录校验）
