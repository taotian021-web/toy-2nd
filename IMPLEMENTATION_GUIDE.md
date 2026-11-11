# 🚀 SwapNorge UX改进 - 实现指南

## 已完成的修复 ✅

### 1️⃣ POST页面登入状态检查 ✅ DONE
**文件:** `src/app/post/page.tsx`

**问题:** 已登入用户点击"添加"按钮后仍显示登入提示

**修复:**
```typescript
// BEFORE: 在加载时立即显示提示
React.useEffect(() => {
  if (!user && !editId) {
    setShowLoginPrompt(true);
  }
}, [user, editId]);

// AFTER: 等待认证状态加载完成
React.useEffect(() => {
  if (!isUserLoading && !user && !editId) {
    setShowLoginPrompt(true);
  }
  if (!isUserLoading) {
    setAuthCheckComplete(true);
  }
}, [user, isUserLoading, editId]);
```

**测试:** 已登入用户打开/post页面应该直接看到表单，不会弹出登入对话框

---

### 2️⃣ 头像跨设备同步 ✅ DONE
**文件:** 
- `src/components/swap-norge/FooterNav.tsx`
- `src/app/profile/page.tsx`

**问题:** 头像存储在localStorage，导致跨设备不一致

**修复:**
```typescript
// FOOTERNAV.tsx - 移除localStorage依赖
// BEFORE
const [localAvatar, setLocalAvatar] = React.useState<string | null>(null);
React.useEffect(() => {
  const saved = localStorage.getItem(`local_avatar_${user.id}`);
  if (saved) setLocalAvatar(saved);
}, [user]);

// AFTER - 使用getAvatarUrl函数
const getAvatarUrl = () => {
  if (profile?.photo_url) {
    return profile.photo_url;
  }
  if (user?.id) {
    return `https://i.pravatar.cc/40?u=${user.id}`;
  }
  return null;
};

// PROFILE.tsx - 移除localStorage保存
// BEFORE
setLocalAvatar(base64String);
localStorage.setItem(`local_avatar_${user.id}`, base64String);

// AFTER - 只保存到状态，不保存到localStorage
setLocalAvatar(base64String);
```

**优先级:** Cloud > LocalBase64Preview > Default

**测试:** 在不同浏览器/设备上应该看到相同的头像

---

### 3️⃣ 全局认证上下文 ✅ DONE (框架已创建)
**文件:** 
- `src/contexts/AuthContext.tsx` ✅ 新建
- `src/contexts/AuthContextProvider.tsx` ✅ 新建

**目标:** 解决跨页面状态不同步问题

**下一步:** 在 `src/app/layout.tsx` 中集成

---

## 待完成的改进 (按优先级)

### 第2阶段：集成全局认证上下文

#### 任务A: 在 layout.tsx 中集成 AuthContextProvider
**文件:** `src/app/layout.tsx` ✅ DONE

```typescript
import { AuthContextProvider } from '@/contexts/AuthContextProvider';

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html>
      <body>
        <SupabaseProvider>
          <AuthContextProvider>
            {children}
          </AuthContextProvider>
        </SupabaseProvider>
      </body>
    </html>
  );
}
```

#### 任务B: 迁移所有页面使用全局上下文 ✅ DONE

| 页面 | 文件 | 状态 |
|------|------|------|
| POST | src/app/post/page.tsx | ✅ DONE |
| Profile | src/app/profile/page.tsx | ✅ DONE |
| Activity | src/app/activity/page.tsx | ✅ DONE |
| Search | src/app/search/page.tsx | ✅ DONE |

**迁移模式:**
```typescript
// BEFORE
const { user, isUserLoading } = useSupabaseUser();

// AFTER
const { user, isUserLoading } = useGlobalAuthCompatible();
```

---

### 第3阶段：改进加载状态UI

#### 任务A: 添加骨架屏加载器 ✅ DONE
**文件:** `src/components/ui/skeleton-loader.tsx` ✅ 新建

完成的加载器组件:
- ✅ SkeletonLoader() - 通用加载器
- ✅ PostPageSkeletonLoader() - POST页面专用
- ✅ ProfilePageSkeletonLoader() - Profile页面专用
- ✅ ActivityPageSkeletonLoader() - Activity页面专用
- ✅ CenteredSkeletonLoader() - 居中加载器

#### 任务B: POST页面添加加载状态 ✅ DONE
**文件:** `src/app/post/page.tsx`

修改内容:
- ✅ 导入 PostPageSkeletonLoader
- ✅ 添加加载状态检查: `{isUserLoading && <PostPageSkeletonLoader />}`
- ✅ 只在auth加载完成后显示表单

#### 任务C: Profile页面添加加载状态 ✅ DONE
**文件:** `src/app/profile/page.tsx`

修改内容:
- ✅ 导入 ProfilePageSkeletonLoader
- ✅ 添加加载状态检查: `if (isUserLoading) { return <ProfilePageSkeletonLoader /> }`
- ✅ 只在auth加载完成后显示内容

#### 任务D: Activity页面添加加载状态 ✅ DONE
**文件:** `src/app/activity/page.tsx`

修改内容:
- ✅ 导入 ActivityPageSkeletonLoader
- ✅ 获取 isUserLoading 从 useGlobalAuthCompatible
- ✅ 添加加载状态检查: `if (isUserLoading) { return <ActivityPageSkeletonLoader /> }`
- ✅ 只在auth加载完成后显示活动列表

#### 任务E: 优化加载时间 ✅ IN PROGRESS
**目标:** < 500ms

改进策略:
- ✅ 减少不必要的re-render (通过加载UI)
- ✅ 全局auth context避免重复初始化
- ⏳ 可以通过性能监控进一步优化

---

### 第4阶段：跨标签页通信

#### 任务A: 实现跨标签页同步
**创建文件:** `src/hooks/use-auth-sync.ts`

```typescript
import { useEffect } from 'react';

export function useAuthSync() {
  useEffect(() => {
    // 监听storage事件实现跨标签页同步
    const handleStorageChange = (e: StorageEvent) => {
      if (e.key === 'auth-state-change') {
        // 触发auth重新加载
        window.location.reload();
      }
    };

    window.addEventListener('storage', handleStorageChange);
    return () => window.removeEventListener('storage', handleStorageChange);
  }, []);
}
```

---

## 📊 改进检查清单

### 第1阶段 (已完成) ✅
- [x] 修复POST页面登入提示逻辑
- [x] 移除localStorage头像依赖
- [x] 创建全局认证上下文框架

### 第2阶段 (已完成) ✅
- [x] 在layout.tsx集成AuthContextProvider
- [x] 迁移所有页面使用全局上下文
  - [x] POST页面
  - [x] Profile页面
  - [x] Activity页面
  - [x] Search页面
- [x] 测试跨页面状态同步

### 第3阶段 (已完成) ✅
- [x] 创建骨架屏加载器
- [x] POST页面添加加载UI
- [x] Profile页面添加加载UI
- [x] Activity页面添加加载UI
- [x] 优化加载时间 (初步完成，预期 < 1s)

### 第4阶段 (待完成)
- [ ] 实现跨标签页通信
- [ ] 添加缓存策略
- [ ] 实现离线支持

---

## 🧪 测试步骤

### 测试1: 已登入用户打开POST页面
```
1. 登入应用
2. 打开/post页面
✓ 期望: 直接显示表单，不弹出登入对话框
✓ 预期加载时间: < 1秒
```

### 测试2: 跨设备头像一致性
```
1. iPhone上: 上传新头像
2. iPad上: 打开应用
✓ 期望: 看到iPhone上的新头像
✓ 其他用户: 看到新头像
```

### 测试3: 跨页面导航
```
1. 在Profile页面登入
2. 点击底部导航到POST
✓ 期望: POST页面已识别登入状态
✓ 登入状态应该立即可用
```

### 测试4: 多标签页
```
1. 标签页1: 打开应用 (未登入)
2. 标签页2: 登入
✓ 期望: 标签页1自动更新显示已登入
```

---

## 📈 性能目标

| 指标 | 当前 | 目标 | 优先级 |
|-----|------|------|--------|
| POST页面首屏显示 | 2-3s | < 1s | 🔴 |
| 头像加载时间 | 2-3s | < 500ms | 🟠 |
| 登入状态检查 | 1-2s | < 300ms | 🟠 |
| 跨页面同步 | 不同步 | 同步 | 🔴 |

---

## 代码审查检查点

在完成每个任务前，检查：

- [ ] 没有新增 console.error
- [ ] 没有使用 localStorage 存储敏感数据
- [ ] 使用了 isLoading 标志检查
- [ ] 添加了适当的类型定义
- [ ] 测试了所有浏览器标签
- [ ] 测试了移动端
- [ ] 添加了注释解释修复内容

---

## 回滚计划

如果发现问题，可以快速回滚：

1. POST页面修复: `git diff src/app/post/page.tsx`
2. 头像修复: `git diff src/app/profile/page.tsx src/components/swap-norge/FooterNav.tsx`
3. 认证上下文: `git rm src/contexts/`

---

## 下一步行动

### 今天完成
✅ 1️⃣ 修复POST登入检查 - DONE
✅ 2️⃣ 修复头像同步 - DONE
✅ 3️⃣ 创建认证上下文框架 - DONE

### 明天/本周
- 集成AuthContextProvider
- 添加加载状态UI
- 进行完整测试

### 本月
- 实现跨标签页同步
- 添加离线支持
- 性能优化

