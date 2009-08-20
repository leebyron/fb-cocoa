//
//  NSXMLNode+.h
//  FBCocoa
//
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSXMLNode (Additions)

- (NSXMLNode *)childWithName:(NSString *)childName;

/*!
 * Give it the response from a FQL Multiquery and it returns a dictionary with
 * the results from each query assigned to the key of the name of the query
 */
- (NSDictionary *)parseMultiqueryResponse;

@end
