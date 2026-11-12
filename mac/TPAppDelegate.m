#import "TPAppDelegate.h"
#import "TPHotkeys.h"
#import "TPSupport.h"

@interface TPAppDelegate ()
@property (nonatomic, strong) NSWindow *editorWindow;
@property (nonatomic, strong) WKWebView *editorView;
@property (nonatomic, strong) NSPanel *prompterPanel;
@property (nonatomic, strong) WKWebView *prompterView;
@property (nonatomic, strong) TPHotkeyCenter *hotkeyCenter;
@property (nonatomic, copy, nullable) NSDictionary *lastUpdate;
@property (nonatomic) BOOL prompterReady;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *pendingForPrompter;
@end

@implementation TPAppDelegate

#pragma mark - 启动

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.pendingForPrompter = [NSMutableArray array];
    [self buildEditor];
    [self buildPrompter];

    self.hotkeyCenter = [TPHotkeyCenter new];
    __weak TPAppDelegate *weakSelf = self;
    self.hotkeyCenter.handler = ^(NSString *command) { [weakSelf runCommand:command fromHotkey:YES]; };
    NSArray<NSString *> *failed = [self.hotkeyCenter registerHotkeys:TPHotkey.defaultHotkeys];
    if (failed.count) {
        [self sendToEditor:@{@"type": @"status",
                             @"text": [NSString stringWithFormat:@"以下快捷键已被其他软件占用：%@", [failed componentsJoinedByString:@"、"]]}];
    }

    [self showEditor:nil];
    [self.prompterPanel orderFront:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app { return NO; }

- (BOOL)applicationShouldHandleReopen:(NSApplication *)app hasVisibleWindows:(BOOL)visible {
    [self showEditor:nil];
    return YES;
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app { return YES; }

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self.hotkeyCenter unregisterAll];
}

- (NSURL *)pageURLWithMode:(NSString *)mode {
    NSURL *file = [NSBundle.mainBundle URLForResource:@"app" withExtension:@"html"];
    return [NSURL URLWithString:[file.absoluteString stringByAppendingFormat:@"#%@", mode]];
}

- (WKWebView *)webViewWithMode:(NSString *)mode initialScript:(nullable NSString *)script {
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    [config.userContentController addScriptMessageHandler:self name:@"tp"];
    if (script) {
        WKUserScript *userScript = [[WKUserScript alloc] initWithSource:script
                                                          injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                       forMainFrameOnly:YES];
        [config.userContentController addUserScript:userScript];
    }
    WKWebView *view = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600) configuration:config];
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    NSURL *page = [self pageURLWithMode:mode];
    [view loadFileURL:page allowingReadAccessToURL:page.URLByDeletingLastPathComponent];
    return view;
}

- (void)buildEditor {
    self.editorWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1000, 660)
                                                    styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                              NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO];
    self.editorWindow.title = @"口播提词器";
    self.editorWindow.releasedWhenClosed = NO;
    self.editorWindow.contentMinSize = NSMakeSize(760, 520);
    [self.editorWindow center];
    [self.editorWindow setFrameAutosaveName:@"EditorWindow"];
    self.editorView = [self webViewWithMode:@"editor" initialScript:TPInitialStateScript(NSUserDefaults.standardUserDefaults)];
    self.editorView.frame = self.editorWindow.contentView.bounds;
    [self.editorWindow.contentView addSubview:self.editorView];
}

- (void)buildPrompter {
    NSRect visible = NSScreen.mainScreen.visibleFrame;
    NSRect frame = NSMakeRect(NSMidX(visible) - 380, NSMaxY(visible) - 300, 760, 280);
    self.prompterPanel = [[NSPanel alloc] initWithContentRect:frame
                                                    styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                              NSWindowStyleMaskResizable | NSWindowStyleMaskNonactivatingPanel
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO];
    NSPanel *panel = self.prompterPanel;
    panel.title = @"提词器";
    panel.titleVisibility = NSWindowTitleHidden;
    panel.titlebarAppearsTransparent = YES;
    panel.releasedWhenClosed = NO;
    panel.floatingPanel = YES;
    panel.hidesOnDeactivate = NO;
    panel.becomesKeyOnlyIfNeeded = NO;
    panel.level = NSStatusWindowLevel;
    panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
    panel.opaque = NO;
    panel.hasShadow = NO;
    panel.backgroundColor = [NSColor colorWithWhite:0 alpha:0.75];
    panel.movableByWindowBackground = YES;
    panel.minSize = NSMakeSize(320, 160);
    panel.delegate = self;
    panel.sharingType = NSWindowSharingNone;
    [panel setFrameAutosaveName:@"PrompterPanel"];

    self.prompterView = [self webViewWithMode:@"prompter" initialScript:nil];
    // 透明背景，让窗口的半透明黑色透出来。
    @try {
        [self.prompterView setValue:@NO forKey:@"drawsBackground"];
    } @catch (NSException *exception) {
    }
    self.prompterView.frame = panel.contentView.bounds;
    [panel.contentView addSubview:self.prompterView];
}

#pragma mark - 窗口

- (void)showEditor:(id)sender {
    [self.editorWindow makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)togglePrompter:(id)sender {
    if (self.prompterPanel.isVisible) {
        [self sendToPrompter:@{@"type": @"command", @"command": @"pause"}];
        [self.prompterPanel orderOut:nil];
    } else {
        [self.prompterPanel orderFront:nil];
    }
}

- (BOOL)windowShouldClose:(NSWindow *)window {
    if (window == self.prompterPanel) {
        [self togglePrompter:nil];
        return NO;
    }
    return YES;
}

- (void)applyWindowSettings:(NSDictionary *)settings {
    if (![settings isKindOfClass:NSDictionary.class]) return;
    NSNumber *opacity = settings[@"opacity"];
    if ([opacity isKindOfClass:NSNumber.class]) {
        CGFloat alpha = MIN(MAX(opacity.doubleValue / 100.0, 0), 1);
        // 完全透明时保留一点点背景，否则鼠标无法拖动窗口。
        self.prompterPanel.backgroundColor = [NSColor colorWithWhite:0 alpha:MAX(alpha, 0.01)];
    }
    NSNumber *hide = settings[@"hideFromCapture"];
    if ([hide isKindOfClass:NSNumber.class]) {
        self.prompterPanel.sharingType = hide.boolValue ? NSWindowSharingNone : NSWindowSharingReadOnly;
    }
}

#pragma mark - 消息

- (void)sendTo:(WKWebView *)view message:(NSDictionary *)message {
    NSString *js = TPJavaScriptCall(message);
    if (js) [view evaluateJavaScript:js completionHandler:nil];
}

- (void)sendToEditor:(NSDictionary *)message {
    [self sendTo:self.editorView message:message];
}

- (void)sendToPrompter:(NSDictionary *)message {
    if (!self.prompterReady) {
        [self.pendingForPrompter addObject:message];
        return;
    }
    [self sendTo:self.prompterView message:message];
}

- (void)runCommand:(NSString *)command fromHotkey:(BOOL)fromHotkey {
    if ([command isEqualToString:@"show"]) {
        if (fromHotkey) {
            [self togglePrompter:nil];
        } else {
            [self.prompterPanel orderFront:nil];
        }
        return;
    }
    if (([command isEqualToString:@"toggle"] || [command isEqualToString:@"restart"] || [command isEqualToString:@"play"]) &&
        !self.prompterPanel.isVisible) {
        [self.prompterPanel orderFront:nil];
    }
    [self sendToPrompter:@{@"type": @"command", @"command": command}];
}

- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message {
    NSDictionary *body = [message.body isKindOfClass:NSDictionary.class] ? message.body : nil;
    NSString *type = [body[@"type"] isKindOfClass:NSString.class] ? body[@"type"] : nil;
    if (!type) return;

    if (message.webView == self.editorView) {
        if ([type isEqualToString:@"update"]) {
            self.lastUpdate = body;
            [self applyWindowSettings:body[@"settings"]];
            [self sendToPrompter:body];
        } else if ([type isEqualToString:@"store"]) {
            TPSaveState(body[@"state"], NSUserDefaults.standardUserDefaults);
        } else if ([type isEqualToString:@"command"] && [body[@"command"] isKindOfClass:NSString.class]) {
            [self runCommand:body[@"command"] fromHotkey:NO];
        } else if ([type isEqualToString:@"import"]) {
            [self importScript:nil];
        }
        return;
    }

    if (message.webView == self.prompterView) {
        if ([type isEqualToString:@"ready"]) {
            self.prompterReady = YES;
            if (self.lastUpdate) [self sendTo:self.prompterView message:self.lastUpdate];
            for (NSDictionary *pending in self.pendingForPrompter) {
                if (![pending[@"type"] isEqual:@"update"]) [self sendTo:self.prompterView message:pending];
            }
            [self.pendingForPrompter removeAllObjects];
        } else if ([type isEqualToString:@"hide"]) {
            [self.prompterPanel orderOut:nil];
        } else if ([type isEqualToString:@"position"] || [type isEqualToString:@"playback"] || [type isEqualToString:@"settings"]) {
            [self sendToEditor:body];
        }
    }
}

#pragma mark - 导入

- (void)importScript:(id)sender {
    [self showEditor:nil];
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.title = @"导入稿子";
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    [panel beginSheetModalForWindow:self.editorWindow completionHandler:^(NSModalResponse response) {
        if (response != NSModalResponseOK || !panel.URL) return;
        NSError *error = nil;
        NSString *text = TPReadTextFile(panel.URL, &error);
        if (!text) {
            [self sendToEditor:@{@"type": @"status", @"text": [@"导入失败：" stringByAppendingString:error.localizedDescription ?: @"未知错误"]}];
            return;
        }
        [self sendToEditor:@{@"type": @"imported", @"text": text, @"name": panel.URL.lastPathComponent ?: @"稿子"}];
    }];
}

@end
