# LunarUnits 互操作

该独立模块连接 MoonUCUM 的 UCUM 编码与 [LunarUnits 0.1.9](https://github.com/FrozenLemonTee/LunarUnits) 的物理量运算。核心 MoonUCUM 模块仍只依赖标准库。适配器使用上游公开的 `Un`、`Dimension`、`Quantity` 接口，依赖固定为 0.1.9；未复制上游实现。

`to_unit(engine, code)` 将比例单位转为 LunarUnits 单位，`to_quantity` 包装数值，`from_quantity` 将运算结果转回指定 UCUM 单位。测试包含距离除以时间、克与千克、力、电荷以及两种编码模式。

量纲映射保持 UCUM 语义：质量系数由克调整到千克；电荷映射为安培乘秒；弧度映射为独立的 `ucum:rad` 自定义量纲；摩尔仍按 UCUM 展开为计数，因此不会自动转成 LunarUnits 的物质的量维度。温标点和非线性单位先经 MoonUCUM 转为对应比例单位，再进入乘法物理量运算。任意单位返回原有语义错误。

在尚未发布 Mooncakes 版本时，用包含仓库根目录与本目录的 `moon.work` 进行集成。完整的发布归档与四后端集成验证：

```sh
python scripts/acceptance.py --with-reference --with-integrations
```

构造与转换仍使用 binary64；类型化 `BridgeError` 区分单位错误、点值限制、量纲冲突和非有限数值。
