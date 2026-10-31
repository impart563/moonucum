# 数据接入接口

## 单位发现

`Engine::describe(code)` 接受单位原子或带前缀的原子，返回标准代码、大小写不敏感代码、名称、物理属性和标志。例如 `kPa` 的描述对应 `Pa`；表达式 `kg.m/s2` 应交给解析与归一化接口。

`Engine::search(query)` 按当前代码模式的单位表搜索代码、名称和属性，忽略查询大小写，按代码排序。空查询返回完整原子表。名称来自固定的 UCUM XML，经实体解码生成；返回数组可由调用方修改，不会改变引擎内的目录。名称与属性用于检索，单位计算仍使用标准代码。

```moonbit
let engine = Engine::new()
let pressure_units = engine.search("pressure")
let pascal = engine.describe("kPa")
```
