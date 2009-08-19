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

@end
