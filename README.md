# Postwx

一句话将文章发布到微信公众号草稿箱。全自动完成内容适配、去 AI 味、排版配色、AI 配图、上传发布。

## 工作流

说一句"把 article.md 发到公众号"，自动执行以下 8 步：

### Step 0 — 加载偏好 + 检查凭证

1. 按优先级查找 `EXTEND.md`：项目级 `.baoyu-skills/Postwx/EXTEND.md` → 用户级 `~/.baoyu-skills/Postwx/EXTEND.md`
2. 找到则读取配置；未找到则引导首次设置（7 个问题：角色、风格、受众、笔名、评论开关、保存位置）
3. 检查微信凭证（`.baoyu-skills/.env` 或 `~/.baoyu-skills/.env`），缺失则引导配置
4. 检查 `IMAGE_API_KEY`，缺失则警告（跳过配图，不阻断流程）

### Step 1 — 输入检测

| 格式 | 处理方式 |
|------|---------|
| Markdown (.md) | 完整走全流程 |
| HTML (.html) | 跳过渲染，直接发布（跳至 Step 6） |
| 纯文本 | 自动保存为 `post-to-wechat/yyyy-MM-dd/[slug].md`，再走全流程 |

纯文本自动生成 slug：取前 2-4 个有意义的词，kebab-case（中文翻译为英文）。

### Step 2 — 角色适配

根据 `EXTEND.md` 配置自动调整内容，不询问用户确认。

**创作者角色**：

| 角色 | 适配方式 |
|------|---------|
| tech-blogger | 技术术语保留，加入实用性观点，结构清晰 |
| lifestyle-writer | 口语化，加入个人感受，场景描写 |
| educator | 层次分明，循序渐进，加入总结要点 |
| business-analyst | 数据支撑，行业视角，趋势分析 |

**写作风格**：

| 风格 | 适配方式 |
|------|---------|
| professional | 严谨用词，逻辑清晰，适度使用专业术语 |
| casual | 亲切自然，适当口语化，拉近距离 |
| humorous | 加入巧妙比喻，轻松表达，保持信息量 |
| academic | 规范引用，严格论证，学术用语 |

**目标受众**：

| 受众 | 适配方式 |
|------|---------|
| general | 通俗易懂，避免术语堆砌 |
| industry | 行业术语，深度分析 |
| students | 教学口吻，知识点标注 |
| tech-community | 代码示例，技术深度 |

### Step 3 — 自动去 AI 味

每次发布强制执行，不询问用户。默认 `medium` 强度，根据 `writing_style` 调整策略。

**24 种 AI 痕迹检测**：

内容模式（6 种）：

| # | 模式 | 示例 | 处理 |
|---|------|------|------|
| 1 | 过度强调意义/遗产 | "划时代的发现将永远改变人类" | 简化为客观陈述 |
| 2 | 过度强调知名度 | "业界公认的权威专家" | 去除不必要修饰 |
| 3 | 以-ing 肤浅分析 | "引领着、推动着、改变着" | 用具体动词替代 |
| 4 | 宣传/广告式语言 | "革命性的、颠覆性的" | 替换为中性描述 |
| 5 | 模糊归因 | "据专家表示"、"研究表明" | 补充来源或删除 |
| 6 | 公式化总结 | "挑战与机遇并存" | 用具体结论替代 |

语言模式（6 种）：

| # | 模式 | 示例 | 处理 |
|---|------|------|------|
| 7 | AI 高频词 | "至关重要、深入探讨、赋能、助力" | 替换日常用语 |
| 8 | 系动词回避 | "作为…的存在"（回避"是"） | 恢复自然"是"字句 |
| 9 | 否定式排比 | "不仅…而且…更是…" | 简化直接陈述 |
| 10 | 三段式过度使用 | 每观点三个并列 | 打破固定结构 |
| 11 | 刻意换词 | 同概念反复换词指代 | 统一用词 |
| 12 | 虚假范围 | "从…到…，从…到…" | 聚焦具体点 |

风格模式（4 种）：

| # | 模式 | 处理 |
|---|------|------|
| 13 | 破折号过度 | 保留关键，简化其余 |
| 14 | 粗体过度 | 仅保留核心关键词 |
| 15 | 正文列表化 | 恢复段落叙述 |
| 16 | 表情符号装饰 | 去除 |

填充词（4 种）：

| # | 模式 | 示例 | 处理 |
|---|------|------|------|
| 17 | 填充短语 | "为了实现这一目标"、"在当今时代" | 删除 |
| 18 | 过度限定 | "在某种程度上来说" | 简化/删除 |
| 19 | 通用积极结论 | "总之，未来可期" | 具体结论替代 |
| 20 | 绕圈回避 | 长句绕开直接表态 | 直接表述 |

交流痕迹（4 种）：

| # | 模式 | 示例 | 处理 |
|---|------|------|------|
| 21 | 协作痕迹 | "希望对您有帮助" | 删除 |
| 22 | 截止免责 | "截至我所知…" | 删除 |
| 23 | 谄媚语气 | "非常好的问题" | 删除 |
| 24 | 交流特征 | "让我来为您解释" | 删除 |

**五维评分（满分 50）**：

| 维度 | 满分 | 10 分标准 | 1 分标准 |
|------|------|----------|----------|
| 直接性 | 10 | 直截了当 | 铺垫绕圈 |
| 节奏感 | 10 | 长短交错 | 机械等长 |
| 信任度 | 10 | 简洁尊重读者 | 过度解释 |
| 真实性 | 10 | 像真人说话 | 机械生硬 |
| 精炼度 | 10 | 无冗余 | 大量废话 |

评级：45-50 优秀 | 35-44 良好 | <35 需修订

### Step 4 — 智能选择主题配色

根据文章内容自动匹配，不询问用户。综合考虑文章主题、`creator_role`、情感基调、受众特征。

| 文章类型 | 主题 | 配色 |
|---------|------|------|
| 技术/编程 | default | blue |
| 生活/情感 | grace | purple / rose |
| 教程/教育 | simple | green |
| 商业/分析 | modern | orange / black |
| 设计/创意 | grace | vermilion / pink |
| 科普/知识 | default | sky / green |

4 种主题：default、grace、simple、modern

13 种配色：blue、green、vermilion、yellow、purple、sky、rose、olive、black、gray、pink、red、orange（或自定义 hex 值）

### Step 5 — AI 自动配图

分析文章内容，自动选择风格、生成封面图和插图。

**6 种图片风格**：

| 风格 | 适用场景 | 色彩方案 |
|------|---------|---------|
| vector | 技术文章、教程、知识科普 | Cream 底 #F5F0E6, Coral #E07A5F, Mint #81B29A, Mustard #F2CC8F |
| watercolor | 生活方式、旅行、情感散文 | Earth 色系, 柔和边缘, 自然暖调 |
| minimal | 观点文章、深度思考、哲理 | 黑白 #000/#374151, 白底, 60%+ 留白 |
| warm | 个人故事、成长、生活感悟 | Cream 底 #FFFAF0, Orange #ED8936, Golden #F6AD55 |
| blueprint | API 文档、系统设计、技术深度 | Off-White 底 #FAF8F5, Blue #2563EB, Navy, Amber |
| notion | 产品指南、工具教程、SaaS | 白底, 黑色文字 #1A1A1A, 淡蓝/淡黄/淡粉点缀 |

**自动匹配规则**：

| 文章内容信号 | 推荐风格 |
|-------------|---------|
| API、代码、系统架构 | blueprint |
| 编程教程、操作指南 | vector |
| 产品介绍、工具评测 | notion |
| 个人故事、成长、情感 | warm |
| 旅行、美食、生活方式 | watercolor |
| 观点评论、深度分析 | minimal |
| 商业分析、行业报告 | vector / blueprint |

**提示词模板**（通用结构）：

```
[风格描述]. [主题内容]. [构图要求]. [色彩方案].
Clean composition with generous white space. Simple or no background.
Human figures: simplified stylized silhouettes, not photorealistic.
```

各风格模板示例：

- **vector**: `Flat vector illustration. Clean black outlines on all elements. [主题]. Geometric simplified icons, no gradients. Colors: Cream background (#F5F0E6), Coral Red (#E07A5F), Mint Green (#81B29A), Mustard Yellow (#F2CC8F). Centered composition with white space.`
- **watercolor**: `Soft watercolor illustration with natural warmth. [主题]. Gentle brush strokes, soft edges, organic flow. Earthy warm tones with muted greens and browns. Light paper texture background.`
- **minimal**: `Ultra-minimalist illustration. [主题]. Single focal element centered, 60%+ white space. Black and dark gray (#374151) on pure white background. Clean geometric shapes, no decoration.`
- **warm**: `Warm hand-drawn illustration with friendly feel. [主题]. Sketchy organic strokes, variable line weights. Colors: Cream background (#FFFAF0), Warm Orange (#ED8936), Golden Yellow (#F6AD55). Cozy inviting atmosphere.`
- **blueprint**: `Technical blueprint-style diagram. [主题]. Precise lines, grid overlay, 90-degree angles. Colors: Off-White background (#FAF8F5), Engineering Blue (#2563EB), Navy Blue, Amber highlights.`
- **notion**: `Minimalist hand-drawn line art in Notion style. [主题]. Simple black outlines (#1A1A1A) on white background. Pastel blue, yellow, pink accents only. Clean layout, generous spacing.`

**Markdown 语法**：

```markdown
![图片描述](__generate:英文提示词__)
```

**处理流程**：

```
Claude 分析文章 → 选择风格 → 生成提示词 → 插入 Markdown
  ↓
Markdown: ![alt](__generate:prompt__)
  ↓ 渲染
HTML: <img src="__generate:prompt__">
  ↓ wechat-api.ts 检测 __generate: 前缀
调用 api.tu-zi.com (gpt-image-1) → 生成图片
  ↓
上传微信素材库 → 获取 CDN URL → 替换 src
```

`IMAGE_API_KEY` 未配置时跳过生成，API 失败时跳过该图片继续处理。

### Step 6 — 校验元数据 + 发布

**元数据解析**（按优先级取值）：

| 字段 | 优先级（高→低） |
|------|----------------|
| 标题 | CLI `--title` → frontmatter → 首个 H1/H2 → 提示输入 |
| 作者 | CLI `--author` → frontmatter → EXTEND.md `default_author` |
| 摘要 | CLI `--summary` → frontmatter → 首段截取（120 字） |
| 封面 | CLI `--cover` → frontmatter → AI 生成 → `imgs/cover.png` → 首张内容图 → 报错 |

**发布命令**：

```bash
npx -y bun ${SKILL_DIR}/scripts/wechat-api.ts <file> \
  --theme <theme> \
  [--color <color>] \
  [--title <title>] \
  [--summary <summary>] \
  [--author <author>] \
  [--cover <cover_path>]
```

发布至微信公众号草稿箱（`POST /cgi-bin/draft/add`）。

### Step 7 — 完成报告

输出完整发布摘要：

```
WeChat Publishing Complete!

Input: [type] - [path]

Role Adaptation:
• Creator: [creator_role]
• Style: [writing_style]
• Audience: [target_audience]

De-AI Processing:
• Changes: [N] modifications
• Score: [score]/50 ([rating])

Theme: [theme] + [color]
• Reason: [选择理由]

Article:
• Title: [title]
• Summary: [summary]
• Cover: [generated/provided/fallback]
• Images: [N] AI-generated + [N] inline images
• Comments: [open/closed], [fans-only/all users]

Result:
✓ Draft saved to WeChat Official Account
• media_id: [media_id]

Next Steps:
→ Manage drafts: https://mp.weixin.qq.com（内容管理 → 草稿箱）
```

## 配置

### 微信凭证

前往 [微信公众平台](https://mp.weixin.qq.com) → 开发 → 基本配置，获取 AppID 和 AppSecret。

```bash
mkdir -p ~/.baoyu-skills
cat > ~/.baoyu-skills/.env << 'EOF'
WECHAT_APP_ID=你的AppID
WECHAT_APP_SECRET=你的AppSecret
IMAGE_API_KEY=你的图片API密钥
EOF
```

`IMAGE_API_KEY` 用于 AI 自动配图（使用 api.tu-zi.com），不配置则跳过配图。

### 创作者偏好（EXTEND.md）

首次使用时 Claude 会引导你完成设置，也可手动创建：

```bash
# 项目级（仅当前项目生效）
.baoyu-skills/Postwx/EXTEND.md

# 用户级（所有项目生效）
~/.baoyu-skills/Postwx/EXTEND.md
```

```yaml
creator_role: tech-blogger
writing_style: professional
target_audience: general
default_author: 你的笔名
need_open_comment: 1
only_fans_can_comment: 0
```

## 使用

```
> 把 article.md 发到公众号
```

或者直接贴文本：

```
> 发到公众号：
>
> 你的文章内容...
```

## 技术栈

- **运行时**：Bun（通过 `npx -y bun` 执行）
- **Markdown 渲染**：marked + highlight.js + KaTeX
- **CSS 内联**：juice（适配微信 HTML 渲染限制）
- **CJK 排版**：remark-cjk-friendly
- **图片生成**：api.tu-zi.com（gpt-image-1）
- **发布接口**：微信公众号草稿箱 API

## License

MIT
