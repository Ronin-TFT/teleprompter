#import <Cocoa/Cocoa.h>
#import "TPAppDelegate.h"

static NSMenu *TPBuildMainMenu(void) {
    NSMenu *menuBar = [NSMenu new];

    NSMenuItem *appItem = [[NSMenuItem alloc] initWithTitle:@"口播提词器" action:nil keyEquivalent:@""];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"口播提词器"];
    [appMenu addItemWithTitle:@"隐藏口播提词器" action:@selector(hide:) keyEquivalent:@"h"];
    [appMenu addItem:NSMenuItem.separatorItem];
    [appMenu addItemWithTitle:@"退出口播提词器" action:@selector(terminate:) keyEquivalent:@"q"];
    appItem.submenu = appMenu;
    [menuBar addItem:appItem];

    NSMenuItem *fileItem = [[NSMenuItem alloc] initWithTitle:@"文件" action:nil keyEquivalent:@""];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"文件"];
    [fileMenu addItemWithTitle:@"导入稿子…" action:@selector(importScript:) keyEquivalent:@"o"];
    [fileMenu addItemWithTitle:@"关闭窗口" action:@selector(performClose:) keyEquivalent:@"w"];
    fileItem.submenu = fileMenu;
    [menuBar addItem:fileItem];

    NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:@"编辑" action:nil keyEquivalent:@""];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"编辑"];
    [editMenu addItemWithTitle:@"撤销" action:@selector(undo:) keyEquivalent:@"z"];
    [editMenu addItemWithTitle:@"重做" action:@selector(redo:) keyEquivalent:@"Z"];
    [editMenu addItem:NSMenuItem.separatorItem];
    [editMenu addItemWithTitle:@"剪切" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"复制" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"粘贴" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"全选" action:@selector(selectAll:) keyEquivalent:@"a"];
    editItem.submenu = editMenu;
    [menuBar addItem:editItem];

    NSMenuItem *windowItem = [[NSMenuItem alloc] initWithTitle:@"窗口" action:nil keyEquivalent:@""];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"窗口"];
    [windowMenu addItemWithTitle:@"稿子窗口" action:@selector(showEditor:) keyEquivalent:@"1"];
    [windowMenu addItemWithTitle:@"显示/隐藏提词器" action:@selector(togglePrompter:) keyEquivalent:@"2"];
    [windowMenu addItem:NSMenuItem.separatorItem];
    [windowMenu addItemWithTitle:@"最小化" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    windowItem.submenu = windowMenu;
    [menuBar addItem:windowItem];
    NSApp.windowsMenu = windowMenu;

    return menuBar;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        TPAppDelegate *delegate = [TPAppDelegate new];
        app.delegate = delegate;
        app.mainMenu = TPBuildMainMenu();
        [app run];
    }
    return 0;
}
