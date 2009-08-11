//
//  FBRequest.h
//  FBCocoa
//
//  Created by Lee Byron on 7/30/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FBRequest : NSURLConnection {
  id  target;
  SEL method;
  SEL errorMethod;
  NSMutableData *responseBuffer;
}

-(id)initWithRequest:(NSURLRequest *)req
              target:(id)tar
            selector:(SEL)sel
               error:(SEL)err;

@end
