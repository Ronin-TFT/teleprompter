#import "TPSupport.h"

static NSString *const TPStateKey = @"state";
static const NSUInteger TPMaxTextFileBytes = 10 * 1024 * 1024;

static NSError *TPError(NSString *message) {
    return [NSError errorWithDomain:@"Teleprompter" code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
}

NSString *TPReadTextFile(NSURL *url, NSError **error) {
    NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:error];
    if (!data) return nil;
    if (data.length > TPMaxTextFileBytes) {
        if (error) *error = TPError(@"文件超过 10 MB，无法导入");
        return nil;
    }
    const uint8_t *bytes = data.bytes;
    NSString *text = nil;
    if (data.length >= 2 && ((bytes[0] == 0xFF && bytes[1] == 0xFE) || (bytes[0] == 0xFE && bytes[1] == 0xFF))) {
        text = [[NSString alloc] initWithData:data encoding:NSUTF16StringEncoding];
    } else if (data.length == 0 || memchr(bytes, 0, data.length) == NULL) {
        text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!text) {
            NSStringEncoding gb = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
            text = [[NSString alloc] initWithData:data encoding:gb];
        }
    }
    if (!text) {
        if (error) *error = TPError(@"不是可识别的纯文本文件（支持 UTF-8、UTF-16、GB18030）");
        return nil;
    }
    unichar bom = 0xFEFF;
    if ([text hasPrefix:[NSString stringWithCharacters:&bom length:1]]) text = [text substringFromIndex:1];
    return text;
}

NSString *TPJavaScriptCall(NSDictionary *message) {
    if (![NSJSONSerialization isValidJSONObject:message]) return nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:message options:0 error:NULL];
    if (!json) return nil;
    NSString *body = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    return [NSString stringWithFormat:@"window.tp && window.tp.receive(%@);", body];
}

NSString *TPInitialStateScript(NSUserDefaults *defaults) {
    NSString *saved = [defaults stringForKey:TPStateKey];
    NSString *json = @"{}";
    if (saved.length) {
        id parsed = [NSJSONSerialization JSONObjectWithData:[saved dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
        if ([parsed isKindOfClass:NSDictionary.class]) json = saved;
    }
    return [NSString stringWithFormat:@"window.tpInitialState = %@;", json];
}

BOOL TPSaveState(id state, NSUserDefaults *defaults) {
    if (![state isKindOfClass:NSDictionary.class] || ![NSJSONSerialization isValidJSONObject:state]) return NO;
    NSData *json = [NSJSONSerialization dataWithJSONObject:state options:0 error:NULL];
    if (!json) return NO;
    [defaults setObject:[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] forKey:TPStateKey];
    return YES;
}
