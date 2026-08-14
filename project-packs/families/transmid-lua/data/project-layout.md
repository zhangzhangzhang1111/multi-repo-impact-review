# 项目目录结构

以下目录仅用于识别常见形态，不代表目标项目必须使用 `hsarapi` 或示例文件名。实际业务目录和注册入口必须由目标仓库特征确认。

## Windows 版本

```
Transmid/script/
├── comm/           # 架构代码
│   ├── jmodel.lua  # 核心框架：请求分发、数据转换
│   ├── comm.lua    # 公共函数
│   └── defines.lua # 定义
└── hsarapi/        # 业务逻辑
    ├── config_hx.lua # 鸿信配置入口
    ├── config_gj.lua # 国金配置入口
    ├── rzrq.lua       # 融资融券
    ├── asset.lua      # 资产
    └── ...
```

## Linux 版本

```
wt_service/bin/script/
├── comm/           # 架构代码
│   ├── jmodel.lua
│   ├── comm.lua
│   └── defines.lua
└── hsarapi/        # 业务逻辑
    ├── config_gj.lua  # 国金配置入口
    └── ...
```

### Windows vs Linux 目录差异

| 项目 | Windows 路径 | Linux 路径 |
|------|--------------|------------|
| 脚本目录 | `.../Transmid/script/` | `.../wt_service/bin/script/` |
| 核心文件 | `hsarapi/config_*.lua` | `hsarapi/config_*.lua` |
| 架构文件 | `comm/jmodel.lua` | `comm/jmodel.lua` |

> **注意**：Linux 版本目录从 `wt_service/` 开始，后面与 Windows 版本结构一致。

# 关键文件

| 文件 | 作用 |
|------|------|
| jmodel.lua | 请求分发、协议转换、结果映射 |
| config_hx.lua | 鸿信业务请求注册入口 |
| hsarapi/*.lua | 各业务模块实现 |

# 项目特征

- 每个项目业务逻辑主要在 .lua 文件
- comm 文件夹是公共架构，不同项目复用
- 请求通过`[moneytype][reqtype]-[mmlb]-[his_query]-[cmd]-[extend]`组合匹配处理函数

# 请求格式详解

完整命令格式：`[moneytype][reqtype]-[mmlb]-[his_query]-[cmd]-[extend]`

## 组成部分

| 组成部分 | 位置 | 说明 |
|----------|------|------|
| moneytype | 第1位 | 前缀：`@`(资产清理)、空(普通) |
| reqtype | 第1字母 | 请求类型：1/3/4/5/C/E/F/J/L/T/I |
| mmlb | 第3位 | 买卖类别：0/1/2/6/7/8/9/:/=/-/星号 |
| his_query | 第4位 | 历史标识：`H`(历史)、空(当日) |
| cmd | 第5位起 | 具体业务命令，如 rzrq_cxwt、xgsg_fqrg 等 |
| extend | 最后 | 扩展参数 |

## 匹配流程 (jmodel.lua)

1. `DoHandleRequest` 接收客户端请求
2. 拼装命令：`reqcmd = string.format('%s%s-%s%s-%s-%s', moneytype, reqtype, mmlb, his_query, cmd, extend)`
3. 先在 `_spe_req_handle`（特殊配置）中匹配
4. 再在 `_req_handle`（默认配置）中匹配
5. 调用对应的处理函数

## 数据转换链路

请求处理流程中的数据转换分为三个阶段：

```
客户端请求(askdata)
       ↓
   [pre_handle]  ←  详见 pre-handle.md
       ↓
  柜台请求(req) → 调用柜台API
       ↓
   柜台返回(result)
       ↓
 [table_handle]  ←  详见 table-handle.md (列表数据)
 [post_handle]   ←  详见 post-handle.md (单条结果)
[extend_handle]  ←  详见 post-handle.md (扩展数据)
[userinfo_handle] ← 详见 post-handle.md (用户信息)
[extern_data_handle] ← 详见 post-handle.md (结构化扩展)
       ↓
 返回客户端(replydata)
```

### 各阶段说明

| 阶段 | 作用 | 文档 |
|------|------|------|
| pre_handle | 客户端请求 → 柜台请求 | pre-handle.md |
| table_handle | 柜台列表 → 客户端列表 | table-handle.md |
| post_handle | 柜台单条 → 客户端字段 | post-handle.md |
| extend_handle | 扩展数据 → T_ADD_DATA | post-handle.md |
| userinfo_handle | 柜台数据 → 用户缓存 | post-handle.md |
| extern_data_handle | 结构化扩展 → extend_data | post-handle.md |

## 关联文档

| 文档 | 说明 |
|------|------|
| `adapter-layout.md` | 项目文件夹、柜台适配目录和脚本根目录规则 |
| `default-field-mapping.md` | _D 默认字段映射表 |
| `request-command-catalog.md` | 请求命令代码对照表 |
| `request-dispatch.md` | 请求 key、注册表和 handler 查找顺序 |
| `conversion-lifecycle.md` | 转换生命周期总规则 |
| `pre-handle.md` | 请求参数转换规则 |
| `table-handle.md` | 列表数据转换规则 + 字段字典 |
| `post-handle.md` | 结果转换规则 (post/extend/extern/userinfo) |

## 项目目录命名规则

### 一级目录：券商拼音
```
Transmid-git\
├── zhongtianguofu/     # 中天国富
├── hongxin/             # 鸿信
├── zhongxinjiantou/     # 中信建投
├── zhongjin/            # 中金
└── ...
```

### 二级目录：项目版本
| 前缀 | 含义 |
|------|------|
| `pc` | PC客户端版本 |
| `sj` | 手机客户端版本 |
| `zy` | 自运营交易版本 |
| `mn` | 模拟炒股版本 |

| 后缀 | 含义 |
|------|------|
| `pt` | 普通交易 |
| `rzrq` | 融资融券 |
| `ks/ksgt` | 快速柜台 |
| `all` | 综合版 |
| `linux` | Linux版本 |
| `uft` | 快速柜台版 |

详见 `adapter-layout.md`
