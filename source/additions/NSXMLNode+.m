//
//  NSXMLNode+.m
//  FBCocoa
//
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import "NSXMLNode+.h"


@implementation NSXMLNode (Additions)

- (NSXMLNode *)childWithName:(NSString *)childName
{
  for (NSXMLNode *currChild in [self children]) {
    if ([[currChild name] isEqualToString:childName]) {
      return currChild;
    }
  }

  return nil;
}

- (NSDictionary *)parseMultiqueryResponse
{
  NSMutableDictionary *responses = [[NSMutableDictionary alloc] init];

  // get the fql result
  NSXMLNode *node = self;
  while (node != nil && ![[node name] isEqualToString:@"fql_result"]) {
    node = [node nextNode];
  }

  // add each response to the dictionary
  while (node) {
    NSXMLNode *nameNode = [node childWithName:@"name"];
    NSXMLNode *resultSetNode = [node childWithName:@"fql_result_set"];
    [responses setObject:resultSetNode forKey:[nameNode stringValue]];
    node = [node nextSibling];
  }

  return responses;
}

@end
