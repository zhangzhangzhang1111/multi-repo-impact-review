# table_handle 处理规则

## 1. 概述

table_handle 是 jmodel.lua 中的结果转换模块，负责将**柜台返回的列表数据**（如持仓、成交、委托）转换为**客户端能识别的字段格式**。

```
柜台返回(result) → table_handle转换 → 客户端数据(mt:add_row) → 返回客户端
```

## 2. 配置结构

```lua
table_handle = {
    head = hdhead,           -- 返回数据表头定义
    handle = {               -- 字段映射配置
        ['客户端字段名'] = {
            field = '柜台字段名',   -- 从柜台结果获取值的字段
            def = '默认值',         -- 柜台无值时的默认值
            change = function(v, index, userinfo, askdata, replydata)
                -- 转换逻辑
                return 转换后的值
            end
        },
        ...
    },
    save_old_data = true/false,  -- 是否保留历史数据
    save_cur_data = true/false,   -- 是否保留当前数据
}
```

`head` 定义最终返回表的列、顺序和显示元数据；`handle` 负责构造逐行 `item` 的初始值。二者不是简单的集合相等关系：返回列也可能由 `OTHERHANDLE` 或明确的 `TABLEHANDLE` 产生，而不在 `head` 的字段可能是过滤、计算、排序或合并所需的内部字段。

## 3. 处理流程 (HandleMultiQueryTable)

```
1. 遍历柜台返回的每一行(i = 0 to _items-1)
2. 对每个映射字段：
   a. 从柜台结果获取值: _result:get_table_item_text(tbname, i, v.field)
   b. 使用默认值: _value = _value or v.def
   c. 应用转换函数: v.change(_value, index, userinfo, askdata, replydata)
3. 执行后处理函数(OTHERHANDLE)
4. 执行跳过函数(SKIPFUNC)，返回true则跳过该行
5. 将转换后的数据添加到返回表: mt:add_row(tbname, item)
6. 执行表后处理函数(TABLEHANDLE)
```

## 4. 字段映射示例

### 4.1 基础字段映射

```lua
table_handle = {
    handle = {
        ['zqdm']   = {field='stock_code'},      -- 证券代码
        ['zqmc']   = {field='stock_name'},      -- 证券名称
        ['gdzh']   = {field='stock_account'},   -- 股东账户
        ['cj_rq']  = {field='business_date'},  -- 成交日期
    }
}
```

### 4.2 带默认值

```lua
handle = {
    ['index'] = {def='', change=function(v, index) return index; end},  -- 行号
    ['position_str'] = {def = '', field='position_str'},
}
```

### 4.3 带转换函数

```lua
handle = {
    -- 市场名称转换
    ['scmc'] = {field='exchange_type', change=map_replace(g_gt_market_name)},

    -- 状态转换
    ['status'] = {field='entrust_status', change=map_replace(g_gt_orderstatus)},

    -- 时间格式转换 (HHMMSS -> HH:MM:SS)
    ['cj_sj'] = {field='business_time', change=change_time},

    -- 自定义转换
    ['gp_cjsl'] = {field='business_amount'},
}
```

## 5. 特殊处理函数

### 5.1 OTHERHANDLE (行后处理)

在每行添加到返回数据之前执行：
```lua
other_funcs = {
    function(item, userinfo, askdata, replydata)
        -- 处理item中的数据
        item['gp_cjje'] = tonumber(item['gp_cjsl']) * tonumber(item['gp_cjjg'])
    end
}
```

### 5.2 SKIPFUNC (行过滤)

返回 true 则跳过该行：
```lua
skip_funcs = {
    function(item, userinfo, askdata, replydata)
        return item['cj_rq'] == ''  -- 跳过空日期的行
    end
}
```

### 5.3 TABLEHANDLE (表后处理)

在所有行处理完成后执行：
```lua
table_handle_funcs = {
    function(mt, tbname, item)
        -- 对整个表进行处理
    end
}
```

## 5.4 字段依赖与行状态

- `handle` 的目标键是 `item` 的初始字段生产者；`field`、`def` 和 `change` 共同决定值来源。
- `OTHERHANDLE` 按数组顺序执行，其写入对后续 `OTHERHANDLE` 和 `SKIPFUNC` 可见。
- `SKIPFUNC` 的返回值控制当前行是否写入，但其字段读取仍要求前序生产者存在。
- 具名回调必须追到实际函数体；只看到注册名不能确认字段依赖。
- 字段从返回表头隐藏不等于可以删除内部 `handle` 生产者。
- 对每个最终 `head` 字段确认写表前的生产者；普通映射、固定值、`change` 结果和 `OTHERHANDLE` 写入都可以是合法生产者。没有生产者或只有部分路径生产时不能认为返回契约完整。
- 不在 `head` 中的 `handle` 字段先检查内部消费者；存在消费者时属于内部字段，不应作为多余返回字段删除。
- 追踪 wrapper 对 `table_handle.head` 的运行时替换、共享和恢复；静态初始 `head` 不一定是实际请求使用的返回契约。
- 必须从目标项目的 `jmodel.lua` 确认 `item` 是否逐行重建。若跨行复用，回调新增字段的条件写入必须在每行所有必要路径初始化或清理，否则可能读取上一行残留值。

## 6. 客户端字段 ID 候选字典 (WT_xxx)

以下是部分项目中的常用客户端字段 ID，只用于检索候选常量；正式结论必须读取目标项目的 `defines.lua` 和实际返回表头。

### 6.1 基础信息

| 字段ID | 常量名 | 含义 |
|--------|--------|------|
| 2102 | WT_ZQDM | 证券代码 |
| 2103 | WT_ZQMC | 证券名称 |
| 2104 | WT_RIQI | 日期 |
| 2105 | WT_NOTE | 备注 |
| 2106 | WT_GDZH | 股东账户 |
| 2107 | WT_GDXM | 股东姓名 |
| 2108 | WT_JYS | 交易所 |
| 2109 | WT_CZLB | 操作类别 |

### 6.2 资金相关

| 字段ID | 常量名 | 含义 |
|--------|--------|------|
| 2112 | WT_ZJ_YE | 资金余额 |
| 2113 | WT_ZJ_DJJE | 冻结金额 |
| 2114 | WT_ZJ_CXJE | 撤单金额/可取金额 |
| 2115 | WT_ZJ_HZJE | 转出金额 |
| 2116 | WT_ZJ_KYYE | 资金可用额 |
| 2160 | WT_ZJ_BCje | 变动金额 |
| 2165 | WT_ZJ_LSH | 资金流水号 |

### 6.3 股票持仓

| 字段ID | 常量名 | 含义 |
|--------|--------|------|
| 2117 | WT_GP_YE | 股票余额 |
| 2118 | WT_GP_DJSL | 股票冻结数量 |
| 2119 | WT_GP_HZSL | 股票红冲数量 |
| 2120 | WT_GP_CXSL | 股票撤单数量 |
| 2121 | WT_GP_KYYE | 股票可用余额 |
| 2122 | WT_GP_MRJG | 股票买入价格均价 |
| 2123 | WT_GP_MRCB | 股票买入成本 |
| 2124 | WT_GP_ZXJG | 股票最新价格 |
| 2125 | WT_GP_SZ | 股票市值 |
| 2147 | WT_GP_PROFIT | 股票浮动盈亏 |
| 3704 | WT_GPLB | 股票类别 |
| 2164 | WT_GP_SJSL | 股票实际数量 |
| 2167 | WT_MK_CODE | 市场代码 |

### 6.4 自定义字段ID (2001-2100)

> **⚠️ 重要规则**：字段ID **2001-2100** 区间是**自定义字段**，各个请求、各家券商可能都不一样，**不能写到通用规则中**。

| 字段ID | 字段名(代码中) | 含义 |
|--------|---------------|------|
| 2001 | jclx | 持仓类型(仅港股通) |
| 2003 | ztmr | 冻结买入(仅港股通) |
| 2004 | ztmc | 冻结卖出(仅港股通) |
| 2005 | ykbl | 盈亏比例%(仅港股通) |
| 3918 | qdjg | 前单价(仅港股通) |
| 3919 | jcz | 持仓值(仅港股通) |
| 3920 | zdjg | 昨单价(仅港股通) |
| 3921 | jclb | 持仓量(仅港股通) |

**正确做法**：查找特定请求的 table_handle head 定义，确认具体ID。

```bash
# 在具体业务文件中查找
grep -n "DTE_DOUBLE.*2005\|DTE_STRING.*2003" {项目路径}/script/**/ggt.lua
```

### 6.4 委托相关

| 字段ID | 常量名 | 含义 |
|--------|--------|------|
| 2126 | WT_GP_WTSL | 委托数量 |
| 2127 | WT_GP_WTJG | 委托价格 |
| 2135 | WT_HTBH | 合同编号 |
| 2139 | WT_WT_RQ | 委托日期 |
| 2140 | WT_WT_SJ | 委托时间 |
| 2152 | WT_WT_FANGSHI | 委托方式 |

### 6.5 成交相关

| 字段ID | 常量名 | 含义 |
|--------|--------|------|
| 2128 | WT_GP_CJSL | 成交数量 |
| 2129 | WT_GP_CJJG | 成交价格 |
| 2130 | WT_GP_CJBH | 成交编号 |
| 2131 | WT_GP_CJJE | 成交金额 |
| 2132 | WT_FY_SXF | 委托手续费 |
| 2133 | WT_FY_YHF | 委托印花税 |
| 2134 | WT_FY_QTZF | 委托其他费 |
| 2141 | WT_CJ_RQ | 成交日期 |
| 2142 | WT_CJ_SJ | 成交时间 |
| 2157 | WT_CJ_CJBS | 成交笔数 |
| 2163 | WT_CJ_PH | 成交批号 |

### 6.6 市场代码映射 (g_gt_market_name)

| 柜台值 | 市场名称 |
|--------|----------|
| 0 | 深圳A股 |
| 1 | 上海A股 |
| 2 | 深圳B股 |
| 3 | 上海B股 |
| 8 | 港股通 |
| 9 | 申购 |

### 6.7 委托状态映射 (g_gt_orderstatus)

| 柜台值 | 状态名称 |
|--------|----------|
| 0 | 待成交 |
| 1 | 部分成交 |
| 2 | 全部成交 |
| 3 | 全部撤单 |
| 4 | 废单 |
| 5 | 正常 |

## 7. 字段映射候选速查

### 客户端 → 柜台 (常见)

| 客户端字段 | 柜台字段 | 说明 |
|------------|----------|------|
| zqdm | stock_code | 证券代码 |
| zqmc | stock_name | 证券名称 |
| gdzh | stock_account | 股东账户 |
| gp_cjsl | business_amount | 成交数量 |
| gp_cjjg | business_price | 成交价格 |
| gp_cjje | business_balance | 成交金额 |
| cj_rq | business_date | 成交日期 |
| cj_sj | business_time | 成交时间 |
| wt_sj | entrust_time | 委托时间 |
| czlb | business_name | 操作类别 |
| status | entrust_status | 委托状态 |
| scmc | exchange_type | 市场名称 |
| jys | exchange_type | 交易所 |

## 8. 时间转换函数

```lua
-- 整数时间转 HH:MM:SS 格式
function change_time(v)
    if v == nil or v == '' then return '' end;
    if string.len(v) < 6 then
        v = string.format("%06d",v);
    elseif string.len(v) > 6 then
        v = string.format("%09d",v);
        v = string.sub(v,1,6);
    end
    return string.gsub(v, '(%d*)(%d%d)(%d%d)$', '%1:%2:%3');
end
```

## 9. 字段名到客户端ID的映射规则

### 9.1 查找方法

在代码中形如 `{'zzqdm', '', DTE_STRING + WT_ZQDM, ...}` 的写法：
- `zzqdm` 是客户端字段名
- `WT_ZQDM` 是客户端ID的宏定义
- 实际客户端ID = 宏定义的值（如 WT_ZQDM = 2102）

### 9.2 defines.lua 位置

```
{项目根目录}/{券商}/{项目版本}/Transmid/script/comm/defines.lua
```

### 9.3 常见映射规则

在 table_handle 的 head 定义中，字段名格式为 `客户端字段名`，客户端ID通过 DTE_xxx + WT_xxx 组合确定：

```lua
-- 格式
{'字段名', '中文名', DTE类型 + WT_宏, 显示属性, 宽度, 小数位}

-- 示例
{'zqdm', '', DTE_STRING + WT_ZQDM, DD_LEFT, 8, 3}
-- 含义: 字段名 zqdm, 客户端ID = WT_ZQDM = 2102
```

### 9.4 defines.lua 中的定义格式

```lua
-- 宏定义 (行号 23-120+)
WT_ZQDM = 2102   -- 证券代码

-- 字段映射定义 (行号 700-900+)
['zqdm'] = {'zqdm', '', DTE_STRING + WT_ZQDM, DD_LEFT, 8, 3},
```

### 9.5 快速查找命令

```bash
# 查找 WT_ 宏定义
grep -n "^WT_ZQDM" {项目路径}/script/comm/defines.lua

# 查找字段映射
grep -n "\['zqdm'\]" {项目路径}/script/comm/defines.lua
```

### 9.6 head 定义中字段名没有客户端ID时的处理

如果遇到这种情况：

```lua
head = CreateReturnHDFile
{
    "index",           -- 没有客户端ID
    "zqdm",            -- 没有客户端ID
    {"ykbl", ...},    -- 没有客户端ID
    {"gp_ye", DTE_DOUBLE + WT_GP_YE, ...},  -- 有客户端ID
}
```

**处理方法**：从 `defines.lua` 中查找对应字段的客户端ID：

| 情况 | 查找方式 |
|------|----------|
| 字段名直接写（如 `"zqdm"`） | grep 查找 `WT_` 开头 + 字段名相关 |
| 字段在 defines.lua 有映射 | grep 查找 `['zqdm']` 行获取 WT_xxx |
| 自定义字段（2001-2100） | 在业务代码中搜索实际使用的ID |

```bash
# 示例：查找 ykbl 和 zjzh 的客户端ID
grep -n "WT_YKBL\|WT_ZJZH" {项目路径}/script/comm/defines.lua

# 查找字段在 defines.lua 中的映射定义
grep -n "\['ykbl'\]\|\['zjzh'\]" {项目路径}/script/comm/defines.lua
```

**常见缺失ID的字段**：

| 字段名 | 客户端ID | 常量名 |
|--------|----------|--------|
| ykbl | 3616 | WT_YKBL |
| zjzh | 2908 | WT_ZJZH |
| zjzh_status | 2937 | WT_ZJZH_STATUS |

## 10. save_old_data 与 save_cur_data 机制

### 10.1 核心作用

| 参数 | 作用 | 默认值 |
|------|------|--------|
| `save_old_data` | 是否保留历史数据（上次查询结果） | false |
| `save_cur_data` | 是否保留当前数据 | true |

### 10.2 数据合并原理

```
第一次查询:
  save_old_data=true, save_cur_data=true
  → 不清除历史数据 + 保留当前数据 = 两次数据合并

第二次查询:
  save_old_data=false, save_cur_data=true (默认)
  → 清除历史数据 + 保留当前数据 = 只返回本次数据
```

### 10.3 jmodel.lua 中的处理逻辑

```lua
-- 行184: 如果不保存历史数据，则清除原有数据
if not config.save_old_data then
    mt:DeleteAllItems(tbname);
end

-- 处理当前数据...

-- 行287: 如果不保存当前数据，则清除本次添加的数据
if not config.save_cur_data then
    mt:DeleteAllItems(tbname);
end
```

### 10.4 典型使用场景：Query_Combine_Psqy

**功能**：合并查询（普通股票持仓 + 可转债额度）

```lua
local Query_Combine_Psqy = function(userinfo, askdata, replydata, dorequest)
    -- 第一次查询：普通股票持仓
    Query_Psqy.table_handle.save_old_data = true;   -- 标记保留历史
    Query_Psqy.table_handle.save_cur_data = true;   -- 标记保留当前
    Query_Psqy.pre_handle['funcid'] = '333039';     -- 设置功能号
    HandleNormalRequest(userinfo, askdata, replydata, dorequest, Query_Psqy);

    -- 从结果中提取可转债额度数据
    local fund_account = replydata:getdata('kcb_zjzh') or '';
    local enable_amount = replydata:getdata('kcb_ed') or '';
    local stock_account = replydata:getdata('kcb_gdzh') or '';

    -- 第二次查询：使用 _USE_SELF_DATA_ 注入可转债额度
    Query_Psqy.pre_handle = self_return_data;  -- 包含 _USE_SELF_DATA_
    HandleNormalRequest(userinfo, askdata, replydata, dorequest, Query_Psqy);

    -- 恢复默认状态
    Query_Psqy.table_handle.save_old_data = false;
    Query_Psqy.table_handle.save_cur_data = false;
end
```

**效果**：
- 第一次查询结果（普通持仓）保存在内存
- 第二次查询时，**不清除**第一次的数据，而是追加合并
- 最终返回：普通持仓 + 可转债额度（两条记录）

### 10.5 _USE_SELF_DATA_ 机制

在 pre_handle 中注入自定义数据：

```lua
local self_return_data = {
    ['_USE_SELF_DATA_'] = '1',
    ['_SELF_DATA_'] = {
        {'fund_account', 'enable_amount', 'exchange_type', 'stock_account'},
    }
};

-- 添加一行自定义数据
local kcb_data = {fund_account, enable_amount, exchange_type, stock_account};
table.insert(self_return_data['_SELF_DATA_'], kcb_data);
```

**作用**：绕过柜台查询，直接返回预设数据（常用于合并补充数据）

### 10.6 识别模式

类似逻辑的函数特征：
- 函数名包含 `Combine`、`Merge`、`PSQY`
- 调用两次 `HandleNormalRequest`
- 设置 `save_old_data = true` 和 `save_cur_data = true`
- 第二次调用前修改 `pre_handle` 或使用 `_USE_SELF_DATA_`

### 10.7 代码位置

> **注意**：以下为国金项目的示例路径，实际路径取决于具体券商和项目版本。

```
{项目根目录}\{券商}\{项目版本}\Transmid\script\hsarapi\config_gj.lua
  - 行3208: Query_Combine_Psqy 定义
  - 行3028: Query_Psqy 定义

{项目根目录}\{券商}\{项目版本}\Transmid\script\comm\jmodel.lua
  - 行184: save_old_data 处理
  - 行287: save_cur_data 处理
```

## 11. 调试技巧

1. 启用调试：`show_debug = true`
2. 查看转换结果日志
3. 对比原始柜台数据和转换后数据

---

# 示例项目字段映射表

| 客户端字段 | 客户端ID | 柜台字段 | 转换函数 |
|------------|----------|----------|----------|
| zqdm | 2102 | stock_code | - |
| zqmc | 2103 | stock_name | - |
| gdzh | 2106 | stock_account | - |
| jys | 2108 | exchange_type | map_replace |
| czlb | 2109 | business_name | - |
| gp_ye | 2117 | hold_amount | - |
| gp_djsl | 2118 | freeze_amount | - |
| gp_kysl | 2121 | enable_amount | - |
| gp_mrjg | 2122 | avg_price | - |
| gp_sz | 2125 | market_value | - |
| gp_wtsl | 2126 | entrust_amount | - |
| gp_wtjg | 2127 | entrust_price | - |
| gp_cjsl | 2128 | business_amount | - |
| gp_cjjg | 2129 | business_price | - |
| gp_cjbh | 2130 | report_no | - |
| gp_cjje | 2131 | business_balance | - |
| htbh | 2135 | contract_id | - |
| cj_rq | 2141 | business_date | - |
| cj_sj | 2142 | business_time | change_time |
| wt_sj | 2140 | entrust_time | change_time |
| status | - | entrust_status | map_replace(g_gt_orderstatus) |
| scmc | - | exchange_type | map_replace(g_gt_market_name) |
