#import "UVCKitStringAdditions.h"

@implementation NSString (UVCKitStringAdditions)

- (BOOL) containsString:(NSString *)n	{
	BOOL		returnMe = NO;
	if (n != nil)	{
		NSRange		foundRange = [self rangeOfString:n];
		if (foundRange.location!=NSNotFound && foundRange.length==[n length])
			returnMe = YES;
	}
	return returnMe;
}

@end
