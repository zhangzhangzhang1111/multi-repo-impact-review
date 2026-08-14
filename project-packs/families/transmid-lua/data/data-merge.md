# Transmid 数据合并规则

## 概述

在已知 Transmid 项目中，常见数据合并至少有两种候选类型；目标项目可能存在其他包装或覆盖逻辑：
1. **分页合并** - 单表数据量过大时分多次查询合并
2. **多表合并** - 不同数据源的结果合并（如 A股 + 港股通）

---

## 1. 分页合并 (Combine_Data)

### 触发条件

- 数据量达到目标项目配置的单次查询上限（部分示例使用 `max_query_count = 10000`，必须以当前源码为准）
- 柜台返回 `position_str` 分页定位符

### 处理逻辑

```
1. 设置 request_num = 最大查询数
2. 执行首次查询
3. 检查返回数据条数：
   - < 最大查询数 → 查询完成，退出循环
   - = 最大查询数 → 可能有更多数据，继续
4. 获取 position_str（分页定位符）
5. 带入 position_str 再次查询
6. 循环直到数据查完
7. 合并所有结果返回
```

### 代码特征

```lua
-- 必有 Combine_Data 调用
Combine_Data(Query_XXX)(userinfo, askdata, replydata, dorequest);

-- 或在 _special_handle 中注册
['_tmp_Query_XXX'] = UpdateDefRequest(Query_XXX, true),
```

### 查找方法

1. 搜索 `Combine_Data(` 获取所有分页合并的查询
2. 查看对应 `Query_XXX` 的 `table_handle` 配置

---

## 2. 多表合并 (CombineTwoTable)

### 触发条件

- 用户拥有多个市场的交易权限
- 需要同时查询多个数据源并合并结果

### 常见场景

| 场景 | 合并的表 |
|------|---------|
| 港股通 | A股成交 + 港股通成交 |
| 沪港通 | A股持仓 + 沪股通持仓 |
| 融资融券 | 普通持仓 + 融资融券持仓 |

### 处理逻辑

```
1. 检查用户权限字段（如 Have_Hgtzh, Have_Sgtzh）
2. 判断是否需要合并（如 u_ptgp_sptggt）
3. 调用 CombineTwoTable(tb1, tb2)
4. tb1 先执行查询，结果保存
5. tb2 执行查询，结果追加到 tb1
6. 合并返回
```

### 代码特征

```lua
-- 必有权限判断
local hgt_qx = userinfo:getdata("Have_Hgtzh") or "";
local sgt_qx = userinfo:getdata("Have_Sgtzh") or "";

if (hgt_qx == "1" or sgt_qx == "1") and userinfo:getdata("u_ptgp_sptggt") == "1" then
    return CombineTwoTable(userinfo, askdata, replydata, dorequest, 表1, 表2);
end
```

### 查找方法

1. 搜索 `CombineTwoTable` 获取所有多表合并
2. 向上查找权限判断逻辑
3. 确定需要合并的数据源

---

## 3. 常见权限字段候选

### 港股通权限

| 字段 | 说明 |
|------|------|
| Have_Hgtzh | 沪港通账号 (1=有) |
| Have_Sgtzh | 深港通账号 (1=有) |
| u_ptgp_sptggt | 港股通是否开通 (1=开通) |

### 其他常见权限

| 字段 | 说明 |
|------|------|
| Have_JJZH | 基金账号 |
| Have_RZRQ | 融资融券 |
| u_rzrq_zjzh | 融资融券资金账号 |

---

## 4. 分析步骤

### Step 1: 找到入口函数

搜索命令映射：
```lua
['T-2'] = Query_ChengjiaoMain,  -- 当日成交
```

### Step 2: 分析处理逻辑

查看函数内是否有：
- `Combine_Data()` → 分页合并
- `CombineTwoTable()` → 多表合并
- 权限判断 → 多数据源合并

### Step 3: 确定合并内容

- 分页合并：查看 `Query_XXX` 的 table_handle
- 多表合并：查看 CombineTwoTable 的两个参数

### Step 4: 追踪字段映射

- 字段ID定义在 `defines_*.lua`
- 字段映射在 `table_handle.handle`

---

## 5. 常见命令的合并逻辑

### 持仓查询 (T-1)

| 项目 | 处理方式 |
|------|---------|
| 普通A股 | Combine_Data 分页合并 |
| 融资融券 | 可能合并融资持仓 + 融券持仓 |
| 港股通 | 可能合并A股持仓 + 港股通持仓 |

### 当日委托 (L-0 / T-3)

| 项目 | 处理方式 |
|------|---------|
| 普通A股 | Combine_Data 分页合并 |
| 港股通 | CombineTwoTable(A股委托 + 港股通委托) |

### 当日成交 (T-2)

| 项目 | 处理方式 |
|------|---------|
| 普通A股 | Combine_Data 分页合并 |
| 港股通 | CombineTwoTable(A股成交 + 港股通成交) |
| 基金 | 单独查询基金成交 |

---

## 6. 验证方法

### 分页合并验证

1. 确认 `position_str` 字段有返回
2. 确认多次查询结果条数累加正确
3. 确认无重复数据

### 多表合并验证

1. 分别查询各数据源
2. 验证合并后条数 = 各数据源之和
3. 验证字段来源正确
4. 验证权限判断逻辑

---

## 7. 示例：东莞证券 T-2 分析

### 入口
```lua
['T-2'] = Query_ChengjiaoMain,
```

### 处理函数逻辑
```lua
local function Query_ChengjiaoMain(userinfo, askdata, replydata, dorequest)
    -- 1. 基金(J开头) → 单独查基金
    if string.getat(zqdm, 1) == 'J' then
        return HandleNormalRequest(..., Jjcf_Req.query_chengjiao);
    end

    -- 2. 港股通权限判断
    local hgt_qx = userinfo:getdata("Have_Hgtzh") or "";
    local sgt_qx = userinfo:getdata("Have_Sgtzh") or "";
    if (hgt_qx == "1" or sgt_qx == "1") and userinfo:getdata("u_ptgp_sptggt") == "1" then
        -- 合并：A股 + 港股通
        return CombineTwoTable(..., Query_Chengjiao, Ggt_Req.query_drcj);
    end

    -- 3. 普通A股
    Combine_Data(Query_Chengjiao)(...);
end
```

### 结论

| 场景 | 合并类型 | 说明 |
|------|---------|------|
| 基金 | 无 | 单独查询 |
| 有港股通权限 | 多表合并 | A股成交 + 港股通成交 |
| 普通A股 | 分页合并 | Combine_Data |
