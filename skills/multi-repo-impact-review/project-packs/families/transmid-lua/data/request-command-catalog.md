# Transmid Command Catalog

Use this catalog only as a static candidate list for common Transmid client request commands and business meanings.

This file is not exhaustive across every broker adapter and optional module. If a command or Chinese feature name is absent, treat the target project code as the complete runtime catalog: search `g_all_request_handle_config`, `g_special_handle_request`, module-level `g_*_request_handle_config` tables, and `AddBussinessModule` registrations before deciding whether the command is new.

`*` in command keys means wildcard matching in code. It can match multiple completed request keys after command normalization, so inspect sibling commands before changing wildcard handlers.

## Request Key Basics

Full command shape:

```text
[moneytype][REQTYPE]-[MMLB][history]-[cmd]-[extend]
```

Common `REQTYPE` meanings:

| REQTYPE | Meaning |
|---|---|
| `1` | 登录/验证密码 |
| `3` | 委托/下单 |
| `4` | 撤单 |
| `5` | 查询资金 |
| `C` | 查询可委托数量 |
| `E` | 场内基金 |
| `F` | 场外基金 |
| `J` | 基金交易 |
| `L` | 扩展请求 |
| `T` | 标准查询请求 |
| `I` | 资金调拨/银证转账 |

## 普通请求

| 请求 cmd | 业务含义 |
| --- | --- |
| `INIT` | 普通启动时初始化 |
| `1` | 普通校验用户 |
| `2` | 普通修改交易密码 |
| `3` | 普通买卖委托 |
| `4` | 普通委托撤单 |
| `5` | 普通查询资金 |
| `V` | 普通修改资金密码/转账密码 |
| `S` | 普通用户退出 |
| `B` | 普通查询证券行情 |
| `C` | 普通查询可买/卖数量 |
| `U` | 普通查询银行资金 |
| `E` | 普通银行转券商 |
| `F` | 普通券商转银行 |
| `T-1` / `T-1*` | 普通查询持仓 |
| `T-2` | 普通查询当日成交 |
| `T-2H` | 普通查询历史成交 |
| `T-3` | 普通查询当日委托 |
| `T-3H` | 普通查询历史委托 |
| `T-4*` | 普通查询银行 |
| `T-5*` | 普通查询股东账号/账号 |
| `T-6H` | 普通查询交割单 |
| `T-7*` | 普通查询交割单/清仓 |
| `T-8` / `T-8*` | 普通查询资金明细 |
| `T-8H` | 普通查询历史资金明细 |
| `T-9` | 普通查询证券流水 |
| `T-I*` | 查询未到期回购 |
| `T-o` | 查询要约代码 |
| `T-p` | 查询要约股东编号 |
| `T-=` | 普通查询银行流水 |
| `T-=H` | 普通查询银行历史流水 |
| `T-<*` | 普通查询配号 |
| `T-q*` | 普通查询中签 |
| `T-;*` | 查询资产总值 |
| `T-R*` | 查询所有资金 |
| `T-Y*` | 查询债券质押 |
| `L-0-get_wtcl_list` | 普通获取委托策略 |
| `L-0-ajax_pkg` | 普通 ajax 请求页面 |

## 新股/配售

| 请求 cmd | 业务含义 |
| --- | --- |
| `L-0-cx_xginfo` | 查询新股信息 |
| `L-0-cx_xgsg` | 查询新股申购信息 |
| `L-0-query_psqy` | 查询配售权益 |
| `L-0-cx_kh_psqy` | 查询配售权益（手机） |
| `L-0-Query_IPO` | 查询配售缴款信息 |
| `L-0-rzrq_cx_ph` / `L-:*-rzrq_cx_ph` | 查询融资融券配号 |
| `L-0-rzrq_cx_zq` / `L-0-query_rzrq_zq` / `L-:*-rzrq_cx_zq` | 查询融资融券中签 |
| `L-0-query_rzrq_psqy` | 查询融资融券配售权益 |
| `L-:-Rzrq_Query_IPO` / `L-0-Rzrq_Query_IPO` | 查询配售缴款信息 |
| `L-0-xgsg_fqrg` | 新股申购放弃认购 |
| `L-:-xgsg_fqrg` | 融资融券新股申购放弃认购 |

## 融资融券

| 请求 cmd | 业务含义 |
| --- | --- |
| `L-:-rzrq_khjy` | 融资融券客户校验 |
| `L-:-cx_wtsl` / `L-0-cx_wtsl` | 查询委托数量 |
| `L-:-rzrq_mairu` | 信用买入 |
| `L-:-rzrq_maichu` | 信用卖出 |
| `L-:-rzrq_mqhk` | 卖券还款 |
| `L-:-rzrq_mqhq` | 买券还券 |
| `L-:-rzrq_rzmq` | 融资买券 |
| `L-:-rzrq_rqmc` | 融券卖出 |
| `L-:-rzrq_zjhk` | 直接还款 |
| `L-:-rzrq_zjhq` | 直接还券（还券划转） |
| `L-:-rzrq_cd` | 撤单 |
| `L-:*-rzrq_cxdbp` | 查询担保品 |
| `L-:-rzrq_dbphz` | 担保品划转 |
| `L-:-rzrq_cxzj` | 查询资金 |
| `L-:-rzrq_cxgp` | 查询持仓 |
| `L-:*-rzrq_cxmrbdq` | 查询可融资买入标的券 |
| `L-:*-rzrq_cxmcbdq` | 查询可融券卖出标的券 |
| `L-:*-rzrq_cxrzfz` | 查询融资负债 |
| `L-:*-rzrq_cxrqfz` | 查询融券负债 |
| `L-:-rzrq_cxwt` | 查询当日委托 |
| `L-:H-rzrq_cxwt` | 查询历史委托 |
| `L-:-rzrq_cxcj` | 查询当日成交 |
| `L-:H-rzrq_cxcj` | 查询历史成交 |
| `L-:-rzrq_cx_fzhzxx` | 查询负债汇总信息 |
| `L-:*-rzrq_cxzjls` | 查询资金流水 |
| `L-:*-rzrq_cxjgd` | 查询交割单 |
| `L-:*-rzrq_cxhzls` | 查询划转流水 |
| `L-:-rzrq_dbphzcd` | 担保品划转撤单 |
| `L-:-rzrq_cxdbphz` | 查询担保品划转 |
| `L-:-rzrq_xgmm` | 修改密码 |
| `L-:*-rzrq_cx_rzfzddmx` | 融资负债订单明细 |
| `L-:*-rzrq_cx_rqfzddmx` | 融券负债订单明细 |
| `L-:*-rzrq_cx_fzdbls` | 查询负债变动流水 |
| `L-:*-rzrq_cx_ychrzfzmx` | 查询已偿还融资负债明细 |
| `L-:*-rzrq_cx_ychrqfzmx` | 查询已偿还融券负债明细 |
| `L-:*-rzrq_cx_rzfzhz` | 查询融资负债汇总 |
| `L-:-rzrq_xgsg` | 信用新股申购 |

## 港股通

| 请求 cmd | 业务含义 |
| --- | --- |
| `L-=-ggt_cx_huilv_info` / `L-0-ggt_cx_huilv_info` | 港股通查询汇率（买卖界面） |
| `L-=-ggt_query_huilv` / `L-0-ggt_query_huilv` | 港股通查询汇率（查询汇率菜单） |
| `L-=-ggt_query_zijin` / `L-0-ggt_query_zijin` | 港股通查询资金 |
| `L-=-ggt_mairu` / `L-0-ggt_mairu` | 港股通买入 |
| `L-=-ggt_maichu` / `L-0-ggt_maichu` | 港股通卖出 |
| `L-=-ggt_cd` / `L-0-ggt_cd` | 港股通撤单 |
| `L-=-ggt_query_drwt` / `L-0-ggt_query_drwt` | 港股通查询当日委托 |
| `L-=-ggt_query_drcj` / `L-0-ggt_query_drcj` / `L-=-ggt_query_chengjiao` / `L-0-ggt_query_chengjiao` | 港股通查询当日成交 |
| `L-=-ggt_query_jgd` / `L-0-ggt_query_jgd` | 港股通查询交割单 |
| `L-=-ggt_query_cican` / `L-0-ggt_query_cican` | 港股通查询持仓 |
| `L-=-ggt_query_jiacha` / `L-0-ggt_query_jiacha` | 港股通查询价差 |
| `L-=-ggt_cx_edye` / `L-0-ggt_cx_edye` | 港股通查询额度余额 |
| `L-=-query_ggt_kmsl` / `L-0-query_ggt_kmsl` | 港股通查询可买/卖数量 |
| `L-=-ggt_query_zjmx` / `L-0-ggt_query_zjmx` | 港股通查询资金明细 |
| `L-=-ggt_query_kcwt` / `L-0-ggt_query_kcwt` | 港股通查询可撤委托 |
| `L-=-ggt_query_lswt` / `L-0-ggt_query_lswt` | 港股通查询历史委托 |
| `L-=-ggt_query_lscj` / `L-0-ggt_query_lscj` | 港股通查询历史成交 |
| `L-=-query_ggt_bd_info` / `L-0-query_ggt_bd_info` | 港股通查询标的信息 |
| `L-=-ggt_cx_prompt` / `L-0-ggt_cx_prompt` | 港股通查询提示 |

## 基金业务

| 请求 cmd | 业务含义 |
| --- | --- |
| `J-1` / `J-1*` | 基金申购 |
| `J-2` / `J-2*` | 基金认购 |
| `J-5` | 基金转托管 |
| `T-A*` | 查询基金持仓 |
| `T-B*` | 查询基金委托 |
| `T-C` | 查询基金成交 |
| `T-CH` | 查询基金历史成交 |
| `T-E*` | 查询基金信息 |
| `T-F*` | 查询基金分红方式 |
| `T-G*` | 查询基金公司 |
| `T-H` | 查询定投基金 |

## ETF/LOF/场内基金

| 请求 cmd | 业务含义 |
| --- | --- |
| `C-S` | 查询可卖数量 |
| `C-B` | 查询可买数量 |
| `L-9-etf_xjrg` | ETF 现金申购 |
| `L-9-etf_cxrgcfg` | ETF 申购份额结果查询 |
| `L-9-etf_shengou` | ETF 申购认购 |
| `L-9-etf_shuhui` | ETF 赎回 |

## 资金/银证/账户

| 请求 cmd | 业务含义 |
| --- | --- |
| `I-4` | 退出银行转账 |
| `I-6` | 转账 |
| `I-7` | 充值 |
| `I-Q` | 中行查询 |
| `I-d` | 开放基金公司开户 |
| `I-c` | 修改通讯密码 |
| `L-0-zjdb_cx_kyje` | 查询可取金额 |
| `L-0-zjdb_cx_dblls` | 查询对账单列表 |
| `L-0-zjdb_cx_ksjy` | 查询可售余额 |
| `L-0-zjdb_cx_jzjy` | 查询结转收益 |
| `L-0-zijin_diaobo` | 资金调拨 |

## 权限/适当性/协议

| 请求 cmd | 业务含义 |
| --- | --- |
| `L-0-risk_get_status` | 风险评测手机号时间 |
| `L-0-mobile_cs` | 查询用户风险等级 |
| `L-0-get_prot` | 获取协议 |
| `L-0-Qs_Bqxy` | 客户协议补签记录签署 |
| `L-0-goto_T_5` | 查询账号并进入协议签署 |
| `L-0*-ptgp_sfcg_zzls_ls` | 普通股票三方存管转账流水查询 |

## 电子合同/认证/用户信息

| 请求 cmd | 业务含义 |
| --- | --- |
| `M-S-kh_qu_hardinfo` | 硬件绑定信息查询 |
| `M-S-kh_hardbind` | 硬件绑定 |
| `M-S-kh_harddelbind` | 硬件绑定删除 |
| `M-S-kh_changeprompt` | 修改提示问题 |
| `L-0-get_fund_list` | 获取签约列表 |
| `L-0-elc_contract` | 电子合同签约 |
| `L-0-get_checked_fund_list` | 获取已签约产品列表 |
| `L-0-get_elc_detail` | 获取签约详情 |
| `L-0-elc_query_clientrisk` | 判断客户风险等级 |
| `L-0-elc_query_clientright` | 判断客户是否有新股申购权限 |
| `L-0-elc_check_risk` | 判断风险等级是否匹配 |

## 系统/版本/服务

| 请求 cmd | 业务含义 |
| --- | --- |
| `L-L-queryversion` | 查询版本 |
| `L-L-*` | 版本查询 |
| `L-0-down_svrcfg` | 下载服务配置 |
| `L-0-sdk_login` | SDK 登录 |

## 北交所/股转新股

| 请求 cmd | 业务含义 |
| --- | --- |
| `L-0-sbwt_cx_transfer_type` | 查询三板委托转让类型 |
| `L-0-sbwt_gkfx` | 股转公开发行委托 |
| `L-0-cx_sbwt_gkfx_xjdm` | 股转查询公开发行询价阶段证券 |
| `L-0-cx_sbwt_gkfx_sgdm` | 股转查询公开发行申购阶段证券 |
| `L-0-cx_sbwt_gkfx_xjjg` | 股转查询公开发行询价结果 |
| `L-0-cx_sbwt_gkfx_sgjg` | 股转查询公开发行申购结果 |
| `L-0-cx_sbwt_gkfx_xjwt` | 股转查询公开发行询价委托 |
| `L-0-cx_sbwt_gkfx_sgwt` | 股转查询公开发行申购委托 |
| `L-0-cx_sbwt_wtsl` | 股转查询三板委托委托数量 |
| `L-0-cx_sbwt_zqxx` | 股转查询三板委托证券信息 |
