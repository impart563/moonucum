# 数据接入接口

## 数量比较与区间判断

`Engine::compare_quantities(left, right, unit, absolute_tolerance?, relative_tolerance?)` 接受两个 `(数值, 单位代码)`，将两者换算到调用方指定的比较单位，返回 `Lower`、`Same` 或 `Higher`。默认按 binary64 数值精确比较；绝对容差使用比较单位，相对容差按两值绝对值的较大者计算。容差必须有限且非负。带容差的 `Same` 不满足传递性，不能作为排序等价关系。

比较单位也决定坐标方向：pH 6 与 pH 8 在 `[pH]` 坐标中前者更小，在 `mol/L` 坐标中前者更大。两个输入都执行实际转换，定义域、非有限值和任意单位错误不会被相同代码绕过。

`Converter::classify(value, interval)` 把源单位数值转换到目标单位，再与以目标单位表示的区间比较，返回 `Below`、`Within` 或 `Above`，遵守两端开闭属性。该接口执行调用方给定的数值规则，不附加测量项目或医学判断。

## FHIR Quantity

导入 `impart563/moonucum/fhir` 后，`convert_quantity(engine, quantity_json, target)` 可换算带数值及显式 UCUM system/code 的 FHIR R4 Quantity。输入使用大小写敏感编码，`unit` 只作为显示文本。成功后更新 `value`、`code`、`unit`，保留 `id`、一般 `extension` 等无关成员，原对象保持不变。

比例与温标映射保留 `<`、`<=`、`>`、`>=` 比较符。非线性映射支持点值；带比较符时返回 `Input`，因为有限阈值不能单独表达其定义域。转换字段上的 `_value` 等原始扩展也返回 `Input`，由调用方处理。结构问题和单位错误分别表示为 `QuantityError::Input` 与 `UnitConversion(UcumError)`。数值仍采用核心库的 binary64 精度，未实施 FHIR 全资源或 profile 校验。

依据：[FHIR R4 Quantity](https://hl7.org/fhir/R4/datatypes.html#Quantity) 对编码、显示文本、比较符及隐含精度的定义。示例数据全部为合成值。

## FHIR Range

`fhir.convert_range(engine, range_json, target)` 换算具有一个或两个数值端点的 FHIR R4 Range。双端点的 `system`、`code` 和显示用 `unit` 必须相同，源数值满足 `low <= high`；端点不允许比较符。两个边界均为闭端点。

比例和温标映射保留端点方向；pH 等递减映射交换完整的 `low`、`high` Quantity，因此端点 `id`、扩展等元数据跟随原端点移动。仅有一个边界时，缺少的边界保持未知；递减映射会将已知下界移到上界，或将已知上界移到下界，不填充无穷值。无数值边界、空值边界、编码或显示文本不一致均返回 `Input`；单位和定义域问题保持 `UnitConversion`。换算字段上的原始扩展沿用 Quantity 接口的显式处理要求。

依据：[FHIR R4 Range](https://hl7.org/fhir/R4/datatypes.html#Range)。适配范围为有数值边界的 Range，数值精度与核心 binary64 相同。

## FHIR Ratio

`fhir.convert_ratio(engine, ratio_json, numerator_target, denominator_target)` 分别换算有数值的分子和分母，保持 Ratio 结构与两个 Quantity 的元数据。例如 `5 mg / 10 mL` 可换算为 `0.005 g / 0.01 L`；不会约分、把分母重设为 1 或自动计算商值。分母的原始数量在部分业务中具有独立意义。

源单位和目标单位均须是比例单位，两侧不允许比较符。仿射温标点、非线性单位和任意单位不进入这一运算；调用方应先明确相应数量的解释。分母必须非零，换算后的分母在 binary64 精度下也须保持非零。分子可以为零；数值符号保持原值，不附加具体业务约束。缺少分子或分母以及仅含扩展的未知 Ratio 无法进行数值换算，返回 `Input`。

依据：[FHIR R4 Ratio](https://hl7.org/fhir/R4/datatypes.html#Ratio) 对双数量结构及分母意义的规定。接口处理编码数量的单位变化，不将 Ratio 视为两个任意字段组成的普通除法。

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
