//
//  FBCallback.h
//  FBCocoa
//
//  Created by Lee Byron on 10/13/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FBCallback : NSObject {
  id  target;
  SEL method;
  SEL errorMethod;
}

- (id)initWithTarget:(id)tar
            selector:(SEL)sel
               error:(SEL)err;

- (void)success:(id)json;

- (void)failure:(NSError *)err;

@end
