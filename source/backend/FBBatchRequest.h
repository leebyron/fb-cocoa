//
//  FBBatchRequest.h
//  FBCocoa
//
//  Created by Lee Byron on 9/5/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FBRequest.h"


@interface FBBatchRequest : FBRequest {
  NSArray* requests;
}

-(id)initWithRequest:(NSString *)requestString
            requests:(NSArray *)requests
              parent:(FBConnect *)parent;

@end
