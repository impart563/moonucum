# 数据接入接口

## 批量换算

`Converter::apply_all(values)` 在同一转换器上处理数值数组。`Engine::convert_many(rows)` 接受 `(数值, 源代码, 目标代码)` 数组，在一次调用内缓存每组单位关系的转换器。两者返回与输入等长的 `Array[Result[Double, UcumError]]`，保留原始行号；一行出现未知代码、量纲冲突或定义域错误时，其余行继续处理。输入数组保持原值，空数组返回空结果。

## 单位发现

`Engine::describe(code)` 接受单位原子或带前缀的原子，返回标准代码、大小写不敏感代码、名称、物理属性和标志。例如 `kPa` 的描述对应 `Pa`；表达式 `kg.m/s2` 应交给解析与归一化接口。

`Engine::search(query)` 按当前代码模式的单位表搜索代码、名称和属性，忽略查询大小写，按代码排序。空查询返回完整原子表。名称来自固定的 UCUM XML，经实体解码生成；返回数组可由调用方修改，不会改变引擎内的目录。名称与属性用于检索，单位计算仍使用标准代码。

```moonbit
let engine = Engine::new()
let pressure_units = engine.search("pressure")
let pascal = engine.describe("kPa")
```

## 代码模式转换

`engine.translate(expression, target_mode)` 根据源引擎选择的代码表解析单位，再替换为目标代码表的原子和前缀。括号、乘除、指数与注释原文保留；注释中的大小写不变。任意单位也可进行代码转换，其数值语义仍保持原有边界。

例如默认模式的 `MPa` 转为 `MAPAL`，`KiBy/s` 转为 `KIBBY/S`。大小写不敏感模式的 `PA` 转回 `pA`；默认模式的 `PA` 则转为 `PTA`。合并别名返回目标表的规范原子，例如升的 `l` 经大小写不敏感表往返可成为 `L`，数值语义一致。
