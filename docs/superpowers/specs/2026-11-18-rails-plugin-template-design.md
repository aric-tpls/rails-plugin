# Rails Plugin 模板设计规格

## 目标

把「用 Rails plugin 开发常用组件」这件事做成一个可复用的 Rails application template。新项目通过容器内执行 `rails plugin new NAME --mountable -m template.rb` 生成，产物自带 Docker / Compose / justfile 工具链，开发者宿主机不安装任何 Ruby 相关工具。

本仓库（`aric-tpls/rails-plugin`）是**模板仓库**，不是具体的组件库。它负责生成骨架，不承载业务代码。

## 技术栈

- Rails 8.1.4.1，Ruby 4.0.9。
- Docker 基础镜像 `ruby:4.0.9-slim`，Aliyun apt / gem 镜像源，与 `aric-tpls/rails-blueprint` 同源。
- 宿主机只需 `git` / `just` / `docker`；Ruby、Rails、Bundler 全部只存在于容器内。
- 生成方式：`rails plugin new NAME --mountable --skip-bundle -m /template/template.rb`，全部在 generator 容器内执行。

## 本仓库结构

```
aric-tpls/rails-plugin/
├── template.rb                  # Rails plugin 模板入口，负责叠加自定义内容
├── scaffold/                    # 待复制进新 plugin 的静态文件
│   ├── Dockerfile               # base / development / test 三阶段，Aliyun 镜像源
│   ├── docker-compose.dev.yml   # 源码挂载 + bundle 缓存卷 + dummy app server
│   ├── justfile                 # up/build/down/console/sh/rake/test/ci/logs
│   ├── bin/ci                   # rubocop + rake test
│   ├── .ruby-version            # 4.0.9
│   ├── .gitignore               # 含 .superpowers / *.gem / generated/
│   └── README.md                # 中文四步启动说明
├── Dockerfile                   # generator 专用镜像（ruby:4.0.9-slim + rails gem）
├── docker-compose.yml           # generator service：仓库只读挂载 + generated/ 可写
├── justfile                     # build / new name=x / sh / list
├── generated/                   # 生成产物输出目录（gitignore）
└── docs/superpowers/specs/      # 本设计文档
```

`scaffold/` 中的文件是可直接编辑的真实文件，不放进 heredoc。`template.rb` 只保留流程逻辑：复制静态文件、补齐 Gemfile 依赖、生成示例组件与测试、创建 `docs/superpowers/` 占位。

## 生成流程

1. 宿主机执行 `just build`，构建 generator 镜像一次（gem 镜像走 Aliyun）。
2. `just new name=demo_plugin` → 容器内执行：
   `rails plugin new /output/demo_plugin --mountable --skip-bundle -m /template/template.rb`
3. Rails generator 先生成标准 mountable Engine 骨架（module / engine / version / `test/dummy/`），随后应用 `template.rb`：
   - 从 `/template/scaffold/` 复制 `Dockerfile`、`docker-compose.dev.yml`、`justfile`、`bin/ci`、`.ruby-version`、`.gitignore`、`README.md` 到目标目录；
   - 向 Gemfile 补齐 dummy app 与测试所需依赖（sqlite3、rubocop-rails-omakase），执行 `bundle lock` 生成 Gemfile.lock；
   - 创建示例组件 `app/helpers/<name>/example_helper.rb` 及其测试 `test/example_helper_test.rb`，模块名按目标目录名推导（snake_case → CamelCase，如 `demo_plugin` → `DemoPlugin`）；
   - 创建 `docs/superpowers/specs/` 与 `docs/superpowers/plans/` 占位。
4. 产物落在 `generated/demo_plugin/`，用户自行移出作独立仓库。

**回退方案**：若 `rails plugin new` 不接受 `-m/--template`，改为两步——先 `rails plugin new`，再在生成目录内执行 `bin/rails app:template LOCATION=/template/template.rb`。对用户的使用方式无影响。

## 生成后的 plugin 项目结构

- Rails 原生 mountable Engine 骨架：`lib/<name>/engine.rb` / `version.rb` / `<name>.rb`
- `test/dummy/`：Rails 生成的测试应用，用于启动与手动验证组件
- `app/helpers/<name>/example_helper.rb`：最小示例组件，证明链路可跑通
- `test/example_helper_test.rb`：示例组件测试
- `Dockerfile` / `docker-compose.dev.yml` / `justfile` / `bin/ci` / `.ruby-version` / `.gitignore` / `README.md`：来自 scaffold
- 日常命令全部在容器内：
  - `just up`：启动 dummy app（容器内 `cd test/dummy && bin/rails server -b 0.0.0.0`），端口 `${PORT:-3000}:3000`
  - `just test`：容器根目录执行 `bundle exec rake test`
  - `just ci`：执行 `bin/ci`（rubocop + rake test）
  - `just console` / `just sh` / `just rake '...'` / `just logs`：全部 `docker compose exec`

## 测试与验收

1. 模板仓库 `just build` 成功，generator 容器内 `rails -v` 可用。
2. `just new name=demo_plugin` 成功，产物包含上述全部文件，且宿主机无任何 Ruby 进程/依赖。
3. `cd generated/demo_plugin && just test` 通过（示例 helper 测试在容器内跑通）。
4. `just up` 后 `curl localhost:3000/up` 返回 200。
5. `just ci` 全绿。
6. 换第二个名字（如 `my_widgets`）再生成一次，确认无硬编码残留，模块名与文件路径随之变化。

## 明确不做（YAGNI）

- gem 发布 / release-it / gem push
- 生产部署与生产 compose 文件
- 业务组件实现（本仓库只产骨架与一个示例 helper）
- 复杂 CI 矩阵、多数据库适配
- 在宿主机安装或配置 Ruby 的任何步骤
