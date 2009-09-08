//
//  FBBatchRequest.m
//  FBCocoa
//
//  Created by Lee Byron on 9/5/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import "FBBatchRequest.h"
#import "FBCocoa.h"
#import "JSON.h"


@implementation FBBatchRequest

-(id)initWithRequest:(NSString *)requestString
            requests:(NSArray *)reqs
              parent:(FBConnect *)parent
{
  self = [super initWithRequest:requestString
                         parent:parent
                         target:nil
                       selector:nil
                          error:nil];
  if (!self) {
    return nil;
  }
  requests = [reqs retain];
  return self;
}

- (void)dealloc
{
  [requests dealloc];
  [super dealloc];
}

- (void)requestSuccess:(id)json
{
  SBJsonParser* jsonParser = [SBJsonParser new];
  int index = 0;
  for (NSString* subJsonString in json) {
    id subJson = [jsonParser fragmentWithString:subJsonString];
    if (!subJson) {
      NSError* jsonError = [NSString stringWithFormat:@"JSON Parsing error: %@", [jsonParser errorTrace]];
      [[requests objectAtIndex:index] requestFailure:[NSError errorWithDomain:kFBErrorDomainKey
                                                                         code:FBAPIUnknownError
                                                                     userInfo:[NSDictionary dictionaryWithObject:jsonError
                                                                                                          forKey:kFBErrorMessageKey]]];
    }
    [[requests objectAtIndex:index] evaluateResponse:subJson];
    index++;
  }
  [jsonParser release];
}

- (void)requestFailure:(NSError *)err
{
  for (FBRequest* req in requests) {
    [req requestFailure:err];
  }
}

@end
