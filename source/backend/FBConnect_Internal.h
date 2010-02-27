/*
 *  FBConnect_Internal.h
 *  FBCocoa
 *
 *  Created by Lee Byron on 2/26/10.
 *  Copyright 2010 Facebook. All rights reserved.
 *
 */


@interface FBConnect (Internal)

- (void)setSandbox:(NSString*)box;

- (NSString*)loginURL;

- (NSString*)restURL;

- (NSString*)permissionsURL;

- (NSString*)loginFailureURL;

- (NSString*)loginSuccessURL;

@end
