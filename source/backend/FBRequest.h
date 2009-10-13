//
//  FBRequest.h
//  FBCocoa
//
//  Created by Lee Byron on 10/13/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol FBRequest <NSObject>

/*!
 * Calling this will cancel the in progress request and reattempt
 */
- (void)retry;

/*!
 * Cancel the in progress request
 */
- (void)cancel;

@end
