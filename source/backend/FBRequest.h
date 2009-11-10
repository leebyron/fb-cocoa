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

/*!
 * The API response to this request, given it is successful
 */
- (id)response;

/*!
 * The API response to this request, given it is unsuccessful
 */
- (NSError*)error;

/*!
 * User data to identify your request, can be anything your heart desires
 */
- (id)userData;
- (void)setUserData:(id)data;

@end
