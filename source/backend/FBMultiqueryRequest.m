//
//  FBMultiqueryRequest.m
//  FBCocoa
//
//  Created by Lee Byron on 9/7/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import "FBMultiqueryRequest.h"


@implementation FBMultiqueryRequest

- (void)requestSuccess:(id)json
{
  // convert the json response into a dictionary
  NSMutableDictionary* multiqueryResponse = [[NSMutableDictionary alloc] init];
  for (NSDictionary* result in json) {
    [multiqueryResponse setObject:[result objectForKey:@"fql_result_set"]
                           forKey:[result objectForKey:@"name"]];
  }

  if (target && method && [target respondsToSelector:method]) {
    [target performSelector:method withObject:multiqueryResponse];
  }
}

@end
