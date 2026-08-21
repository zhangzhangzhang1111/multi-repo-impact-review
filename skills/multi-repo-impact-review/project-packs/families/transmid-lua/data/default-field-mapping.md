# _D 默认字段映射表

## 1. 概述

`_D` 是 `Get_Def_Change` 函数的别名，位于 `tools.lua` 中。

```lua
-- tools.lua 行 212
_D = Get_Def_Change;

-- 行 205-211
local function Get_Def_Change(name)
    local t = DATA_DEF_CHANGE[name];
    if t == nil then
        error(string.format('应用字典中未找到:%s 的默认转换配置，请确认', name));
    end
    return t;
end
```

当代码中使用 `_D('字段名')` 时，等同于使用 `DEF_DATA_DEF_CHANGE['字段名']` 中定义的映射配置。

**⚠️ 重要**：不同项目的 `_D` 映射可能不同！必须根据实际项目代码确定映射关系。

## 2. 不同项目的映射差异

### 2.1 常见项目映射对比

| 字段 | 国金/鸿信 (hsarapi/tools.lua) | 中信建投 (kcbp/_r_d.lua) |
|------|-------------------------------|--------------------------|
| `gdzh` | `stock_account` | `secuid` |
| `zqdm` | `stock_code` | `stkcode` |
| `zqmc` | `stock_name` | `stkname` |
| `gp_cjsl` | `business_amount` | `matchqty` |
| `gp_cjjg` | `business_price` | `matchprice` |
| `gp_cjje` | `business_balance` | `matchbal` |

### 2.2 项目代码位置

> **注意**：以下为示例路径，实际路径取决于具体券商和项目版本。

| 项目 | 文件路径 |
|------|----------|
| 国金 | `{项目根目录}/guojin/zy_all/Transmid/script/hsarapi/tools.lua` |
| 鸿信 | `{项目根目录}/hongxin/pc_rzrq/Transmid/script/hsarapi/tools.lua` |
| 中信建投 | `{项目根目录}/zhongxinjiantou/pc_rzrq/Transmid/script/kcbp/_r_d.lua` |

### 2.3 查找方法

```bash
# 查找 DEF_DATA_DEF_CHANGE 定义位置
grep -r "DEF_DATA_DEF_CHANGE" {项目根目录}/script/

# 查找 _D 函数定义位置
grep -r "_D = Get_Def_Change" {项目根目录}/script/

# 在 tools.lua 或 _r_d.lua 中查找特定字段映射
grep -n "\['zqdm'\]" {项目根目录}/script/hsarapi/tools.lua
```

## 3. 基础映射表（国金/鸿信标准）

| _D 参数 | 等效配置 | 柜台字段 | 转换函数 |
|---------|----------|----------|----------|
| `_D('index')` | `{def='', change=function(v, index) return index; end}` | - | 返回行号 |
| `_D('scmc')` | `{field='exchange_type', change=map_replace(g_gt_market_name)}` | exchange_type | 市场名称映射 |
| `_D('jys')` | `{field='exchange_type', change=map_replace(g_gt_market_name)}` | exchange_type | 市场名称映射 |
| `_D('gdzh')` | `{field='stock_account'}` | stock_account | - |
| `_D('zqdm')` | `{field='stock_code'}` | stock_code | - |
| `_D('zqmc')` | `{field='stock_name'}` | stock_name | - |
| `_D('gp_cjsl')` | `{field='business_amount'}` | business_amount | - |
| `_D('gp_cjjg')` | `{field='business_price'}` | business_price | - |
| `_D('gp_cjje')` | `{field='business_balance'}` | business_balance | - |
| `_D('cj_rq')` | `{field='business_date'}` | business_date | - |
| `_D('cj_sj')` | `{field='business_time',change=change_time}` | business_time | 时间转换 |
| `_D('wt_sj')` | `{field='entrust_time', change=change_time}` | entrust_time | 时间转换 |
| `_D('czlb')` | `{field='business_name'}` | business_name | - |
| `_D('status')` | `{field='entrust_status', change=map_replace(g_gt_orderstatus)}` | entrust_status | 状态映射 |

## 4. 使用示例

### 代码中写法
```lua
-- 实际写法
['zqdm'] = _D('zqdm'),
['gp_cjsl'] = _D('gp_cjsl'),
['cj_sj'] = _D('cj_sj'),
```

### 等效完整写法（国金/鸿信标准）
```lua
-- 等效写法
['zqdm'] = {field='stock_code'},
['gp_cjsl'] = {field='business_amount'},
['cj_sj'] = {field='business_time', change=change_time},
```

## 5. 代码位置

| 文件 | 行号 | 内容 |
|------|------|------|
| `hsarapi/tools.lua` | 119-135 | DEF_DATA_DEF_CHANGE 表定义 |
| `hsarapi/tools.lua` | 205-211 | Get_Def_Change 函数 |
| `hsarapi/tools.lua` | 212 | `_D = Get_Def_Change` |

## 6. 历史成交查询字段（国金zy_all项目）

| 客户端字段 | 客户端ID | 柜台字段 | 说明 |
|------------|----------|----------|------|
| `index` | - | - | 行号 |
| `cj_rq` | 2141 | `init_date` | 成交日期 |
| `cj_sj` | 2142 | `business_time` | 成交时间 (change_time) |
| `zqdm` | 2102 | `stock_code` | 证券代码 |
| `zqmc` | 2103 | `stock_name` | 证券名称 |
| `czlb` | 2109 | `business_name` | 操作类别 |
| `gp_cjsl` | 2128 | `business_amount` | 成交数量 |
| `gp_cjjg` | 2129 | `business_price` | 成交价格 |
| `gp_cjje` | 2131 | `business_balance` | 成交金额 |
| `gp_cjbh` | 2130 | `business_id` | 成交编号 |
| `htbh` | 2135 | `entrust_no` | 合同编号 |
| `gdzh` | 2106 | `stock_account` | 股东账户 |
| `fy_sxf` | 2132 | `fare0` | 手续费 |
| `fy_yhf` | 2133 | `fare1` | 印花税 |
| `fy_qtzf` | 2134 | `fare2+fare3+farex` | 其他费用(计算) |
| `fsje` | 2110 | `occur_balance` | 发生金额 |
| `jys` | 2108 | `exchange_type` | 交易所 |

## 7. 其他 _D 扩展

| _D 参数 | 说明 |
|---------|------|
| `_D('E_EXTEND')` | 根据REQTYPE返回扩展版本 |
| `_D('E_model')` | 根据REQTYPE返回模型 |
| `_D('T_EXTEND')` | T类请求扩展版本 |
| `_D('T_model')` | T类请求模型 |
| `_D('position_str')` | 分页位置字符串 |
| `_D('position_str_nocfg')` | 无配置分页 |
| `_D('position_str_fanye')` | 翻页分页 |
