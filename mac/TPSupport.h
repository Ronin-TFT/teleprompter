#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 读取纯文本文件：依次识别 UTF-16（带 BOM）、UTF-8、GB18030，最大 10 MB。
NSString *_Nullable TPReadTextFile(NSURL *url, NSError *_Nullable *_Nullable error);

/// 把消息编码为 window.tp.receive(...) 调用；无法编码时返回 nil。
NSString *_Nullable TPJavaScriptCall(NSDictionary *message);

/// 读取保存的状态（稿子、设置、阅读位置），生成在页面加载前注入的脚本。
NSString *TPInitialStateScript(NSUserDefaults *defaults);

/// 保存编辑窗口发来的状态；不是字典或无法编码时返回 NO。
BOOL TPSaveState(id state, NSUserDefaults *defaults);

NS_ASSUME_NONNULL_END
