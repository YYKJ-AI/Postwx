# Postwx 工作流配置

## 工作流程

```
输入 → 格式检测 → 角色适配 → 去AI味 → 主题配色 → AI配图 → 用户审核 → 发布
```

### Step 1 — 输入检测

| 格式 | 处理方式 |
|------|---------|
| Markdown (.md) | 完整走全流程 |
| HTML (.html) | 跳过渲染，直接发布 |
| 纯文本 | 自动保存为 md 再走全流程 |

### Step 2 — 角色适配

根据设置中的创作者角色、写作风格、目标受众自动调整内容。

**创作者角色：**

| 角色 | 适配方式 |
|------|---------|
| tech-blogger | 技术术语保留，加入实用性观点，结构清晰 |
| lifestyle-writer | 口语化，加入个人感受，场景描写 |
| educator | 层次分明，循序渐进，加入总结要点 |
| business-analyst | 数据支撑，行业视角，趋势分析 |

**写作风格：**

| 风格 | 适配方式 |
|------|---------|
| professional | 严谨用词，逻辑清晰，适度使用专业术语 |
| casual | 亲切自然，适当口语化，拉近距离 |
| humorous | 加入巧妙比喻，轻松表达，保持信息量 |
| academic | 规范引用，严格论证，学术用语 |

**目标受众：**

| 受众 | 适配方式 |
|------|---------|
| general | 通俗易懂，避免术语堆砌 |
| industry | 行业术语，深度分析 |
| students | 教学口吻，知识点标注 |
| tech-community | 代码示例，技术深度 |

### Step 3 — 自动去 AI 味

强制执行，24 种 AI 痕迹检测 + 五维评分（满分 50）。

**评级标准：**
- 45-50：优秀
- 35-44：良好
- <35：需修订

### Step 4 — 智能选择主题配色

根据文章内容自动匹配：
- 4 种主题：default, grace, simple, modern
- 13 种配色：blue, green, vermilion, yellow, purple, sky, rose, olive, black, gray, pink, red, orange

### Step 5 — AI 自动配图

6 种图片风格：vector, watercolor, minimal, warm, blueprint, notion

占位符语法：`![描述](__generate:英文提示词__)`

需要配置 IMAGE_API_KEY。

### Step 6 — 用户审核

AI 处理完成后进入审核模式，用户可以：
- 查看/编辑 AI 处理后的内容
- 对比原文
- 修改标题、摘要
- 调整主题配色
- 确认发布或返回编辑
