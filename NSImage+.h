//
//  NSImage+.h
//  FBCocoa
//
//  Created by Lee Byron on 11/9/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSImage (FBCocoa)

- (void)resizeToFit:(NSSize)size
          usingMode:(NSImageScaling)scale;

@end
