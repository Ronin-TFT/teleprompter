// 原生部分的回归测试（不打开窗口、不注册全局快捷键）。
// 构建运行：
//   clang -fobjc-arc -I mac tests/mac_test.m mac/TPSupport.m mac/TPHotkeys.m -framework Cocoa -framework Carbon -o build/mac-test && build/mac-test
#import <Cocoa/Cocoa.h>
#include <assert.h>
#import "TPHotkeys.h"
#import "TPSupport.h"

static NSURL *writeTemp(NSString *name, NSData *data) {
    NSURL *url = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:name];
    assert([data writeToURL:url atomically:YES]);
    return url;
}

int main(void) {
    @autoreleasepool {
        // 文本导入
        NSMutableData *utf8 = [NSMutableData dataWithBytes:"\xEF\xBB\xBF" length:3];
        [utf8 appendData:[@"大家好 hello" dataUsingEncoding:NSUTF8StringEncoding]];
        assert([TPReadTextFile(writeTemp(@"tp-utf8.txt", utf8), NULL) isEqualToString:@"大家好 hello"]);
        assert([TPReadTextFile(writeTemp(@"tp-utf16.txt", [@"口播" dataUsingEncoding:NSUTF16StringEncoding]), NULL) isEqualToString:@"口播"]);
        NSData *gb = [@"中文稿子" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)];
        assert([TPReadTextFile(writeTemp(@"tp-gb.txt", gb), NULL) isEqualToString:@"中文稿子"]);
        NSError *error = nil;
        assert(!TPReadTextFile(writeTemp(@"tp-bin.dat", [NSData dataWithBytes:"\x89PNG\0\0" length:6]), &error) && error);

        // 消息编码
        NSString *js = TPJavaScriptCall(@{@"type": @"imported", @"text": @"a\"b</script>\n"});
        assert([js hasPrefix:@"window.tp && window.tp.receive({"] && [js hasSuffix:@");"]);
        assert(TPJavaScriptCall(@{@"bad": [NSDate date]}) == nil);

        // 状态保存与注入
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"local.ronin.teleprompter.tests"];
        [defaults removeObjectForKey:@"state"];
        assert([TPInitialStateScript(defaults) isEqualToString:@"window.tpInitialState = {};"]);
        assert(TPSaveState(@{@"script": @"稿子", @"settings": @{@"speed": @240}}, defaults));
        NSString *script = TPInitialStateScript(defaults);
        assert([script containsString:@"\"script\":\"稿子\""] && [script containsString:@"240"]);
        assert(!TPSaveState(@"not a dictionary", defaults));
        [defaults setObject:@"[1,2" forKey:@"state"];
        assert([TPInitialStateScript(defaults) isEqualToString:@"window.tpInitialState = {};"]);
        [defaults removePersistentDomainForName:@"local.ronin.teleprompter.tests"];

        // 快捷键定义：名称、命令都不重复
        NSArray<TPHotkey *> *hotkeys = TPHotkey.defaultHotkeys;
        assert(hotkeys.count == 7);
        NSSet *commands = [NSSet setWithArray:[hotkeys valueForKey:@"command"]];
        NSSet *keys = [NSSet setWithArray:[hotkeys valueForKey:@"displayName"]];
        assert(commands.count == 7 && keys.count == 7 && [commands containsObject:@"toggle"] && [commands containsObject:@"show"]);

        // 界面文件存在，快捷键说明与原生定义一致
        NSString *html = [NSString stringWithContentsOfFile:@"web/app.html" encoding:NSUTF8StringEncoding error:NULL];
        assert(html.length > 0);
        for (NSString *name in @[@"⌥⌘P", @"⌥⌘R", @"⌥⌘T"]) assert([html containsString:name]);

        puts("text import, message encoding, state storage and hotkey definitions passed");
    }
    return 0;
}
