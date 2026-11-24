import SwiftUI

// MARK: - 安卓原版 D-MAP 视觉主题
// 取自真机截图：蓝色渐变顶栏、浅蓝页面背景、白色圆角分组卡片、彩色小图标
enum DMapTheme {
    static let brandBlue   = Color(red: 0.18, green: 0.62, blue: 0.85)
    static let topDark     = Color(red: 0.13, green: 0.44, blue: 0.65)
    static let topLight    = Color(red: 0.22, green: 0.66, blue: 0.90)
    static let headerTop   = Color(red: 0.36, green: 0.76, blue: 0.94)
    static let headerBot   = Color(red: 0.20, green: 0.63, blue: 0.87)
    static let pageBg      = Color(red: 0.91, green: 0.97, blue: 0.995)
    static let cardBg      = Color.white
    static let textDark    = Color(red: 0.20, green: 0.22, blue: 0.25)
    static let textGray    = Color(red: 0.55, green: 0.58, blue: 0.62)
    static let tabNormal   = Color(red: 0.62, green: 0.66, blue: 0.70)
    static let divider     = Color(red: 0.90, green: 0.93, blue: 0.96)

    static let topBarGradient = LinearGradient(
        colors: [topLight, topDark], startPoint: .top, endPoint: .bottom)
    static let headerGradient = LinearGradient(
        colors: [headerTop, headerBot], startPoint: .top, endPoint: .bottom)
}

// MARK: - 顶部标题栏（安卓风格：居中标题、可选返回箭头、可选右上角按钮）
struct DMapTopBar: View {
    let title: String
    var showBack: Bool = false
    var onBack: (() -> Void)? = nil
    var trailing: AnyView? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            DMapTheme.topBarGradient
                .ignoresSafeArea(edges: .top)
            HStack {
                if showBack {
                    Button(action: { onBack?() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                } else {
                    Spacer().frame(width: 44)
                }
                Spacer()
                if let trailing = trailing { trailing }
                else { Spacer().frame(width: 44) }
            }
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .padding(.bottom, 14)
        }
        .frame(height: 92)
    }
}

// MARK: - 页面容器（浅蓝背景 + 安卓顶栏）
struct DMapPage<Content: View>: View {
    let title: String
    var showBack: Bool = false
    var onBack: (() -> Void)? = nil
    var trailing: AnyView? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            DMapTopBar(title: title, showBack: showBack, onBack: onBack, trailing: trailing)
            content()
        }
        .background(DMapTheme.pageBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - 白色圆角分组卡片容器
struct DMapCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0) { content() }
            .background(DMapTheme.cardBg)
            .cornerRadius(6)
            .padding(.horizontal, 8)
    }
}

// MARK: - 卡片行（安卓：左侧彩色线性图标 + 文字 + 右侧箭头/开关）
struct DMapRow: View {
    let icon: String
    let tint: Color
    let title: String
    var detail: String? = nil
    var showArrow: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(tint)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(DMapTheme.textDark)
                Spacer()
                if let detail = detail {
                    Text(detail)
                        .font(.system(size: 14))
                        .foregroundColor(DMapTheme.textGray)
                }
                if showArrow {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(red: 0.78, green: 0.81, blue: 0.85))
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 可跳转的卡片行
struct DMapNavRow<Destination: View>: View {
    let icon: String
    let tint: Color
    let title: String
    var detail: String? = nil
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(tint)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(DMapTheme.textDark)
                Spacer()
                if let detail = detail {
                    Text(detail)
                        .font(.system(size: 14))
                        .foregroundColor(DMapTheme.textGray)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(red: 0.78, green: 0.81, blue: 0.85))
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 开关行
struct DMapToggleRow: View {
    let icon: String
    let tint: Color
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(tint)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(DMapTheme.textDark)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(DMapTheme.brandBlue)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

// MARK: - 卡片内分隔线（左侧缩进，仿安卓列表 divider）
struct DMapRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(DMapTheme.divider)
            .frame(height: 0.5)
            .padding(.leading, 52)
    }
}

// MARK: - 底部四标签导航（安卓：白底、等分、选中蓝色）
enum DMapTab: Int, CaseIterable {
    case day = 0, analysis, play, mine

    var title: String {
        switch self {
        case .day: return "我的一天"
        case .analysis: return "分析"
        case .play: return "智玩"
        case .mine: return "我的"
        }
    }
    var icon: String {
        switch self {
        case .day: return "chart.bar.fill"
        case .analysis: return "doc.text"
        case .play: return "square.grid.2x2"
        case .mine: return "person.fill"
        }
    }
}

struct DMapTabBar: View {
    @Binding var selected: DMapTab

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(DMapTheme.divider).frame(height: 0.5)
            HStack(spacing: 0) {
                ForEach(DMapTab.allCases, id: \.rawValue) { tab in
                    Button(action: { selected = tab }) {
                        VStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 21))
                            Text(tab.title)
                                .font(.system(size: 10))
                        }
                        .foregroundColor(selected == tab ? DMapTheme.brandBlue : DMapTheme.tabNormal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.white)
        }
    }
}

// MARK: - 根视图：四个标签页
struct ContentView: View {
    @EnvironmentObject var viewModel: DeviceViewModel
    @State private var selectedTab: DMapTab = .day

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch selectedTab {
                case .day:
                    NavigationView { DayView() }
                        .navigationViewStyle(.stack)
                case .analysis:
                    NavigationView { AnalysisView() }
                        .navigationViewStyle(.stack)
                case .play:
                    NavigationView { PlayView() }
                        .navigationViewStyle(.stack)
                case .mine:
                    NavigationView { MineView() }
                        .navigationViewStyle(.stack)
                }
            }
            DMapTabBar(selected: $selectedTab)
        }
        .background(DMapTheme.pageBg.ignoresSafeArea())
    }
}

// MARK: - 通用二级页包装（带返回）
struct DMapSubPage<Content: View>: View {
    let title: String
    @Environment(\.dismiss) private var dismiss
    @ViewBuilder var content: () -> Content

    var body: some View {
        DMapPage(title: title, showBack: true, onBack: { dismiss() }) {
            content()
        }
    }
}

// MARK: - 空数据占位（安卓文案「暂无历史数据」）
struct DMapEmptyHint: View {
    let text: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 38))
                .foregroundColor(DMapTheme.tabNormal.opacity(0.5))
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(DMapTheme.textGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 46)
    }
}

#Preview {
    ContentView()
        .environmentObject(DeviceViewModel())
}
