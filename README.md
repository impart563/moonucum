# MoonUCUM

MoonUCUM 是面向数据互操作的 MoonBit 单位表达式库。它按 UCUM 2.2 的标准代码解析单位，判断表达式的语义关系，并在量纲兼容时转换数值。核心库使用纯 MoonBit 实现，运行时只依赖标准库。

同一组 API 可用于 FHIR 编码数量、科研数据导入和设备测量数据。医疗业务规则保留在调用端，单位处理能力可以独立复用。

## 快速使用

需要 MoonBit 工具链；本版本使用 `moon 0.1.20260920` 开发验证。

```sh
moon test --target all
moon run cmd/ucum -- validate 'mg/dL'
moon run cmd/ucum -- normalize 'kg.m/s2'
moon run cmd/ucum -- convert 12 'mg/dL' 'g/L'
moon run cmd/ucum -- equivalent 'N' 'kg.m/s2'
moon run cmd/ucum -- search pressure
moon run cmd/ucum -- translate MPa case-insensitive
moon run examples/fhir
moon run examples/sensor
python scripts/acceptance.py
```

命令行输出 JSON。每个操作通过 `ok` 字段报告结果；`batch` 对每条 JSON 请求分别返回结果，调用端应读取该字段。

## 在程序中调用

下面的示例随 `moon test` 一同编译、执行。外部调用方在 `moon.pkg` 导入 `impart563/moonucum` 并指定别名 `ucum`。

```mbt check
///|
test "unit semantics from the public API" {
  let engine = @ucum.Engine::new()
  engine.validate("mg/dL")
  assert_true(engine.equivalent("N", "kg.m/s2"))
  assert_true(engine.compatible("mg/dL", "g/L"))
  assert_false(engine.equivalent("mg/dL", "g/L"))
  assert_true(engine.convert(12.0, "mg/dL", "g/L").is_close(0.12))
  assert_true(engine.convert(37.0, "Cel", "K").is_close(310.15))
}
```

```mbt check
///|
test "incompatible quantities preserve a typed error" {
  let engine = @ucum.Engine::new()
  let rejected = try {
    ignore(engine.convert(90.0, "mg/dL", "mmol/L"))
    false
  } catch {
    @ucum.Incompatible(_, _) => true
    _ => false
  }
  assert_true(rejected)
}
```

`mg/dL` 到 `mmol/L` 的转换需要具体物质及摩尔质量，不能仅根据单位决定。FHIR 示例也要求显式的 `system` 和 `code`，不会把显示用的 `unit` 文本当成标准编码。

## 批量与对数转换

```mbt check
///|
test "reuse a logarithmic converter" {
  let engine = @ucum.Engine::new()
  let converter = engine.converter("dB[W]", "W")
  assert_true(converter.apply(10.0).is_close(10.0))
  assert_true(converter.apply(20.0).is_close(100.0))
  assert_true(engine.convert(7.0, "[pH]", "mol/L").is_close(0.0000001))
}
```

```mbt check
///|
test "logarithmic targets require positive quantities" {
  let engine = @ucum.Engine::new()
  let rejected = try {
    ignore(engine.convert(0.0, "W", "dB[W]"))
    false
  } catch {
    @ucum.Domain(_) => true
    _ => false
  }
  assert_true(rejected)
}
```

对数目标要求正的对应数量，零或负值返回 `Domain`。表达式解析、量纲核对在转换器创建时完成，数值定义域在 `apply` 时检查。函数、参考量和数值边界见[对数转换说明](docs/logarithmic-conversion.md)。

## 选择代码模式

```mbt check
///|
test "select the UCUM code system explicitly" {
  let engine = @ucum.Engine::new(mode=@ucum.CaseInsensitive)
  assert_true(engine.convert(1.0, "PaL", "KPAL").is_close(0.001))
  assert_true(engine.convert(12.0, "MG/DL", "G/L").is_close(0.12))
}
```

默认模式保持大小写敏感。大小写不敏感模式使用 UCUM 独立的代码和前缀表，例如帕斯卡为 `PAL`，兆米为 `MAM`；不能直接把默认代码改成大写来替代。命令行可在操作前添加 `--case-insensitive`。两种模式的映射、别名和边界见[代码模式说明](docs/code-modes.md)。

## 数据接入与生态互操作

```mbt check
///|
test "discover translate and convert independent rows" {
  let engine = @ucum.Engine::new()
  assert_eq(engine.describe("kPa").property, "pressure")
  assert_eq(
    engine.translate("MPa{Reading}", @ucum.CaseInsensitive),
    "MAPAL{Reading}",
  )
  let rows = engine.convert_many([(12.0, "mg/dL", "g/L"), (1.0, "m", "s")])
  assert_true(rows[0].unwrap().is_close(0.12))
  assert_true(rows[1] is Err(@ucum.Incompatible(_, _)))
}
```

```mbt check
///|
test "convert a decreasing interval with endpoint flags" {
  let converter = @ucum.Engine::new().converter("[pH]", "mol/L")
  let result = converter.apply_interval(
    @ucum.Interval::new(6.0, 8.0, lower_closed=false),
  )
  assert_true(
    result.lower.is_close(
      1.0e-8,
      relative_tolerance=1.0e-12,
      absolute_tolerance=0.0,
    ),
  )
  assert_true(result.lower_closed)
  assert_false(result.upper_closed)
}
```

单位检索、代码模式转换、逐行批量结果和有限区间均通过根包调用。`impart563/moonucum/fhir` 提供可复用的 FHIR R4 Quantity JSON 适配器，处理显式编码、比较符和元数据；用法和边界见[数据接入说明](docs/data-integration.md)。命令行的 `batch` 支持 `info`、`search`、`translate`、`values` 和 `interval` 请求。

[LunarUnits 适配模块](integrations/lunarunits/README.md) 可将 UCUM 比例单位接入现有物理量运算，明确映射质量、电荷、角度和计数。它作为独立模块引用 LunarUnits 0.1.9，核心库保持标准库依赖。所有输入示例使用合成数据。

## 标准支持范围

| 能力 | 0.5.0 状态 |
|---|---|
| UCUM 2.2 大小写敏感代码 | 312 个单位原子、24 个前缀全部载入 |
| 语法解析 | 乘除、括号、整数指数、前导除号、方括号原子、注释和十进制因子 |
| 比例单位归一化 | 250 个基础或比例单位原子及其支持的组合 |
| 温标转换 | `Cel`、`[degF]`、`[degRe]`，包含允许的前缀和标量缩放 |
| 对数与 pH 转换 | 11 个现行单位及 4 个退休编码的历史对数函数 |
| 正切与平方根转换 | 棱镜度、坡度百分比和幅度谱密度，包含定义域检查 |
| 批量转换 | 预解析转换器、同构数值数组和异构数量行，保留逐行结果及错误 |
| 目录与代码转换 | 按代码、名称、属性检索；在两种标准代码表之间转换表达式 |
| 区间与数据适配 | 单调有限区间转换、FHIR R4 Quantity、独立 LunarUnits 适配模块 |
| 关系判断 | 区分语义等价与量纲兼容，支持对数单位 |
| 任意单位 | 41 个代码可识别，数值语义返回 `Unsupported` |
| 特殊函数覆盖 | 单位表中的 21 个特殊单位原子均有转换路径；任意单位保持独立 |
| 大小写不敏感代码模式 | 独立 CODE 表及前缀，310 个不同代码；显式选择模式 |

`parse_expression` 返回保留注释及符号位置的语法树。`Engine::validate` 检查语法和标准代码；`normalize` 返回比例与温标的线性表示；`compatible`、`equivalent` 和 `convert` 同时支持已实现的对数单位。对数、正切和平方根单位没有线性 `NormalForm`，应通过转换器或 `convert` 处理。特殊单位参与维度乘除时返回明确错误。正切、平方根和退休编码的公式与边界见[特殊转换说明](docs/special-conversion.md)。

计算采用 binary64；`equivalent` 对系数和原点使用 `1e-12` 相对容差。归一化基底为 UCUM 的 `m, s, g, rad, K, C, cd`，摩尔按标准定义展开为计数。量纲兼容表示单位关系，具体测量项目能否比较由调用方的数据语义决定。

资源限制：输入 4096 个 ASCII 字符、256 个组件、32 层括号、64 层定义展开；整数因子及指数绝对值上限为 10000。非有限输入、数值溢出和缩放因子下溢会返回错误。

## 验证与复用

- FHIR 上游 529 条校验用例保留原始期望，生成黑盒测试。
- 独立测试覆盖比例与全部特殊函数、定义域、前缀、连续除法、任意单位、错误位置及资源限制。
- 根据原始 XML 生成测试，检查 312 对代码映射、24 个前缀和 21 个特殊单位函数在两种代码模式下的行为。
- 固定种子 563 的 5000 个比例表达式检查独立系数公式、往返与双模式结果；另有 1000 个不完整操作符输入。
- NLM 实现的 741 个数值对照案例分别记录一致项和已核对的标准差异，见[差异说明](docs/reference-differences.md)和[结果数据](validation/differential-results.json)。
- 验收脚本复制发布所需文件到临时目录，再以独立模块消费该副本，验证公开 API。

完整流程：

```sh
npm ci --ignore-scripts
python scripts/acceptance.py --with-reference
python scripts/acceptance.py --with-reference --with-integrations
python benchmarks/run.py --iterations 20000 --repeats 5
```

Node.js 及 NLM 包仅用于开发阶段的独立对照，核心库和普通验收不依赖它们。具体支持矩阵见 [docs/standard-support.md](docs/standard-support.md)，架构和生态分工见 [docs/design.md](docs/design.md)。

`--with-integrations` 会安装固定版本的 LunarUnits，并对归档中的适配器执行四后端测试。性能基准记录编译配置、运行环境、原始采样和校验和，见 [benchmarks/README.md](benchmarks/README.md) 与 [结果数据](benchmarks/results.json)。基准反映记录环境中的运行结果，不设跨机器性能门槛。

## 来源与许可

项目代码采用 [Apache-2.0](LICENSE)。UCUM 标准文件保持原文，适用其独立[许可](standards/UCUM-LICENSE.md)；FHIR 上游测试适用 [BSD 许可](standards/FHIR-LICENSE.txt)。来源版本、固定提交及文件哈希见 [standards/sources.json](standards/sources.json)。

- [UCUM 2.2 规范](https://ucum.org/ucum)
- [FHIR Quantity](https://hl7.org/fhir/datatypes.html#Quantity)
- [FHIR UCUM Java 测试来源](https://github.com/FHIR/Ucum-java)
- [NLM UCUM 参考实现](https://github.com/LHNCBC/ucum-lhc)

## Codex 辅助使用声明

本项目使用 Codex 辅助文献查阅与资料整理、代码编写与纠错、测试用例补充和文档润色。
