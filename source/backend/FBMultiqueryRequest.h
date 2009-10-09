//
//  FBMultiqueryRequest.h
//  FBCocoa
//
//  Created by Lee Byron on 9/7/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FBRequest.h"


@interface FBMultiqueryRequest : FBRequest

+(FBMultiqueryRequest*) requestWithRequest:(NSString *)requestString
                                    parent:(FBConnect *)parent
                                    target:(id)tar
                                  selector:(SEL)sel
                                     error:(SEL)err;

@end
