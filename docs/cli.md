# 命令行与 JSON 请求

`moon run cmd/ucum -- OP ...` 输出 JSON；检查每条结果的 `ok` 字段。操作错误通过结果报告，进程退出码保持原有行为。可在操作前加入 `--case-insensitive`；FHIR 适配操作使用大小写敏感 UCUM 编码。

直接参数支持 `validate UNIT`、`normalize UNIT`、`convert VALUE SOURCE TARGET`、`equivalent SOURCE TARGET`、`info UNIT`、`search QUERY`、`translate UNIT case-sensitive|case-insensitive` 和 `catalog`。

`batch JSON_REQUEST ...` 接受一条或多条 JSON 请求，每条输出一行结果；请求间保留原始顺序。格式或类型错误也各自返回结果。

```sh
moon run cmd/ucum -- batch '{"op":"compare","left":{"value":1,"unit":"m"},"right":{"value":100,"unit":"cm"},"unit":"m"}'
moon run cmd/ucum -- batch '{"op":"classify","value":150,"source":"cm","target":"m","lower":1,"upper":2,"lower_closed":false}'
```

| op | 必填字段 | 结果字段 |
| --- | --- | --- |
| validate / normalize / info | unit | unit / 归一化字段 / 元数据 |
| search | query | units |
| translate | unit, mode | unit, mode |
| convert | value, source, target | value, unit |
| equivalent | source, target | equivalent, compatible |
| values | values 数组, source, target | results，保留每个数值的结果 |
| interval | lower, upper, source, target | lower, upper, unit，输入为闭区间 |
| compare | left 和 right 各含 value、unit；unit 指定比较坐标 | order: lower / same / higher |
| classify | value, source, target, lower, upper | position: below / within / above |
| fhir-quantity | quantity, target | quantity |
| fhir-range | range, target | range |
| fhir-ratio | ratio, numerator_target, denominator_target | ratio |

`compare` 可选 `absolute_tolerance` 与 `relative_tolerance`，默认均为 0，须为有限非负数。绝对容差使用比较单位，带容差的相等结果不能作为排序等价关系。`classify` 可选 `lower_closed`、`upper_closed`，默认均为 true，须为布尔值。

FHIR 请求中的编码数量须包含 `value`、`code`、`system: "http://unitsofmeasure.org"`。结构或适配条件错误返回 `error: "input"`；单位错误沿用 `syntax`、`unknown_unit`、`unsupported`、`incompatible`、`domain`、`non_finite` 等核心类别。`request` 表示请求字段或选项类型不合要求，`json` 表示请求文本无法解析。

```json
{
  "op": "fhir-ratio",
  "ratio": {
    "numerator": {"value": 5, "code": "mg", "system": "http://unitsofmeasure.org"},
    "denominator": {"value": 10, "code": "mL", "system": "http://unitsofmeasure.org"}
  },
  "numerator_target": "g",
  "denominator_target": "L"
}
```

成功时仍返回含分子、分母的 Ratio。操作范围、端点和元数据处理见[数据接入说明](data-integration.md)。
