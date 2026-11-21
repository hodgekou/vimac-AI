// SPDX-License-Identifier: GPL-3.0-only

import Foundation

/// The interface language chosen in the settings.
public enum AppLanguage: String, Codable, Sendable, CaseIterable {
    /// Follow the language order of the system.
    case system
    case english
    case chinese
    case japanese

    /// The language to show, given the user's system language preferences
    /// (`Locale.preferredLanguages`, most preferred first).
    public func resolved(preferredLanguages: [String]) -> Language {
        switch self {
        case .english: return .english
        case .chinese: return .chinese
        case .japanese: return .japanese
        case .system:
            for identifier in preferredLanguages {
                let code = identifier.lowercased()
                if code.hasPrefix("zh") { return .chinese }
                if code.hasPrefix("ja") { return .japanese }
                if code.hasPrefix("en") { return .english }
            }
            return .english
        }
    }
}

/// A language the interface is translated into.
public enum Language: String, Sendable, CaseIterable {
    case english
    case chinese
    case japanese

    /// The language's own name for itself.
    public var nativeName: String {
        switch self {
        case .english: "English"
        case .chinese: "中文"
        case .japanese: "日本語"
        }
    }
}

/// Looks up interface text. The English text is the key, so a missing entry falls back to English.
public enum Localizer {
    public static func text(_ english: String, in language: Language) -> String {
        guard language != .english, let entry = table[english] else { return english }
        return language == .chinese ? entry.chinese : entry.japanese
    }

    /// Translates a format string and fills in its arguments.
    public static func text(_ english: String, in language: Language, _ arguments: [any CVarArg]) -> String {
        String(format: text(english, in: language), arguments: arguments)
    }

    struct Entry {
        let chinese: String
        let japanese: String
    }

    static let table: [String: Entry] = [
        // Panes
        "General": Entry(chinese: "通用", japanese: "一般"),
        "Hints": Entry(chinese: "标签", japanese: "ヒント"),
        "Scrolling": Entry(chinese: "滚动", japanese: "スクロール"),
        "Activation": Entry(chinese: "激活方式", japanese: "起動方法"),
        "AI Detection": Entry(chinese: "AI 识别", japanese: "AI 検出"),
        "Shortcuts, startup and ignored apps": Entry(chinese: "快捷键、启动与忽略的应用", japanese: "ショートカット、起動、除外するアプリ"),
        "How labels look and behave": Entry(chinese: "标签的外观与行为", japanese: "ラベルの外観と動作"),
        "Speed and direction": Entry(chinese: "速度与方向", japanese: "速度と方向"),
        "Other ways to start a mode": Entry(chinese: "进入模式的其他方式", japanese: "モードを開始するほかの方法"),
        "Find text that apps do not expose": Entry(chinese: "找出应用没有暴露的文字", japanese: "アプリが公開していないテキストを見つける"),
        "Keyboard navigation": Entry(chinese: "键盘导航", japanese: "キーボード操作"),
        "Keyfari Settings": Entry(chinese: "Keyfari 设置", japanese: "Keyfari 設定"),

        // General
        "Shortcuts": Entry(chinese: "快捷键", japanese: "ショートカット"),
        "Show hints": Entry(chinese: "显示标签", japanese: "ヒントを表示"),
        "Label everything clickable": Entry(chinese: "给所有可点击的元素打标签", japanese: "クリックできる要素すべてにラベルを付ける"),
        "Search": Entry(chinese: "搜索", japanese: "検索"),
        "Find an element by its text": Entry(chinese: "按文字查找元素", japanese: "テキストで要素を探す"),
        "Scroll mode": Entry(chinese: "滚动模式", japanese: "スクロールモード"),
        "Scroll with H J K L": Entry(chinese: "用 H J K L 滚动", japanese: "H J K L でスクロール"),
        "Two modes share a shortcut, so the defaults are in use.": Entry(
            chinese: "有两个模式使用了相同的快捷键,已改用默认设置。", japanese: "2 つのモードが同じショートカットを使っているため、デフォルトを使用しています。"),
        "Press a shortcut…": Entry(chinese: "请按下快捷键…", japanese: "ショートカットを押してください…"),
        "Click, then press the new shortcut. Esc cancels.": Entry(chinese: "点击后按下新的快捷键,按 Esc 取消。", japanese: "クリックしてから新しいショートカットを押します。Esc でキャンセル。"),
        "Startup": Entry(chinese: "启动", japanese: "起動"),
        "Launch at login": Entry(chinese: "登录时启动", japanese: "ログイン時に起動"),
        "Start Keyfari when you log in": Entry(chinese: "登录系统时自动启动 Keyfari", japanese: "ログイン時に Keyfari を自動的に起動する"),
        "Language": Entry(chinese: "语言", japanese: "言語"),
        "Interface language": Entry(chinese: "界面语言", japanese: "表示言語"),
        "Takes effect immediately": Entry(chinese: "立即生效", japanese: "すぐに反映されます"),
        "System default": Entry(chinese: "跟随系统", japanese: "システムに合わせる"),
        "Ignored applications": Entry(chinese: "忽略的应用", japanese: "除外するアプリ"),
        "No applications are ignored": Entry(chinese: "没有忽略任何应用", japanese: "除外しているアプリはありません"),
        "Shortcuts do nothing while one of these applications is in front.": Entry(
            chinese: "这些应用在前台时,快捷键不起作用。",
            japanese: "これらのアプリが最前面にあるあいだ、ショートカットは動作しません。"
        ),
        "Add application": Entry(chinese: "添加应用", japanese: "アプリを追加"),
        "No other applications are running": Entry(chinese: "没有其他正在运行的应用", japanese: "ほかに実行中のアプリはありません"),
        "Remove": Entry(chinese: "移除", japanese: "削除"),

        // Hints
        "Appearance": Entry(chinese: "外观", japanese: "外観"),
        "Theme": Entry(chinese: "主题", japanese: "テーマ"),
        "Vivid": Entry(chinese: "多彩", japanese: "カラフル"),
        "Yellow": Entry(chinese: "黄色", japanese: "イエロー"),
        "Dark": Entry(chinese: "深色", japanese: "ダーク"),
        "Light": Entry(chinese: "浅色", japanese: "ライト"),
        "Label size": Entry(chinese: "标签字号", japanese: "ラベルのサイズ"),
        "Corner radius": Entry(chinese: "圆角", japanese: "角の丸み"),
        "Label characters": Entry(chinese: "标签字符", japanese: "ラベルの文字"),
        "Letters used for labels. Home-row keys first keeps your fingers still.": Entry(
            chinese: "用于生成标签的字母。把基准键位的字母放在前面,手指移动最少。",
            japanese: "ラベルに使う文字です。ホームポジションのキーを先頭にすると指の移動が少なくなります。"
        ),
        "Needs at least %d different letters. Using %@ for now.": Entry(
            chinese: "至少需要 %d 个不同的字母。目前使用 %@。",
            japanese: "異なる文字が %d 個以上必要です。現在は %@ を使用しています。"
        ),
        "Behaviour": Entry(chinese: "行为", japanese: "動作"),
        "Keep labels stable": Entry(chinese: "保持标签稳定", japanese: "ラベルを固定する"),
        "An element keeps the label it had when you last clicked it": Entry(chinese: "点过的元素下次仍使用同一个标签", japanese: "一度クリックした要素には次回も同じラベルを付ける"),
        "Chain clicks": Entry(chinese: "连续点击", japanese: "連続クリック"),
        "Stay in the mode after a click, until Esc or a text field": Entry(
            chinese: "点击后不退出模式,直到按 Esc 或点到输入框", japanese: "クリック後もモードを続ける(Esc またはテキスト欄をクリックするまで)"),

        // Scrolling
        "Speed": Entry(chinese: "速度", japanese: "速度"),
        "Scroll speed": Entry(chinese: "滚动速度", japanese: "スクロール速度"),
        "Speed with Shift": Entry(chinese: "按住 Shift 时的倍数", japanese: "Shift を押したときの倍率"),
        "Direction": Entry(chinese: "方向", japanese: "方向"),
        "Reverse horizontal": Entry(chinese: "反转水平方向", japanese: "左右を反転"),
        "Reverse vertical": Entry(chinese: "反转垂直方向", japanese: "上下を反転"),
        "Keys": Entry(chinese: "按键", japanese: "キー"),
        "Scroll left, down, up, right": Entry(chinese: "向左、下、上、右滚动", japanese: "左・下・上・右にスクロール"),
        "Half a page down, up": Entry(chinese: "向下、向上半页", japanese: "半ページ下・上"),
        "Top  ·  Shift-G for the bottom": Entry(chinese: "到顶部  ·  Shift-G 到底部", japanese: "先頭へ  ·  Shift-G で末尾へ"),
        "Next scroll area  ·  0–9 to jump": Entry(chinese: "下一个滚动区  ·  0–9 直接跳转", japanese: "次のスクロール領域  ·  0–9 で移動"),

        // Activation
        "Hold Space": Entry(chinese: "长按空格", japanese: "スペースを長押し"),
        "Hold Space to show hints": Entry(chinese: "长按空格显示标签", japanese: "スペースの長押しでヒントを表示"),
        "A short tap still types a space, when you release it": Entry(chinese: "短按仍会输入空格,在松开时输入", japanese: "短く押した場合は、離したときに空白が入力されます"),
        "Hold delay": Entry(chinese: "长按时长", japanese: "長押しの時間"),
        "Key sequences": Entry(chinese: "按键序列", japanese: "キーシーケンス"),
        "For example fd": Entry(chinese: "例如 fd", japanese: "例: fd"),
        "For example jk": Entry(chinese: "例如 jk", japanese: "例: jk"),
        "Timeout": Entry(chinese: "超时", japanese: "タイムアウト"),
        "At least two characters, and neither sequence may start with the other.": Entry(
            chinese: "至少两个字符,且两个序列不能互为前缀。",
            japanese: "2 文字以上で、一方がもう一方の先頭と一致しないようにしてください。"
        ),
        "off": Entry(chinese: "关闭", japanese: "オフ"),

        // AI detection
        "On-screen text detection": Entry(chinese: "屏幕文字识别", japanese: "画面上のテキスト検出"),
        "Detect text": Entry(chinese: "识别文字", japanese: "テキストを検出"),
        "Off": Entry(chinese: "关闭", japanese: "オフ"),
        "When needed": Entry(chinese: "需要时", japanese: "必要なとき"),
        "Always": Entry(chinese: "始终", japanese: "常に"),
        "Reads the window's pixels on this Mac to label text the application does not expose. Nothing is saved or sent anywhere.": Entry(
            chinese: "在本机读取窗口画面,给应用没有暴露的文字打标签。不保存,也不发送任何内容。",
            japanese: "この Mac 上でウインドウの画面を読み取り、アプリが公開していないテキストにラベルを付けます。保存や送信は一切行いません。"
        ),
        "Screen Recording permission": Entry(chinese: "屏幕录制权限", japanese: "画面収録の許可"),
        "Status": Entry(chinese: "状态", japanese: "状態"),
        "Turn it on in System Settings, then restart Keyfari": Entry(
            chinese: "在系统设置里打开开关,然后重启 Keyfari", japanese: "システム設定でオンにしてから、Keyfari を再起動してください"),
        "Restart": Entry(chinese: "重启", japanese: "再起動"),
        "Granted": Entry(chinese: "已授权", japanese: "許可済み"),
        "Not granted": Entry(chinese: "未授权", japanese: "未許可"),
        "Request…": Entry(chinese: "申请…", japanese: "リクエスト…"),

        // Menu bar
        "Accessibility: Granted": Entry(chinese: "辅助功能:已授权", japanese: "アクセシビリティ: 許可済み"),
        "Grant Accessibility Permission…": Entry(chinese: "授予辅助功能权限…", japanese: "アクセシビリティを許可…"),
        "Show Hints": Entry(chinese: "显示标签", japanese: "ヒントを表示"),
        "Scroll Mode": Entry(chinese: "滚动模式", japanese: "スクロールモード"),
        "Ignore %@": Entry(chinese: "忽略 %@", japanese: "%@ を除外"),
        "Settings…": Entry(chinese: "设置…", japanese: "設定…"),
        "Quit Keyfari": Entry(chinese: "退出 Keyfari", japanese: "Keyfari を終了"),

        // Search bar
        "Type to search": Entry(chinese: "输入以搜索", japanese: "入力して検索"),
        "1 match": Entry(chinese: "1 个匹配", japanese: "1 件"),
        "%d matches": Entry(chinese: "%d 个匹配", japanese: "%d 件"),
    ]
}
