# Rails Plugin 模板仓库实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个 Rails application template 仓库，在任意空目标目录内通过容器执行 `rails plugin new` 生成自带 Docker 工具链的 mountable Engine 骨架。

**Architecture:** 模板仓库提供 generator 镜像（ruby + rails）与 `just new` 入口（docker run，`$PWD` 挂载为 /output，模板挂载为 /template:ro）。`template.rb` 在 Rails 生成 engine 骨架后叠加：复制 scaffold 静态文件、补 Gemfile + bundle lock、生成示例 helper 及测试、docs 占位。产物内 Docker/Compose/justfile 让日常开发全部容器化。

**Tech Stack:** Rails 8.1.4.1 / Ruby 4.0.9（仅容器内）、Docker、just。宿主机零 Ruby 依赖。

**设计文档:** `docs/superpowers/specs/2026-11-18-rails-plugin-template-design.md`

**验证方式说明:** 本仓库无单元测试框架——所有验证都是端到端的：构建 generator 镜像、在临时空目录生成 plugin、在产物内跑容器化测试。每个任务的验证命令都写明预期输出。

---

### Task 1: 仓库基础文件（.gitignore、.ruby-version 说明保留在 scaffold）

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: 写 .gitignore**

```gitignore
.superpowers
generated/
```

注：不再需要 `generated/`（产物直接落目标目录），但保留条目以防用户仍想试跑；`.ruby-version` 属于 scaffold（Task 2），不放在模板仓库根目录。

- [ ] **Step 2: Commit**

```bash
git add .gitignore && git commit -m "chore: add gitignore for template repo"
```

---

### Task 2: scaffold 静态文件

**Files:**
- Create: `scaffold/.ruby-version`
- Create: `scaffold/bin/ci`
- Create: `scaffold/.gitignore`
- Create: `scaffold/Dockerfile`
- Create: `scaffold/docker-compose.dev.yml`
- Create: `scaffold/justfile`
- Create: `scaffold/README.md`

- [ ] **Step 1: scaffold/.ruby-version**

```
4.0.9
```

- [ ] **Step 2: scaffold/bin/ci**

```bash
#!/usr/bin/env bash
set -e
bundle exec rake test
```

- [ ] **Step 3: scaffold/.gitignore**

`.gitignore` 无法用 `copy_file` 追加合并到 Rails 生成内容——Rails 的 `rails plugin new` 会生成自己的 `.gitignore`（mountable plugin 生成的是包含 `*.gem` 等的版本）。策略：`template.rb` 先读 Rails 生成内容，再追加 scaffold 里的补充段。本文件只写**补充段**：

```gitignore

# Supplied by rails-plugin template
.superpowers
*.gem
```

（开头空行，保证追加后与原内容分隔。）

- [ ] **Step 4: scaffold/Dockerfile**

与 rails-blueprint 同构、裁剪为 base/development 两阶段 + test 继承：

```dockerfile
ARG BASE_IMAGE=m.daocloud.io/docker.io/library/ruby:4.0.9-slim
FROM ${BASE_IMAGE} AS base

# Aliyun mirror for apt in China
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y ca-certificates curl libjemalloc2 sqlite3 && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV LD_PRELOAD="/usr/local/lib/libjemalloc.so"
ENV BUNDLE_PATH="/usr/local/bundle"

WORKDIR /plugin

# Development stage
FROM base AS development

ENV RAILS_ENV="development" \
    BUNDLE_DEPLOYMENT="" \
    BUNDLE_WITHOUT=""

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ARG GEM_MIRROR=https://mirrors.aliyun.com/rubygems/
COPY Gemfile Gemfile.lock ./
RUN bundle config --global mirror.https://rubygems.org ${GEM_MIRROR} && \
    bundle install

COPY . .

# Test stage
FROM development AS test
ENV RAILS_ENV="test"
```

- [ ] **Step 5: scaffold/docker-compose.dev.yml**

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

- [ ] **Step 6: scaffold/justfile**

```just
_default:
    @just --list

# Start dummy app server, e.g. just up / just up -d
up *flags:
    docker compose -f docker-compose.dev.yml up --build {{flags}}

# Rebuild dev image after Gemfile changes
build:
    docker compose -f docker-compose.dev.yml build

# Stop dev environment
down:
    docker compose -f docker-compose.dev.yml down

# Run the engine test suite
test:
    docker compose -f docker-compose.dev.yml run --rm -e RAILS_ENV=test web bash -c "cd test/dummy && bin/rails db:prepare && cd ../.. && bundle exec rake test"

# Run CI checks
ci:
    docker compose -f docker-compose.dev.yml run --rm web ./bin/ci

# Rails console against the dummy app
console:
    docker compose -f docker-compose.dev.yml exec web bash -c "cd test/dummy && bin/rails console"

# Shell into container
sh:
    docker compose -f docker-compose.dev.yml exec web bash

# Run rails/rake task against dummy app, e.g. just rake 'db:prepare'
rake *args:
    docker compose -f docker-compose.dev.yml exec web bash -c "cd test/dummy && bin/rails '{{args}}'"

# Tail logs
logs:
    docker compose -f docker-compose.dev.yml logs -f web
```

- [ ] **Step 7: scaffold/README.md**

````markdown
# <PLUGIN_NAME>

Rails mountable Engine，由 [aric-tpls/rails-plugin](https://github.com/aric-tpls/rails-plugin) 模板生成。Docker / Compose / just 工具链齐全，宿主机不需要安装 Ruby。

## 快速开始

```bash
just build   # 构建开发镜像（首次较慢）
just up      # 启动 dummy app（默认 3000 端口，PORT=3001 just up 可换端口）
```

验证：`curl localhost:3000/up` 返回 200。

## 常用命令

| 命令 | 说明 |
|---|---|
| `just up` / `just up -d` | 启动 dummy app server |
| `just build` | 重建开发镜像 |
| `just down` | 停止 |
| `just test` | 跑 engine 测试套件 |
| `just ci` | 跑 bin/ci（rake test） |
| `just console` | dummy app 的 rails console |
| `just sh` | 容器 shell |
| `just rake 'db:prepare'` | 容器内跑 rake 任务 |
| `just logs` | 跟日志 |

## 结构

- `lib/<name>/engine.rb` — Engine 定义
- `app/helpers/<name>/` — 组件代码（含示例 example_helper）
- `test/` — 测试（`test/dummy/` 为测试应用）
- `bin/ci` — CI 入口

设计与规格文档见 `docs/superpowers/`。
````

（`<PLUGIN_NAME>` 占位由 template.rb 在复制时替换——见 Task 4 Step 6。）

- [ ] **Step 8: 给 bin/ci 加执行位并 commit**

```bash
chmod +x scaffold/bin/ci
git add scaffold && git commit -m "feat: add scaffold files for generated plugin"
```

---

### Task 3: Generator 镜像与模板仓库 justfile

**Files:**
- Create: `Dockerfile`
- Create: `justfile`

- [ ] **Step 1: Dockerfile（generator）**

```dockerfile
ARG BASE_IMAGE=m.daocloud.io/docker.io/library/ruby:4.0.9-slim
FROM ${BASE_IMAGE}

# Aliyun mirror for apt in China
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

- [ ] **Step 2: justfile（模板仓库）**

```just
_default:
    @just --list

# Build the generator image once
build:
    docker build -t rails-plugin-generator {{justfile_directory()}}

# Generate a new plugin into the CURRENT directory (must be empty).
# Usage: cd <target-dir> && just -f /path/to/rails-plugin/justfile new
new:
    #!/usr/bin/env bash
    set -euo pipefail
    target="$PWD"
    if [ -n "$(ls -A "$target" | grep -v '^\.git$')" ]; then
      echo "Error: target directory is not empty: $target" >&2
      exit 1
    fi
    exec docker run --rm -it \
      -v "{{justfile_directory()}}:/template:ro" \
      -v "$target:/output" \
      rails-plugin-generator \
      rails plugin new /output --mountable --skip-bundle -m /template/template.rb

# Shell into the generator image (for debugging)
sh:
    docker run --rm -it \
      -v "{{justfile_directory()}}:/template:ro" \
      -v "$PWD:/output" \
      rails-plugin-generator bash
```

- [ ] **Step 3: 构建 generator 镜像验证**

```bash
just build
```

预期：构建成功结束（apt 与 gem install 走 Aliyun；gem install rails 需数分钟）。失败且网络卡在 rubygems 时，按设计文档 fallback 加 `--build-arg GEM_MIRROR=https://rubygems.org/` 与代理 build-args 重试。

- [ ] **Step 4: 验证 rails 可用**

```bash
docker run --rm rails-plugin-generator rails -v
```

预期输出：`Rails 8.1.4.1`。

- [ ] **Step 5: Commit**

```bash
git add Dockerfile justfile && git commit -m "feat: add generator image and template justfile"
```

---

### Task 4: template.rb

**Files:**
- Create: `template.rb`

- [ ] **Step 1: 编写 template.rb**

```ruby
# Rails application template for rails plugin new (mountable engine).
# Applied inside the generator container with /output as the plugin root.

plugin_name = File.basename(Dir.pwd)                     # e.g. my_widgets
module_name = plugin_name.split("_").map(&:capitalize).join # e.g. MyWidgets

scaffold = "/template/scaffold"

# 1. Static files
copy_file "#{scaffold}/Dockerfile", "Dockerfile"
copy_file "#{scaffold}/docker-compose.dev.yml", "docker-compose.dev.yml"
copy_file "#{scaffold}/justfile", "justfile"
copy_file "#{scaffold}/bin/ci", "bin/ci"
chmod "bin/ci", 0o755
copy_file "#{scaffold}/.ruby-version", ".ruby-version"

# Append ignore rules to the generated .gitignore
append_to_file ".gitignore" do
  File.read("#{scaffold}/.gitignore")
end

# README with the real plugin name substituted
readme = File.read("#{scaffold}/README.md")
  .gsub("<PLUGIN_NAME>", plugin_name)
  .gsub("<name>", plugin_name)
create_file "README.md", readme

# 2. Gemfile: dummy app needs sqlite3; lock without installing
gem "sqlite3", ">= 2.1"
bundle_lock

# 3. Example helper + test
create_file "app/helpers/#{plugin_name}/example_helper.rb", <<~RUBY
  module #{module_name}
    module ExampleHelper
      def example_greeting(name = "world")
        "Hello, #{name}!"
      end
    end
  end
RUBY

create_file "test/example_helper_test.rb", <<~RUBY
  require "test_helper"

  module #{module_name}
    class ExampleHelperTest < ActiveSupport::TestCase
      include #{module_name}::ExampleHelper

      test "greets by name" do
        assert_equal "Hello, Alice!", example_greeting("Alice")
        assert_equal "Hello, world!", example_greeting
      end
    end
  end
RUBY

# 4. docs placeholders
create_file "docs/superpowers/specs/.keep", ""
create_file "docs/superpowers/plans/.keep", ""
```

要点说明（写给执行者）：
- `template.rb` 在 Rails 生成骨架**之后**、于 plugin 根目录上下文中执行，`Dir.pwd` 即 plugin 根。
- `gem` / `bundle_lock` 是 Rails template API 提供的方法。若 `bundle_lock` 在该 Rails 版本不可用，回退写法：`run "bundle lock"`。
- `module_name` 推导用 `capitalize`（而非 `camelize`），因为 `camelize("my_widgets")` 结果相同但对含数字等边界输入更稳的是简单规则——保持与设计文档一致的最小实现。
- 回退预案（设计文档）：若 `rails plugin new` 不接受 `-m`，把 justfile `new` 里的命令换成两步：`rails plugin new /output --mountable --skip-bundle && cd /output && bin/rails app:template LOCATION=/template/template.rb`。仅当 Task 5 验证发现 `-m` 不被支持时才改。

- [ ] **Step 2: Commit**

```bash
git add template.rb && git commit -m "feat: add rails plugin application template"
```

---

### Task 5: 端到端验证（第一次生成）

**Files:** 无新文件（在临时目录验证）

- [ ] **Step 1: 空目录生成**

```bash
mkdir -p /tmp/demo_plugin && cd /tmp/demo_plugin
just -f ~/github/aric-tpls/rails-plugin/justfile new
```

预期：生成完成、退出码 0。

- [ ] **Step 2: 检查产物完整性**

```bash
ls Dockerfile docker-compose.dev.yml justfile bin/ci .ruby-version .gitignore README.md \
   lib/demo_plugin/engine.rb demo_plugin.gemspec \
   app/helpers/demo_plugin/example_helper.rb test/example_helper_test.rb \
   Gemfile.lock docs/superpowers/specs/.keep
grep -c demo_plugin demo_plugin.gemspec
```

预期：全部文件存在；gemspec 内含 `demo_plugin`（说明模块名按目录名推导，无硬编码）。

- [ ] **Step 3: 非空目录校验**

```bash
cd /tmp/demo_plugin && just -f ~/github/aric-tpls/rails-plugin/justfile new
```

预期：`Error: target directory is not empty`，退出码 1，已有文件未被改动。

- [ ] **Step 4: 产物内测试**

```bash
cd /tmp/demo_plugin && just test
```

预期：`bundle exec rake test` 通过，2 runs, 0 failures（example_helper 的两个断言在一个 test 方法内）。若失败，先看是否 sqlite3 native 扩展或 dummy `db:prepare` 问题，修 scaffold/template 后重跑。

- [ ] **Step 5: 产物内启动验证**

```bash
just up -d
sleep 15 && curl -s -o /dev/null -w '%{http_code}\n' localhost:3000/up
```

预期输出：`200`。然后 `just down`。

- [ ] **Step 6: CI 命令**

```bash
just ci
```

预期：退出码 0。

- [ ] **Step 7: 换名回归**

```bash
mkdir -p /tmp/my_widgets && cd /tmp/my_widgets
just -f ~/github/aric-tpls/rails-plugin/justfile new
grep -r "demo_plugin\|DemoPlugin" . --exclude-dir=.git || echo "no hardcode residue"
```

预期：`no hardcode residue`；`app/helpers/my_widgets/`、`lib/my_widgets/` 存在。

- [ ] **Step 8: 清理并最终提交**

```bash
rm -rf /tmp/demo_plugin /tmp/my_widgets
cd ~/github/aric-tpls/rails-plugin
git status   # 确认无遗漏文件
```

---

## Self-Review 结论

- **Spec 覆盖**：设计文档「本仓库结构」→ Task 1–4；「使用方式」→ Task 3 justfile + Task 5 Step 1/3；「template.rb 流程」→ Task 4；「scaffold 文件要点」→ Task 2；「测试与验收」7 条 → Task 5（镜像构建 Step 前置在 Task 3）。无缺口。
- **占位符**：`<PLUGIN_NAME>`/`<name>` 是 template.rb 的运行时替换占位符，机制在 Task 4 明确，非计划占位。
- **类型/命名一致性**：scaffold README 的 `<name>` 与 template.rb gsub 一致；compose target `development` 与 Dockerfile stage 名一致。
