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

@interface FBRequest (Internal)

-(id)initWithRequest:(NSString *)requestString
              parent:(FBConnect *)parent
              target:(id)tar
            selector:(SEL)sel
               error:(SEL)err;

@end


@interface FBBatchRequest (Private)

-(id)initWithRequest:(NSString *)requestString
            requests:(NSArray *)requests
              parent:(FBConnect *)parent;

@end


@implementation FBBatchRequest

+(FBBatchRequest*)requestWithRequest:(NSString *)requestString
                            requests:(NSArray *)requests
                              parent:(FBConnect *)parent
{
  return [[[FBBatchRequest alloc] initWithRequest:requestString
                                         requests:requests
                                           parent:parent] autorelease];
}

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
  [requests release];
  [super dealloc];
}

- (void)requestSuccess:(id)json
{
  SBJsonParser* jsonParser = [SBJsonParser new];
  int index = 0;
  NSString* subJsonString;
  for (int i = 0; i < [json count]; i++) {
    subJsonString = [json objectAtIndex:i];
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
  FBRequest* req;
  for (int i = 0; i < [requests count]; i++) {
    req = [requests objectAtIndex:i];
    [req requestFailure:err];
  }
}

@end
