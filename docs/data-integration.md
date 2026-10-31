# 数据接入接口

## FHIR Quantity

导入 `impart563/moonucum/fhir` 后，`convert_quantity(engine, quantity_json, target)` 可换算带数值及显式 UCUM system/code 的 FHIR R4 Quantity。输入使用大小写敏感编码，`unit` 只作为显示文本。成功后更新 `value`、`code`、`unit`，保留 `id`、一般 `extension` 等无关成员，原对象保持不变。

比例与温标映射保留 `<`、`<=`、`>`、`>=` 比较符。非线性映射支持点值；带比较符时返回 `Input`，因为有限阈值不能单独表达其定义域。转换字段上的 `_value` 等原始扩展也返回 `Input`，由调用方处理。结构问题和单位错误分别表示为 `QuantityError::Input` 与 `UnitConversion(UcumError)`。数值仍采用核心库的 binary64 精度，未实施 FHIR 全资源或 profile 校验。

依据：[FHIR R4 Quantity](https://hl7.org/fhir/R4/datatypes.html#Quantity) 对编码、显示文本、比较符及隐含精度的定义。示例数据全部为合成值。

## 有限区间

`Interval::new(lower, upper, lower_closed?, upper_closed?)` 建立非空、端点有限的区间，默认包含两端。`Converter::apply_interval(interval)` 转换两端，并通过映射方向安排结果。例如 pH `[6, 8]` 转为 `mol/L` 后是约 `[10^-8, 10^-6]`，端点的开闭属性随对应端点交换。

所有已支持映射在其定义域内连续且单调。两端均须可转换，包括标为开区间的端点；`(0, 1] W` 转为对数单位需要无穷端点，因此返回 `Domain`。接口处理数值区间，不把区间解释为统计置信区间或测量不确定度。`is_increasing` 公开方向；`is_affine` 标识比例或温标之间的映射。

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
