---
name: ArkUI @Builder 参数传递问题
description: ArkUI 中 @Builder 方法按值传递参数，导致状态更新时 UI 不刷新
type: feedback
---

## 规则

**在 ArkUI 中，避免在 @Builder 方法中传递频繁变化的 @State 变量作为参数。**

### 问题原因

ArkUI 的 `@Builder` 方法参数是**按值传递**的，不是响应式的。当原始 `@State` 变量变化时，已传递给 `@Builder` 方法的值不会自动更新，导致 UI 显示旧数据。

### 错误示例

```typescript
@Component
struct MyPage {
  @State count: number = 0;
  @State dhtNodes: number = 0;

  @Builder
  statChip(label: string, count: number, color: Resource) {
    Column() {
      Text(`${count}`)  // count 是按值传递的，不会响应状态变化
      Text(label)
    }
  }

  build() {
    Row() {
      this.statChip('DHT', this.dhtNodes, $r('app.color.accent'))
      // 当 dhtNodes 变化时，statChip 中的 count 不会更新
    }
  }
}
```

### 正确做法

**方案一：直接内联 UI 代码（推荐用于简单组件）**

```typescript
build() {
  Row() {
    Column() {
      Text(`${this.dhtNodes}`)  // 直接引用 @State 变量
      Text('DHT')
    }
  }
}
```

**方案二：@Builder 不传参数，内部引用 this**

```typescript
@Builder
dhtItem() {
  Column() {
    Text(`${this.dhtNodes}`)  // 直接引用 this.dhtNodes
    Text('DHT')
  }
}

build() {
  Row() {
    this.dhtItem()  // 不传参数
  }
}
```

### 为什么：ArkUI 状态更新机制

Why: ArkUI 的 `@Builder` 装饰器在编译时会生成独立的渲染函数，参数值在调用时被捕获。这与 React/Vue 的 props 机制不同，不会自动建立响应式绑定。

How to apply: 对于需要实时更新的数据（如速度、计数、状态），优先在 `build()` 方法中直接使用 `this.xxx`，而不是通过 `@Builder` 方法传递。

### 何时可以传参

以下情况可以安全地使用 `@Builder` 传参：
- 静态文本或不变化的数据
- 点击回调函数
- 资源引用（如颜色、图标）

```typescript
@Builder
actionRow(title: string, icon: Resource, action: () => void) {
  // title 和 icon 在创建后不变，action 是函数引用，这些都可以传参
  Button() { ... }
  .onClick(action)
}
```
