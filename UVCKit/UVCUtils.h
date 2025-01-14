#import <Foundation/Foundation.h>

#define NSXLog(string, ...) \
	[UVCUtils logFile:__FILE__ lineNumber:__LINE__ format:(string), ##__VA_ARGS__]

NS_ASSUME_NONNULL_BEGIN

@interface UVCUtils : NSObject
+ (BOOL)isLogOn;
+ (void)closeLog;
+ (void)openLog;
+ (NSString *)logPath;
+ (void)showAlert:(NSString *)msg title:(NSString *)title window:(NSWindow *)window completionHandler:(void (^ _Nullable)(void))handler;
+ (void)logFile:(char *)sourceFile lineNumber:(int)lineNumber format:(NSString*)format, ...;
@end

NS_ASSUME_NONNULL_END
