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

## 标准支持范围

| 能力 | 0.2.0 状态 |
|---|---|
| UCUM 2.2 大小写敏感代码 | 312 个单位原子、24 个前缀全部载入 |
| 语法解析 | 乘除、括号、整数指数、前导除号、方括号原子、注释和十进制因子 |
| 比例单位归一化 | 250 个基础或比例单位原子及其支持的组合 |
| 温标转换 | `Cel`、`[degF]`、`[degRe]`，包含允许的前缀和标量缩放 |
| 对数与 pH 转换 | 11 个单位原子的正反转换，包含分贝、奈培、声压级和功率级 |
| 批量转换 | `Engine::converter` 预解析表达式，`Converter::apply` 重复处理数值 |
| 关系判断 | 区分语义等价与量纲兼容，支持对数单位 |
| 任意单位 | 41 个代码可识别，数值语义返回 `Unsupported` |
| 其他特殊单位 | 7 个代码可识别，特殊转换函数尚未实现 |
| 大小写不敏感代码模式 | 后续版本 |

`parse_expression` 返回保留注释及符号位置的语法树。`Engine::validate` 检查语法和标准代码；`normalize` 返回比例与温标的线性表示；`compatible`、`equivalent` 和 `convert` 同时支持已实现的对数单位。对数单位没有线性 `NormalForm`，应通过转换器或 `convert` 处理。特殊单位参与维度乘除时返回明确错误。

计算采用 binary64；`equivalent` 对系数和原点使用 `1e-12` 相对容差。归一化基底为 UCUM 的 `m, s, g, rad, K, C, cd`，摩尔按标准定义展开为计数。量纲兼容表示单位关系，具体测量项目能否比较由调用方的数据语义决定。

资源限制：输入 4096 个 ASCII 字符、256 个组件、32 层括号、64 层定义展开；整数因子及指数绝对值上限为 10000。非有限输入、数值溢出和缩放因子下溢会返回错误。

## 验证与复用

- FHIR 上游 529 条校验用例保留原始期望，生成黑盒测试。
- 独立测试覆盖比例转换、温标、前缀、连续除法、任意单位、错误位置及资源限制。
- NLM 实现的 669 个数值对照案例分别记录一致项和已核对的标准差异，见[差异说明](docs/reference-differences.md)和[结果数据](validation/differential-results.json)。
- 验收脚本复制发布所需文件到临时目录，再以独立模块消费该副本，验证公开 API。

完整流程：

```sh
npm ci --ignore-scripts
python scripts/acceptance.py --with-reference
```

Node.js 及 NLM 包仅用于开发阶段的独立对照，核心库和普通验收不依赖它们。具体支持矩阵见 [docs/standard-support.md](docs/standard-support.md)，架构和生态分工见 [docs/design.md](docs/design.md)。

## 来源与许可

项目代码采用 [Apache-2.0](LICENSE)。UCUM 标准文件保持原文，适用其独立[许可](standards/UCUM-LICENSE.md)；FHIR 上游测试适用 [BSD 许可](standards/FHIR-LICENSE.txt)。来源版本、固定提交及文件哈希见 [standards/sources.json](standards/sources.json)。

- [UCUM 2.2 规范](https://ucum.org/ucum)
- [FHIR Quantity](https://hl7.org/fhir/datatypes.html#Quantity)
- [FHIR UCUM Java 测试来源](https://github.com/FHIR/Ucum-java)
- [NLM UCUM 参考实现](https://github.com/LHNCBC/ucum-lhc)

## Codex 辅助使用声明

本项目使用 Codex 辅助文献查阅与资料整理、代码编写与纠错、测试用例补充和文档润色。
