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
