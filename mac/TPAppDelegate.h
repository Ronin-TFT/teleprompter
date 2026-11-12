#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 管理两个窗口：稿子窗口（编辑模式）与提词悬浮窗（提词模式），并在两者之间转发消息。
@interface TPAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate, WKScriptMessageHandler>
- (IBAction)showEditor:(nullable id)sender;
- (IBAction)togglePrompter:(nullable id)sender;
- (IBAction)importScript:(nullable id)sender;
@end

NS_ASSUME_NONNULL_END
