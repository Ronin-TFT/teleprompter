#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// 一个全局快捷键：command 为发给提词窗口的命令名（show 表示显示/隐藏提词器）。
@interface TPHotkey : NSObject
@property (nonatomic, readonly) UInt32 keyCode;
@property (nonatomic, readonly) UInt32 carbonModifiers;
@property (nonatomic, readonly, copy) NSString *command;
@property (nonatomic, readonly, copy) NSString *displayName;
+ (NSArray<TPHotkey *> *)defaultHotkeys;
@end

/// 全局快捷键（Carbon），应用在后台时也能触发。
@interface TPHotkeyCenter : NSObject
@property (nonatomic, copy, nullable) void (^handler)(NSString *command);
/// 注册全部快捷键，返回注册失败（被占用）的快捷键名称。
- (NSArray<NSString *> *)registerHotkeys:(NSArray<TPHotkey *> *)hotkeys;
- (void)unregisterAll;
@end

NS_ASSUME_NONNULL_END
