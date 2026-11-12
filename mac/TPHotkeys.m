#import "TPHotkeys.h"
#import <Carbon/Carbon.h>

@interface TPHotkey ()
@property (nonatomic, readwrite) UInt32 keyCode;
@property (nonatomic, readwrite) UInt32 carbonModifiers;
@property (nonatomic, readwrite, copy) NSString *command;
@property (nonatomic, readwrite, copy) NSString *displayName;
@end

@implementation TPHotkey

+ (instancetype)key:(UInt32)keyCode name:(NSString *)name command:(NSString *)command {
    TPHotkey *hotkey = [TPHotkey new];
    hotkey.keyCode = keyCode;
    hotkey.carbonModifiers = cmdKey | optionKey;
    hotkey.command = command;
    hotkey.displayName = name;
    return hotkey;
}

+ (NSArray<TPHotkey *> *)defaultHotkeys {
    return @[
        [self key:kVK_ANSI_P name:@"⌥⌘P" command:@"toggle"],
        [self key:kVK_ANSI_Equal name:@"⌥⌘=" command:@"faster"],
        [self key:kVK_ANSI_Minus name:@"⌥⌘-" command:@"slower"],
        [self key:kVK_ANSI_LeftBracket name:@"⌥⌘[" command:@"back"],
        [self key:kVK_ANSI_RightBracket name:@"⌥⌘]" command:@"forward"],
        [self key:kVK_ANSI_R name:@"⌥⌘R" command:@"restart"],
        [self key:kVK_ANSI_T name:@"⌥⌘T" command:@"show"],
    ];
}

@end

@interface TPHotkeyCenter () {
    EventHandlerRef _handlerRef;
}
@property (nonatomic, strong) NSMutableArray<NSValue *> *refs;
@property (nonatomic, strong) NSArray<TPHotkey *> *hotkeys;
- (void)fire:(UInt32)identifier;
@end

static OSStatus TPHotkeyEventHandler(EventHandlerCallRef next, EventRef event, void *userData) {
    EventHotKeyID hotkeyID;
    if (GetEventParameter(event, kEventParamDirectObject, typeEventHotKeyID, NULL,
                          sizeof(hotkeyID), NULL, &hotkeyID) != noErr) return eventNotHandledErr;
    [(__bridge TPHotkeyCenter *)userData fire:hotkeyID.id];
    return noErr;
}

@implementation TPHotkeyCenter

- (instancetype)init {
    if ((self = [super init])) {
        _refs = [NSMutableArray array];
        EventTypeSpec type = {kEventClassKeyboard, kEventHotKeyPressed};
        InstallEventHandler(GetApplicationEventTarget(), TPHotkeyEventHandler, 1, &type, (__bridge void *)self, &_handlerRef);
    }
    return self;
}

- (void)fire:(UInt32)identifier {
    if (identifier == 0 || identifier > self.hotkeys.count || !self.handler) return;
    self.handler(self.hotkeys[identifier - 1].command);
}

- (NSArray<NSString *> *)registerHotkeys:(NSArray<TPHotkey *> *)hotkeys {
    [self unregisterAll];
    self.hotkeys = [hotkeys copy];
    NSMutableArray<NSString *> *failed = [NSMutableArray array];
    for (UInt32 i = 0; i < hotkeys.count; i++) {
        EventHotKeyRef ref = NULL;
        EventHotKeyID hotkeyID = {'TPRM', i + 1};
        if (RegisterEventHotKey(hotkeys[i].keyCode, hotkeys[i].carbonModifiers, hotkeyID,
                                GetApplicationEventTarget(), 0, &ref) == noErr && ref) {
            [self.refs addObject:[NSValue valueWithPointer:ref]];
        } else {
            [failed addObject:hotkeys[i].displayName];
        }
    }
    return failed;
}

- (void)unregisterAll {
    for (NSValue *value in self.refs) UnregisterEventHotKey((EventHotKeyRef)value.pointerValue);
    [self.refs removeAllObjects];
}

- (void)dealloc {
    [self unregisterAll];
    if (_handlerRef) RemoveEventHandler(_handlerRef);
}

@end
