
# 邻里交换 (SwapNorge) - 发布与测试指南

您的应用已经开发完成，可以立即部署到 Supabase 后端和 Vercel 前端。

## 推荐部署架构
- 后端：Supabase
  - PostgreSQL 数据库
  - Authentication
  - Storage
- 前端：Vercel
  - 原生支持 Next.js
  - 自动部署与分支预览
  - 与 Supabase 兼容良好

## 1. 本地验证
1. 进入项目目录：
   - `cd "d:\二手交易平台\project Swap"`
2. 安装依赖：
   - `npm install`
3. 启动本地开发：
   - `npm run dev`
4. 测试构建：
   - `npm run build`

## 2. Supabase 后端部署
1. 登录 Supabase：
   - 打开 `https://supabase.com`
2. 创建新项目或使用现有项目
3. 配置数据库：
   - 在 Supabase 控制台中设置数据库表和策略
   - 参考 `docs/supabase-migration.md` 获取迁移指南
4. 配置 Authentication：
   - 在 Authentication > Settings 中启用所需提供商
5. 配置 Storage（如果需要上传图片/文件）：
   - 在 Storage 中创建存储桶并设置策略
6. 获取 API 密钥：
   - 在 Settings > API 中复制 URL 和 anon/public key

## 3. Vercel 前端部署
1. 登录 Vercel：
   - 打开 `https://vercel.com`
2. 连接 GitHub 仓库并导入项目 `project Swap`
3. 构建设置：
   - Build Command: `npm run build`
   - 输出目录：Vercel 会自动识别 Next.js
4. 配置环境变量（推荐）
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - 请在 Vercel 仪表盘的 Environment Variables 中添加，不要将这些值写入 `vercel.json`
5. 部署并访问生成的网址

## 4. 关键检查点
- 本地构建通过：`npm run build`
- Supabase 后端已正常配置
- Vercel 上的前端能正常加载并连接 Supabase
- 数据读写、认证和存储功能正常

## 5. 运行时环境
本项目已经支持从环境变量读取 Supabase 配置。您可以复制 `.env.local.example` 为 `.env.local`，用于本地开发。

---
祝您的邻里社区上线顺利！

## Supabase 迁移指南

项目已支持从 Firebase 迁移到 Supabase 后端。Supabase 提供更好的开发体验和更丰富的功能。

### 迁移优势
- 🚀 更快的查询性能
- 📊 内置分析和监控
- 🔄 实时订阅更稳定
- 🛠️ 更简单的数据库管理
- 📱 更好的移动端支持

### 迁移步骤

#### 1. Supabase 项目设置
1. 访问 [supabase.com](https://supabase.com) 并注册账户
2. 创建新项目 `epohhwawaaopxibhslck`
3. 等待项目初始化完成

#### 2. 数据库表结构
在 Supabase SQL 编辑器中创建以下表：

```sql
-- profiles 表（用户资料）
CREATE TABLE profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uid TEXT,
  display_name TEXT NOT NULL DEFAULT 'Neighbor',
  photo_url TEXT,
  stats JSONB DEFAULT '{"points": 100, "reputation": 5.0, "completedSwaps": 0, "memberSince": null}'
);

-- items 表（交换物品）
CREATE TABLE items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  points INTEGER NOT NULL DEFAULT 50,
  category TEXT NOT NULL,
  condition TEXT DEFAULT 'good',
  image_url TEXT,
  seller_id UUID NOT NULL REFERENCES profiles(id),
  seller_name TEXT NOT NULL,
  seller_rating REAL DEFAULT 5.0,
  posted_date TIMESTAMPTZ DEFAULT NOW(),
  is_public BOOLEAN DEFAULT true,
  location JSONB DEFAULT '{"latitude": 59.91, "longitude": 10.75, "city": "Oslo"}',
  status TEXT DEFAULT 'available',
  views INTEGER DEFAULT 0,
  likes INTEGER DEFAULT 0
);

-- transactions 表（积分交易记录）
CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id),
  type TEXT NOT NULL DEFAULT 'payment',
  amount INTEGER NOT NULL,
  target_id UUID,
  target_name TEXT,
  item_id UUID,
  item_title TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- reviews 表（评价）
CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_id UUID NOT NULL REFERENCES profiles(id),
  from_name TEXT NOT NULL,
  to_id UUID NOT NULL REFERENCES profiles(id),
  request_id UUID NOT NULL,
  content TEXT NOT NULL,
  rating INTEGER DEFAULT 5,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- swap_requests 表（交换请求）
CREATE TABLE swap_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id UUID NOT NULL REFERENCES items(id),
  item_title TEXT NOT NULL,
  item_image_url TEXT,
  message TEXT,
  points INTEGER NOT NULL,
  sender_id UUID NOT NULL REFERENCES profiles(id),
  sender_name TEXT NOT NULL,
  receiver_id UUID NOT NULL REFERENCES profiles(id),
  receiver_name TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- favorites 表（收藏）
CREATE TABLE favorites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id),
  item_id UUID NOT NULL REFERENCES items(id),
  saved_at TIMESTAMPTZ DEFAULT NOW()
);

-- 启用行级安全策略（RLS）
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE items ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE swap_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

-- 创建基本策略（根据需要调整）
CREATE POLICY "Users can view all profiles" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can view all items" ON items FOR SELECT USING (true);
CREATE POLICY "Users can insert own items" ON items FOR INSERT WITH CHECK (auth.uid() = seller_id);
CREATE POLICY "Users can update own items" ON items FOR UPDATE USING (auth.uid() = seller_id);
```

#### 3. 环境变量配置
复制 `.env.local.example` 并更新 Supabase 配置：

```env
# Supabase configuration
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

#### 4. 数据迁移
如果您需要将现有 Firebase 数据迁移到 Supabase，推荐先从 Firestore 导出数据为 JSON/CSV，然后使用迁移脚本将导出文件写入 Supabase。仓库提供 `scripts/test-supabase-migration.js` 用于验证数据在 Supabase 中的可用性。

示例：
1. 从 Firestore 导出数据为 JSON 文件
2. 运行自定义迁移脚本（读取导出文件并写入 Supabase）
3. 验证迁移结果：
   ```bash
   node scripts/test-supabase-migration.js
   ```

#### 5. 部署验证
1. 更新 Vercel 环境变量为 Supabase 配置
2. 重新部署应用
3. 测试所有功能：
   - 用户注册/登录
   - 发布物品
   - 浏览和搜索
   - 发送交换请求
   - 积分交易
   - 个人资料管理

### 故障排除
- **认证问题**：检查 Supabase Auth 设置
- **数据查询失败**：验证表结构和 RLS 策略
- **实时更新不工作**：检查 Supabase Realtime 配置
- **迁移错误**：确保 Firebase 凭据正确且有读取权限

### 回滚到旧后端
若需要回滚到之前的后端实现，请恢复 `src/app/layout.tsx` 中的原始 provider 并回退相关更改（如果保留了历史分支或提交，可通过 Git 回退）。

---

享受 Supabase 带来的强大功能！🎉
