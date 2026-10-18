# 无 Mac 安装指南

没有 Mac 也能编译安装此 App，使用 **GitHub Actions 云编译** + **Sideloadly 侧载**。

## 方案概览

```
你的 Windows 电脑 → GitHub(上传代码) → Actions云编译(免费Mac) → 下载.ipa → Sideloadly签名安装 → iPhone
```

## 第一步：准备 GitHub 仓库

### 1. 注册/登录 GitHub
访问 https://github.com 注册账号（免费）。

### 2. 创建新仓库
- 点击右上角 `+` → `New repository`
- Repository name: `D-MAP-iOS`
- 选择 `Public`（公开仓库，Actions 免费无限制）
- 勾选 `Add a README file`（可选）
- 点击 `Create repository`

### 3. 上传代码
有两种方式：

**方式 A：网页上传（推荐新手）**
1. 进入刚创建的仓库页面
2. 点击 `Add file` → `Upload files`
3. 把 `D-MAP-iOS` 文件夹里的**所有内容**拖进去（包括 `.github` 文件夹、`D-MAP-iOS` 文件夹、`D-MAP-iOS.xcodeproj`、`README.md`）
   - 注意：`.github` 文件夹在 Windows 上是隐藏的，需要先显示隐藏文件
4. 点击 `Commit changes`

**方式 B：Git 命令行（如果你装了 Git）**
```bash
cd D-MAP-iOS
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/你的用户名/D-MAP-iOS.git
git push -u origin main
```

## 第二步：触发云编译

1. 进入仓库页面，点击顶部的 `Actions` 标签
2. 左侧选择 `Build D-MAP iOS App`
3. 点击右侧 `Run workflow` → 选择 `main` 分支 → 点击绿色 `Run workflow` 按钮
4. 等待编译完成（约 3-5 分钟）
   - 黄色圆点 = 正在编译
   - 绿色对勾 = 编译成功
   - 红色叉号 = 编译失败（点进去看日志）

## 第三步：下载编译产物

1. 编译成功后，点击该次运行记录
2. 页面底部 `Artifacts` 区域有两个文件：
   - `D-MAP-iOS` → 包含 `D-MAP.ipa`（推荐下载这个）
   - `D-MAP-app-bundle` → .app 包
3. 点击 `D-MAP-iOS` 下载，解压得到 `D-MAP.ipa`

## 第四步：用 Sideloadly 安装到 iPhone

### 1. 下载 Sideloadly
- 官网：https://sideloadly.io/
- 下载 Windows 版并安装
- 安装过程中会提示安装 iTunes（必须安装，用于驱动 iPhone）

### 2. 准备 iPhone
- 用数据线连接 iPhone 到电脑
- iPhone 上点击「信任此电脑」
- 确保 iPhone 已解锁

### 3. 签名安装
1. 打开 Sideloadly
2. `IPA` 栏：选择下载的 `D-MAP.ipa`
3. `Apple Account`：输入你的 Apple ID（免费账号即可）
4. 点击 `Start`
5. 弹出密码框输入 Apple ID 密码（或应用专用密码）
6. 等待安装完成（约 1-2 分钟）

### 4. 信任开发者
1. iPhone 上打开 `设置` → `通用` → `VPN与设备管理`
2. 找到你的 Apple ID 对应的开发者证书
3. 点击「信任」
4. 回到桌面打开 D-MAP App

## 免费 Apple ID 的限制

- 每 7 天需要重新签名安装一次（Sideloadly 重新操作即可）
- 最多同时侧载 3 个 App
- 无法推送通知到手表（但 App 内功能正常）
- 如果需要永久签名，需要 99 美元/年的 Apple 开发者账号

## 常见问题

### Q: GitHub Actions 编译失败？
A: 点进失败的运行记录，查看日志错误。常见原因：
- 代码上传不完整（确认 `.github/workflows/build.yml` 存在）
- Xcode 项目文件损坏

### Q: Sideloadly 提示错误？
A:
- 确保安装了最新版 iTunes
- 换一根数据线（有些线只能充电不能传数据）
- iPhone 上必须点击「信任此电脑」

### Q: 7 天后 App 打不开？
A: 免费签名过期，用 Sideloadly 重新签名安装一次即可，数据不会丢失。

### Q: 可以不用 GitHub 吗？
A: 可以用其他云编译服务：
- **Codemagic**：https://codemagic.io （免费额度有限）
- **Appcircle**：https://appcircle.io （有免费层）
- **MacinCloud**：https://www.macincloud.com （付费远程 Mac）

但 GitHub Actions 是最方便且完全免费的方案。

## 替代方案：借 Mac 编译

如果身边有朋友用 Mac：
1. 把 `D-MAP-iOS` 文件夹拷贝过去
2. 双击 `D-MAP-iOS.xcodeproj` 打开
3. 连接 iPhone，按 `Cmd+R` 直接编译安装
4. 整个过程 5 分钟搞定
