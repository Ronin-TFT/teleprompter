// 生成 1024×1024 的应用图标：深色圆角底、三行文字、黄色阅读线。
// 用法：make_icon <输出 png 路径>
#import <Cocoa/Cocoa.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc < 2) return 1;
        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:1024 pixelsHigh:1024
                                                                     bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
                                                                    colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
        [NSGraphicsContext saveGraphicsState];
        NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
        [[NSColor clearColor] setFill];
        NSRectFill(NSMakeRect(0, 0, 1024, 1024));

        [[NSColor colorWithRed:0.12 green:0.13 blue:0.16 alpha:1] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(100, 100, 824, 824) xRadius:180 yRadius:180] fill];

        // 已读的行（暗）、当前行（亮）、未读的行（暗）
        NSColor *dim = [NSColor colorWithWhite:1 alpha:0.35];
        [dim setFill];
        [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(220, 660, 520, 56) xRadius:28 yRadius:28] fill];
        [[NSColor whiteColor] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(220, 500, 600, 64) xRadius:32 yRadius:32] fill];
        [dim setFill];
        [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(220, 340, 440, 56) xRadius:28 yRadius:28] fill];

        // 阅读线与三角标记
        NSColor *yellow = [NSColor colorWithRed:1 green:0.81 blue:0.43 alpha:1];
        [yellow setFill];
        NSRectFill(NSMakeRect(220, 456, 640, 12));
        NSBezierPath *triangle = [NSBezierPath bezierPath];
        [triangle moveToPoint:NSMakePoint(160, 422)];
        [triangle lineToPoint:NSMakePoint(160, 502)];
        [triangle lineToPoint:NSMakePoint(214, 462)];
        [triangle closePath];
        [triangle fill];

        [NSGraphicsContext restoreGraphicsState];
        NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        return [png writeToFile:[NSString stringWithUTF8String:argv[1]] atomically:YES] ? 0 : 1;
    }
}
