//
//  NSXMLNodeAdditions.m
//  FBCocoa
//
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import "NSXMLNodeAdditions.h"


@implementation NSXMLNode (NSXMLNodeAdditions)

- (NSXMLNode *)childWithName:(NSString *)childName
{
  for (NSXMLNode *currChild in [self children]) {
    if ([[currChild name] isEqualToString:childName]) {
      return currChild;
    }
  }

  return nil;
}

@end
