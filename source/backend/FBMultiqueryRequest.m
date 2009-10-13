//
//  FBMultiqueryRequest.m
//  FBCocoa
//
//  Created by Lee Byron on 9/7/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import "FBMultiqueryRequest.h"


@interface FBMultiqueryRequest (Private)

-(id)initWithRequest:(NSString *)requestString
              parent:(FBConnect *)parent
              target:(id)tar
            selector:(SEL)sel
               error:(SEL)err;

@end


@implementation FBMultiqueryRequest

+(FBMultiqueryRequest*) requestWithRequest:(NSString *)requestString
                                    parent:(FBConnect *)parent
                                    target:(id)tar
                                  selector:(SEL)sel
                                     error:(SEL)err
{
  return [[[FBMultiqueryRequest alloc] initWithRequest:requestString
                                                parent:parent
                                                target:tar
                                              selector:sel
                                                 error:err] autorelease];
}

- (void)dealloc
{
  [super dealloc];
}

- (void)requestSuccess:(id)json
{
  // convert the json response into a dictionary
  NSMutableDictionary* multiqueryResponse = [[NSMutableDictionary alloc] init];
  NSDictionary* result;
  for (int i = 0; i < [json count]; i++) {
    result = [json objectAtIndex:i];
    [multiqueryResponse setObject:[result objectForKey:@"fql_result_set"]
                           forKey:[result objectForKey:@"name"]];
  }

  if (target && method && [target respondsToSelector:method]) {
    [target performSelector:method withObject:multiqueryResponse];
  }

  [multiqueryResponse release];
}

@end
