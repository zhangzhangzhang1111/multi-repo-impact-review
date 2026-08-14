# pre_handle 处理规则

## 1. 概述

pre_handle 是 jmodel.lua 中的请求转换模块，负责将**客户端请求参数**转换为**柜台请求参数**。

```
客户端请求(askdata) → pre_handle转换 → 柜台请求(req) → 调用柜台API
```

## 2. 配置结构

pre_handle 是一个 key-value 映射表：

```lua
pre_handle = {
    -- 静态值
    ['柜台参数名'] = '静态值',

    -- 动态映射
    ['柜台参数名'] = {
        field = '客户端字段名',   -- 从客户端请求获取值
        def = '默认值',            -- 客户端未提供时的默认值
        change = function(v, userinfo, askdata, replydata)
            -- 转换逻辑
            return 转换后的值
        end
    }
}
```

## 3. 配置类型

### 3.1 静态值

```lua
pre_handle = {
    ['market'] = '',           -- 直接使用空字符串
    ['position_str'] = '0',    -- 直接使用 '0'
}
```

### 3.2 字段映射

从客户端请求获取值：
```lua
pre_handle = {
    -- 从 askdata 获取 'SETCODE' 字段
    ['exchange_type'] = {field = 'SETCODE'},
}
```

### 3.3 带默认值的字段映射

```lua
pre_handle = {
    -- 如果 askdata 没有 'qsrq'，使用空字符串
    ['start_date'] = {def = '', field = 'qsrq'},
}
```

### 3.4 带转换函数的映射

```lua
pre_handle = {
    -- 客户端 'SETCODE' 转换为柜台格式
    ['exchange_type'] = {
        field = 'SETCODE',
        change = map_replace(g_hx_sc_2_gt)  -- 市场代码转换
    },

    -- 自定义转换逻辑
    ['client_id'] = {
        def = '',
        field = 'GDZH',
        change = function(v, userinfo, askdata)
            local rzrq = askdata:getdata('rzrq') or '';
            if rzrq == '1' then
                return userinfo:getdata('rzrq_clientid') or v;
            else
                return userinfo:getdata('u_client_id') or v;
            end
        end
    }
}
```

## 4. 特殊配置

### 4.1 自建数据

```lua
pre_handle = {
    ['_USE_SELF_DATA_'] = '1',
    ['_SELF_DATA_'] = {{'index'}, {'1'}},  -- 返回固定数据
}
```

### 4.2 HTTP通达信格式

```lua
pre_handle = {
    ['Bind_Http_Tdx'] = '1',  -- 使用HTTP通达信格式
}
```

### 4.3 缓存设置

```lua
pre_handle = {
    [CACHESET] = {def='', name='缓存名称', time=60},  -- 缓存60分钟
}
```

## 5. 常见字段转换示例

以下取值来自部分 `hsarapi` 项目，只用于定位候选映射表，不是所有 Transmid 项目的通用协议。

### 5.1 市场代码转换 (g_hx_sc_2_gt)

| 客户端值 | 恒生柜台值 | 说明 |
|----------|------------|------|
| 1 | 0 | 深市A股 |
| 2 | 1 | 沪市A股 |
| 4 | 2 | 深市B股 |
| 5 | 3 | 沪市B股 |
| 8 | 8 | 港股通 |
| 9 | 9 | 申购 |

**代码示例**：
```lua
-- config.lua 中的映射表
g_gt_sc_2_hx = {
    [SZAG] = '1',  -- 深市A股 -> 1
    [SHAG] = '2',  -- 沪市A股 -> 2
    [SZBG] = '4',  -- 深市B股 -> 4
    [SHBG] = '5',  -- 沪市B股 -> 5
    [HGT] = '8',   -- 港股通 -> 8
    [SG] = '9',    -- 申购 -> 9
};
g_hx_sc_2_gt = map_reverse(g_gt_sc_2_hx);  -- 反转
```

### 5.2 币种转换 (g_hx_sc_2_gt_bz)

| 市场代码 | 币种值 |
|----------|--------|
| 4(深B) | 1(港元) |
| 5(沪B) | 2(美元) |
| 9(申购) | 0(人民币) |

### 5.3 日期处理

```lua
-- 起始日期处理：当日查询默认今天，有范围限制
['start_date'] = {
    def = '',
    field = 'qsrq',
    change = function(v, u, ask)
        local lstartdate = v;
        if v == '0' or v == nil or v == '' then
            lstartdate = os.date('%Y%m%d');  -- 默认今天
        else
            local lenddate = ask:getdata('zzrq') or ask:getdata('jzrq');
            local lis_out_day = is_out_max_day(lstartdate, lenddate, maxDays);
            if lis_out_day == 0 then
                lstartdate = getDate_ex(lenddate, maxDays);  -- 超过限制则取限制日期
            end
        end
        return lstartdate;
    end
}
```

### 5.4 客户ID处理

```lua
-- 根据是否融资融券选择不同的客户ID
['client_id'] = {
    def = '',
    field = 'GDZH',
    change = function(v, userinfo, askdata)
        local rzrq = askdata:getdata('rzrq') or '';
        if rzrq == '1' then
            return userinfo:getdata('rzrq_clientid') or v;  -- 融资融券客户ID
        else
            return userinfo:getdata('u_client_id') or v;    -- 普通客户ID
        end
    end
}
```

### 5.5 分页处理

```lua
['request_num'] = {
    def = '',
    change = function(v, userinfo, askdata, replydata)
        if askdata:getdata('page_roll') == '1' then
            return 200;  -- 分页每页200条
        end
        return 2000;     -- 默认最多2000条
    end
}
```

## 6. 不同柜台的差异

### 6.1 恒生 (HS)

- 使用 `g_hx_sc_2_gt` 映射表
- 市场代码：0/1/2/3/8/9

### 6.2 金正W

- 类似恒生格式，可能需要重新映射
- 需要查看具体项目的 config 配置

### 6.3 金正U

- 可能使用不同的市场代码体系
- 需要检查对应的映射表

### 6.4 顶点

- 通常有自己的市场代码体系
- 需要单独配置映射表

## 7. 辅助函数

### map_replace(table)
将值通过映射表转换：
```lua
['exchange_type'] = {field='SETCODE', change=map_replace(g_hx_sc_2_gt)}
```

### map_find(table, key)
反向查找：
```lua
change = function(v) return map_find(g_hx_sc_2_gt, v) or '' end
```

## 8. 调试技巧

1. 查看日志：`show_log(2, ...)` 输出 pre_handle 转换结果
2. 断点调试：在 HandlePreHandle 函数中添加打印
3. 对比请求：比较客户端请求和生成的柜台请求

---

# 规则定义示例

## 字段映射规则

```json
{
    "字段名": {
        "type": "field|static|change",
        "source_field": "客户端字段名",
        "target_field": "柜台字段名",
        "default": "默认值",
        "mapping_table": "映射表名",
        "change_function": "函数名"
    }
}
```

## 市场代码映射

```json
{
    "g_hx_sc_2_gt": {
        "0": "深市A股",
        "1": "沪市A股",
        "2": "深市B股",
        "3": "沪市B股",
        "8": "港股通",
        "9": "申购"
    }
}
```
