# Postwx

一句话将文章发布到微信公众号草稿箱。全自动完成内容适配、去 AI 味、排版配色、AI 配图、上传发布。

## 工作流

说一句"把 article.md 发到公众号"，自动执行以下 7 步：

### Step 1 — 输入检测

支持三种输入格式：

| 格式 | 处理方式 |
|------|---------|
| Markdown (.md) | 完整走全流程 |
| HTML (.html) | 跳过渲染，直接发布 |
| 纯文本 | 自动保存为 `post-to-wechat/yyyy-MM-dd/[slug].md`，再走全流程 |

### Step 2 — 角色适配

根据 `EXTEND.md` 中的配置自动调整内容风格，无需确认：

| 配置项 | 选项 |
|-------|------|
| 创作者角色 | tech-blogger / lifestyle-writer / educator / business-analyst |
| 写作风格 | professional / casual / humorous / academic |
| 目标受众 | general / industry / students / tech-community |

### Step 3 — 自动去 AI 味

每次发布强制执行。检测并修正 24 种 AI 痕迹：

- **内容模式** — 过度强调意义、空洞的权威引用、营销用语、套路式结尾
- **语言模式** — AI 高频词（至关重要、赋能）、不仅...而且...更是... 等三段式
- **排版模式** — 过多破折号、加粗滥用、正文列表化、装饰性 emoji
- **填充词** — 套话、过度修饰、万能正面结论、绕弯子
- **AI 痕迹** — 协作痕迹（希望对您有帮助）、知识截止声明、讨好语气

处理完成输出修改数量 + 五维评分（满分 50）。

### Step 4 — 智能选择主题配色

根据文章内容自动匹配：

| 文章类型 | 主题 | 配色 |
|---------|------|------|
| 技术/编程 | default | blue |
| 生活/情感 | grace | purple / rose |
| 教程/教育 | simple | green |
| 商业/分析 | modern | orange / black |
| 设计/创意 | grace | vermilion / pink |
| 科普/知识 | default | sky / green |

4 种主题：default、grace、simple、modern
13 种配色：blue、green、vermilion、yellow、purple、sky、rose、olive、black、gray、pink、red、orange

### Step 5 — AI 自动配图

根据文章内容自动选择图片风格并生成封面和插图：

| 风格 | 适用场景 | 视觉特征 |
|------|---------|---------|
| vector | 技术文章、教程 | 扁平矢量、黑色描边、几何图标 |
| watercolor | 生活、旅行、情感 | 水彩质感、柔和边缘、自然色调 |
| minimal | 观点、哲学 | 黑白灰为主、60%+ 留白 |
| warm | 个人故事、成长 | 暖色调手绘、奶油色背景 |
| blueprint | API 文档、系统设计 | 工程蓝线条、技术图纸感 |
| notion | 产品评测、工具 | 黑白为主、柔和点缀色 |

需要配置 `IMAGE_API_KEY`，未配置则跳过配图继续发布。

### Step 6 — 校验元数据 + 发布

自动解析标题、作者、摘要、封面，按优先级取值：

| 字段 | 优先级（高→低） |
|------|----------------|
| 标题 | CLI 参数 → frontmatter → 首个标题 → 提示输入 |
| 作者 | CLI 参数 → frontmatter → EXTEND.md `default_author` |
| 摘要 | CLI 参数 → frontmatter → 首段截取（120 字） |
| 封面 | CLI 参数 → frontmatter → AI 生成 → `imgs/cover.png` → 首张内容图 |

发布至微信公众号草稿箱。

### Step 7 — 完成报告

输出完整发布摘要：角色适配信息、去 AI 味修改数 + 评分、主题配色、文章元数据、media_id、草稿箱管理链接。

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
