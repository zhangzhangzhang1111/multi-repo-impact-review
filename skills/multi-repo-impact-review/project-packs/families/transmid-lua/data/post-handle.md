# post_handle 处理规则

## 1. 概述

post_handle 是 jmodel.lua 中的**结果转换模块**，负责将**柜台返回的单条数据**（非列表）转换为**返回给客户端的字段**。

```
柜台返回(ans) → post_handle转换 → 返回客户端(replydata)
```

**与 table_handle 的区别：**
- `table_handle`: 处理**列表数据**（多行），如持仓、成交委托列表
- `post_handle`: 处理**单条数据**，如登录结果、委托提交结果

## 2. 配置结构

```lua
post_handle = {
    -- 静态值：直接设置返回字段
    ['返回字段名'] = '静态值',

    -- 字段映射：从柜台结果获取值
    ['返回字段名'] = {field = '柜台字段名'},

    -- 带默认值：从柜台结果获取，无值时使用默认值
    ['返回字段名'] = {field = '柜台字段名', def = '默认值'},

    -- 带转换函数：对值进行转换后返回
    ['返回字段名'] = {
        field = '柜台字段名',
        def = '默认值',
        change = function(v, ans, userinfo, askdata, replydata)
            -- v: 原始值
            -- ans: 柜台返回的完整数据表
            -- userinfo: 用户信息对象
            -- askdata: 客户端请求数据
            -- replydata: 返回数据对象
            return 转换后的值
        end
    }
}
```

## 3. 处理流程 (HandlePostHandle)

```
1. 遍历 post_handle 配置中的每个映射(k, v)
2. 调用 ReplaceData(ans, v, userinfo, askdata, replydata) 获取值
   a. 从 ans[cfg.field] 获取柜台字段值
   b. 使用默认值: _value = _value or cfg.def
   c. 应用转换函数: cfg.change(_value, ans, userinfo, askdata, replydata)
3. 将结果设置到 replydata: replydata:setdata(k, _value)
```

**示例快照调用位置** (`jmodel.lua:721`，目标项目行号可能不同)：
```lua
-- 在 table_handle 处理之后执行
local _ans = chg2table(_result, nItem);
HandlePostHandle(_ans, handle_config.post_handle, userinfo, askdata, replydata);
HandleExtendRequest(_ans, handle_config.extend_handle, userinfo, askdata, replydata);
HandleUserinfoHandle(_ans, handle_config.userinfo_handle, userinfo, askdata, replydata);
```

## 4. ReplaceData 函数详解

**示例快照函数签名** (`jmodel.lua:360`，目标项目行号可能不同):
```lua
local function ReplaceData(ans, cfg, userinfo, askdata, replydata)
```

**处理逻辑**：
1. 如果 cfg 不是 table，直接返回 cfg（静态值）
2. 如果 cfg 有 field 属性，从 ans[cfg.field] 获取值
3. 应用默认值：`_value = _value or cfg.def`
4. 如果有 change 函数，执行转换：`cfg.change(_value, ans, userinfo, askdata, replydata)`

**change 函数参数**：
| 参数 | 含义 |
|------|------|
| v | 原始值（可能为 nil） |
| ans | 柜台返回的完整数据（table） |
| userinfo | 用户信息对象 |
| askdata | 客户端请求数据 |
| replydata | 返回数据对象 |

## 5. 配置示例

### 5.1 静态值

```lua
post_handle = {
    ['ANSTYPE'] = '1',   -- 返回数据类型：1=有数据
    ['EXTEND'] = '3',   -- 扩展数据版本
}
```

### 5.2 字段映射

```lua
post_handle = {
    ['HTBH'] = {field = 'entrust_no'},      -- 合同编号
    ['GDZH'] = {field = 'stock_account'},   -- 股东账户
}
```

### 5.3 带转换函数

```lua
post_handle = {
    -- ANSTYPE 根据 error_no 动态决定
    ['ANSTYPE'] = {
        def = '',
        field = 'error_no',
        change = function(v)
            if v == '' or v == '0' or v == nil then
                return '1';  -- 成功
            end
            return '0';      -- 失败
        end
    },

    -- HTBH 组合多个字段
    ['HTBH'] = {
        field = 'entrust_count',
        change = function(v, ans, userinfo, askdata, replydata)
            local ret = v or '';
            ret = ret .. ';' .. (ans['entrust_amount'] or '');
            return ret;
        end
    },

    -- 柜台字段经过映射表转换
    ['scdm'] = {
        def = '',
        field = 'exchange_type',
        change = map_replace(g_gt_sc_2_hx)  -- 柜台→客户端市场代码
    },
}
```

### 5.4 复杂业务逻辑

```lua
post_handle = {
    -- 根据 askdata 决定返回哪个字段
    ['sgdm'] = {
        def = '',
        field = 'stock_code',
        change = function(v, ans, userinfo, askdata, replydata)
            if v == nil or string.len(v) <= 0 then
                return askdata:getdata('GDXM');  -- 兜底取客户姓名
            end
            return v;
        end
    },

    -- 动态计算返回值
    ['rzrq_wcdbbl'] = {
        def = '',
        field = 'per_assurescale_value',
        change = function(v, userinfo, askdata)
            -- 业务逻辑处理
            return tonumber(v) * 100;
        end
    },
}
```

## 6. 相关配置对比

### 6.1 post_handle vs userinfo_handle vs extend_handle

| 配置 | 作用 | 目标对象 |
|------|------|----------|
| post_handle | 转换结果数据 | replydata（返回给客户端） |
| userinfo_handle | 保存用户信息 | userinfo（缓存用户状态） |
| extend_handle | 扩展数据 | replydata.T_ADD_DATA（附加返回） |

### 6.2 示例处理顺序 (`jmodel.lua:718-735`，必须由目标项目确认)

```
1. table_handle    → 处理列表数据，填充 replydata
2. post_handle     → 处理单条结果，设置 replydata 字段
3. extend_handle   → 添加扩展数据到 replydata.T_ADD_DATA
4. userinfo_handle → 保存用户信息到 userinfo
5. extern_data_handle → 处理扩展数据字段
```

### 6.3 常用返回字段

| 字段 | 含义 | 常见值 |
|------|------|--------|
| ANSTYPE | 返回数据类型 | '0'=无数据, '1'=有数据 |
| EXTEND | 扩展数据版本 | '1','2','3','4' |
| HTBH | 合同编号 | 委托成功后返回 |
| retcode | 返回代码 | '0'=成功, '1'=失败 |
| retmsg | 返回消息 | 成功/失败描述 |
| CWXX | 错误信息 | 错误详情 |

## 7. 调试技巧

1. 启用调试：`show_debug = true`
2. 查看日志输出中的 `HandlePostHandle=xxx` 时间统计
3. 在 `HandlePostHandle` 函数中添加打印：
   ```lua
   show_log(2, 'post_handle key=' .. k .. ' value=' .. tostring(_value));
   ```

## 8. 完整配置示例

### 登录结果返回

```lua
post_handle = {
    ['ANSTYPE'] = '1',
    ['EXTEND'] = '3',
    ['u_zjzh'] = {def='', field='fund_account'},      -- 资金账号
    ['yhmc'] = {def='', field='client_name'},         -- 客户名称
    ['u_client_id'] = {def='', field='client_id'},    -- 客户ID
    ['u_client_right'] = {def='', field='client_rights'}, -- 客户权限
}
```

### 委托提交返回

```lua
post_handle = {
    ['HTBH'] = {field = 'entrust_no'},
    ['ANSTYPE'] = {def = '', field = 'error_no', change = function(v)
        if v == '' or v == '0' or v == nil then
            return '1';
        end
        return '0';
    end},
    ['CWXX'] = {def = '', field = 'error_info'},
}
```

### ETF申购返回

```lua
post_handle = {
    ['sgdm'] = {def='', field='stock_code', change=function(v, ans, userinfo, askdata, replydata)
        if v == nil or string.len(v) <= 0 then
            return askdata:getdata('GDXM');
        end
        return v;
    end},
    ['scdm'] = {def='', field='exchange_type', change=map_replace(g_gt_sc_2_hx)},
    ['EXTEND'] = '3',
    ['ANSTYPE'] = '1',
}
```

---

# extend_handle 处理规则

## 1. 概述

extend_handle 用于添加**扩展数据**到返回结果，格式为 `key=value` 对。

## 2. 配置结构

```lua
extend_handle = {
    ['_model'] = '4',           -- 扩展数据模型：4=长整型前缀
    ['retcode'] = '1',          -- 返回代码
    ['retmsg'] = '操作成功',     -- 返回消息
    ['htbh'] = {field = 'entrust_no'},  -- 动态获取
    ['自定义字段'] = {def='', change=function(v, ans, userinfo, askdata, replydata)
        return 计算值;
    end},
}
```

## 3. 特殊字段

| 字段 | 作用 |
|------|------|
| `_model` | 数据模型：空=普通, '4'=长整型前缀, '5'=禁用 |
| `_save_old_data_` | 控制替换或追加；不同快照的注释存在歧义，必须读取目标 `HandleExtendRequest` 确认 `'0'` 的实际语义 |

## 4. 输出格式

最终输出到 `replydata.T_ADD_DATA`，格式：
```
key1=value1
key2=value2
...
```

---

# extend_handle 处理规则（补充）

## 1. 概述

extend_handle 用于添加**扩展数据**到返回结果，输出到 `replydata.T_ADD_DATA`。

**与 post_handle 的区别：**
- post_handle: 设置 replydata 的单个字段，如 `replydata:setdata('HTBH', value)`
- extend_handle: 追加格式化的扩展数据块到 T_ADD_DATA

## 2. 处理流程 (HandleExtendRequest)

```
1. 遍历 extend_handle 配置中的每个映射(k, v)
2. 特殊处理 _model 字段：控制数据格式
3. 调用 ReplaceData 获取值
4. 格式化为 key=value，插入 _data 表
5. 拼接所有数据：table.concat(_data, '\n')
6. 根据 _model 决定是否添加长度前缀
7. 追加或替换到 replydata.T_ADD_DATA
```

**代码位置**: jmodel.lua:434-469

## 3. 完整配置结构

```lua
extend_handle = {
    -- 特殊字段
    ['_model'] = '4',                -- 数据模型：空=普通, '4'=长整型前缀, '5'=禁用
    ['_save_old_data_'] = '0',      -- 示例值；替换/追加语义以目标 HandleExtendRequest 为准

    -- 静态值
    ['retcode'] = '1',              -- 返回代码
    ['retmsg'] = '操作成功',         -- 返回消息
    ['htbh'] = '12345',             -- 合同编号

    -- 动态字段
    ['htbh'] = {field = 'entrust_no'},  -- 从柜台结果获取
    ['huilv'] = {def = '', field = 'exchange_rate', change = function(v, ans, userinfo, askdata, replydata)
        -- 自定义转换逻辑
        if askdata:getdata('czlb') == 'B' then
            return v;
        else
            return ans['buy_rate'];
        end
    end},
}
```

## 4. _model 参数详解

| _model 值 | 格式 | 说明 |
|-----------|------|------|
| 空/无 | `key=value\n...` | 普通格式 |
| '4' | `[4位长度][数据]` | 长整型前缀格式 |
| '5' | 禁用 | 不输出扩展数据 |

**长整型前缀格式** (model='4'):
```lua
local _len = ChangeLong2String(#_extend + 4);
_extend = _len .. _extend;  -- 前4位为数据长度
```

## 5. 输出格式示例

**普通格式** (model 为空):
```
retcode=1
retmsg=操作成功
htbh=123456
```

**长整型格式** (model='4'):
```
0023
retcode=1
retmsg=操作成功
htbh=123456
```

## 6. 配置示例

### 6.1 港股通买入返回

```lua
extend_handle = {
    ['retcode'] = '1',
    ['_model'] = _D('E_model'),     -- 使用配置值
    ['huilv'] = {def = '', field = 'sell_exchange_rate', change = function(v, ans, userinfo, askdata, replydata)
        if askdata:getdata('czlb') == 'B' then
            return v;
        else
            return ans['buy_exchange_rate'];
        end
    end},
    ['kjje'] = {def='', field = 'entrust_amount'},
    ['jjje'] = {def='', field = 'entrust_balance'},
}
```

### 6.2 港股通额度查询

```lua
extend_handle = {
    ['retcode'] = '1',
    ['_model'] = _D('E_model'),
    ['csed'] = {def = '', field = 'total_quota'},        -- 初始额度
    ['dred'] = {def = '', field = 'surplus_quota'},       -- 剩余额度
    ['edzt'] = {def = '', field = 'hkquota_status', change = map_replace(g_ggt_edzt)},  -- 额度状态
}
```

### 6.3 弹窗确认框

```lua
extend_handle = {
    ['retcode'] = '1',
    ['show_yesno'] = '1',           -- 显示确认对话框
    ['yes_text'] = '确认',
    ['no_text'] = '取消',
    ['retmsg'] = '[H100]该股票已经停牌，是否继续？',
}
```

---

# extern_data_handle 处理规则

## 1. 概述

extern_data_handle 是**扩展数据字段**处理模块，用于生成结构化的扩展数据字符串，输出到 `replydata.extend_data`。

**与 extend_handle 的区别：**
- extend_handle: 输出到 T_ADD_DATA（追加式）
- extern_data_handle: 输出到 extend_data（结构化格式：`EX=版本&EXL=长度&数据`）

## 2. 处理流程 (HandleExtendDataRequest)

```
1. 检查 EX 字段（必填），版本号需 >= 2.0 且 < 3.0
2. 临时移除 EX 字段，处理其他配置
3. 遍历配置获取所有字段值
4. 处理特殊字段 save_old_extern_data
5. 拼接数据：table.concat(_data, '&')
6. 恢复 EX 字段
7. 格式化输出：EX=版本&EXL=长度&数据
8. 设置到 replydata.extend_data
```

**代码位置**: jmodel.lua:485-518

## 3. 配置结构

```lua
extern_data_handle = {
    ['EX'] = '2.0',                 -- 必填：扩展数据版本 (2.0 <= EX < 3.0)

    -- 可选：是否保留旧数据
    ['save_old_extern_data'] = '1', -- '1'=保留，追加模式

    -- 扩展字段
    ['retcode'] = '0',              -- 返回代码
    ['retmsg'] = '操作成功',         -- 返回消息
    ['show_yesno'] = '1',           -- 是否显示对话框
    ['yes_text'] = '确认',           -- 是按钮文字
    ['no_text'] = '取消',            -- 否按钮文字

    -- 动态字段
    ['自定义字段'] = {field = '柜台字段'},
    ['instr_batch_no'] = {
        def = '',
        field = 'instr_batch_no',
        change = function(v, ans, userinfo, askdata, replydata)
            return 处理逻辑;
        end
    },
}
```

## 4. EX 版本与数据格式

| EX 版本 | 格式 | 说明 |
|---------|------|------|
| 2.0 - 2.9 | `EX=版本&EXL=长度&字段1=值1&字段2=值2...` | 标准扩展格式 |
| < 2.0 | 不处理 | 版本过低 |
| >= 3.0 | 不处理 | 版本过高 |

**EXL 计算**: 数据部分长度 + 17（固定偏移）

## 5. 输出格式

```
EX=2.0&EXL=00041&retcode=0&retmsg=操作成功&自定义字段=值
```

- EX: 版本号
- EXL: 5位数字，整个数据长度（包含 EX 和 EXL 本身）
- 后续: 字段以 & 分隔

## 6. 特殊字段说明

| 字段 | 说明 |
|------|------|
| EX | **必填**，版本号，必须 >= 2.0 |
| save_old_extern_data | '1'=保留之前的数据，追加模式 |
| show_yesno | '1'=显示确认对话框 |
| yes_text | 对话框确认按钮文字 |
| no_text | 对话框取消按钮文字 |

## 7. 配置示例

### 7.1 简单返回

```lua
extern_data_handle = {
    ['EX'] = '2.0',
    ['retcode'] = '0',
    ['retmsg'] = '您的请求已提交，请注意查收短信通知。感谢您的使用！';
};
```

### 7.2 适当性管理提示

```lua
extern_data_handle = {
    ['EX'] = '2.0',
    ['retcode'] = '0',
    ['ydsqs'] = '0',
    ['retmsg'] = '尊敬的投资者：您尚未完成适当性评估，无法参与科创板交易。感谢您的理解！';
};
```

### 7.3 弹窗确认（港股通）

```lua
extern_data_handle = {
    ['EX'] = '2.0',
    ['show_yesno'] = '1',
    ['yes_text'] = '确认',
    ['no_text'] = '取消',
    ['retmsg'] = '[H100]该股票已停牌，是否继续？当前状态:' .. replydata:getdata('notice_info'),
};
```

### 7.4 动态字段（基金定投）

```lua
extern_data_handle = {
    ['EX'] = '2.0',
    ['retcode'] = '0',
    ['instr_batch_no'] = {
        def = '',
        field = 'instr_batch_no',
        change = function(v, ans, userinfo, askdata, replydata)
            return 'BATCH_' .. os.date('%Y%m%d%H%M%S');
        end
    },
    ['retmsg'] = '定投计划已提交',
};
```

### 7.5 追加模式

```lua
extern_data_handle = {
    ['EX'] = '2.0',
    ['save_old_extern_data'] = '1',  -- 保留旧数据
    ['retcode'] = '0',
    ['new_field'] = '新字段值',
};
```

## 8. 处理顺序（完整链路）

```
HandleNormalRequest()
  ├─> 柜台API调用
  ├─> FilterResult()              -- 过滤结果
  ├─> HandleMultiQueryTable()     -- table_handle: 处理列表数据
  ├─> HandlePostHandle()          -- post_handle: 设置返回字段
  ├─> HandleExtendRequest()       -- extend_handle: T_ADD_DATA 扩展数据
  ├─> HandleUserinfoHandle()      -- userinfo_handle: 保存用户信息
  └─> HandleExtendDataRequest()   -- extern_data_handle: extend_data 扩展字段
```

---

# userinfo_handle 处理规则

## 1. 概述

userinfo_handle 用于将柜台返回的数据**保存到用户信息对象**，供后续请求使用。

## 2. 配置示例

```lua
userinfo_handle = {
    ['u_zjzh'] = {def='', field='fund_account'},      -- 资金账号
    ['yhmc'] = {def='', field='client_name'},         -- 客户名称
    ['u_client_id'] = {def='', field='client_id'},    -- 客户ID
    ['u_branch_no'] = {def='', field='branch_no'},    -- 营业部
    ['u_mac'] = {def='', change=function(v, ans, userinfo, askdata)
        local hwcode = askdata:getdata('hardwarecode') or '';
        local _,_,mac = string.find(hwcode,'MAC:([^,]+)');
        return mac or ''
    end},
}
```

## 3. 使用场景

- 登录成功后保存客户信息
- 保存账户相关数据供后续请求使用
- 缓存用户配置信息
