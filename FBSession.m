//
//  FBSession.m
//  FBCocoa
//
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import "FBSession.h"
#import "FBQuery.h"
#import "FBCrypto.h"
#import "FBWebViewWindowController.h"
#import "FBLoginSession.h"
#import "NSStringAdditions.h"

#define kRESTServerURL @"http://api.facebook.com/restserver.php?"
#define kAPIVersion @"1.0"
#define kErrorCodeInvalidSession 102

/*
 * These are shortcuts for calling delegate methods. They check to see if there
 * is a delegate and if the delegate responds to the selector passed as the
 * first argument. DELEGATEn is the call you use when there are n additional
 * arguments beyond "self" (since delegate methods should have the delegating
 * object as the first parameter).
 */
#define DELEGATE(sel) {if (delegate && [delegate respondsToSelector:(sel)]) {\
  [delegate performSelector:(sel)];}}


@interface FBSession (Private)

- (id)initWithAPIKey:(NSString *)key
              secret:(NSString *)secret
            delegate:(id)obj;

- (NSString *)sigForArguments:(NSDictionary *)dict;

- (void)validateSession;
- (void)refreshSession;

@end


@implementation FBSession

static FBSession *instance;

+ (FBSession *)instance
{
  return instance;
}

+ (FBSession *)sessionWithAPIKey:(NSString *)key
                          secret:(NSString *)secret
                        delegate:(id)obj
{
  instance = [[self alloc] initWithAPIKey:key secret:secret delegate:obj];
  return instance;
}

- (id)initWithAPIKey:(NSString *)key
              secret:(NSString *)secret
            delegate:(id)obj
{
  if (!(self = [super init])) {
    return nil;
  }

  APIKey     = [key retain];
  appSecret  = [secret retain];
  session    = [[FBLoginSession alloc] init];
  delegate   = obj;
  isLoggedIn = NO;

  return self;
}

- (void)dealloc
{
  [APIKey      release];
  [appSecret   release];
  [session     release];
  [loginParams release];
  [super dealloc];
}

//==============================================================================
//==============================================================================
//==============================================================================

- (BOOL)isLoggedIn
{
  return isLoggedIn;
}

- (NSString *)uid
{
  return [session uid];
}

- (void)login
{
  [self loginWithParams:nil];
}

- (void)loginWithParams:(NSDictionary *)params
{
  [params retain];
  [loginParams release];
  loginParams = params;
  if ([session isValid]) {
    [self validateSession];
  } else {
    NSMutableDictionary *allLoginParams = [[NSMutableDictionary alloc] initWithDictionary:loginParams];
    [allLoginParams setObject:APIKey      forKey:@"api_key"];
    [allLoginParams setObject:kAPIVersion forKey:@"v"];
    windowController =
    [[FBWebViewWindowController alloc] initWithCloseTarget:self
                                                  selector:@selector(webViewWindowClosed)];
    [windowController showWithParams:allLoginParams];
  }
}

- (void)logout
{
  [self callMethod:@"Auth.expireSession"
     withArguments:nil
            target:self
          selector:@selector(expireSessionResponseComplete:)
             error:@selector(failedLogout:)];
}

- (void)validateSession
{
  [self callMethod:@"users.isAppUser"
     withArguments:nil
            target:self
          selector:@selector(gotLoggedInUser:)
             error:@selector(noLoggedInUser:)];
}

- (void)refreshSession
{
  isLoggedIn = NO;
  [session clear];
  [self loginWithParams:loginParams];
}

- (BOOL)hasPermission:(NSString *)perm
{
  return NO; // return permissions.indexOf(perm) != -1;
}

/*
 need to implement:
 -(void)requirePermissions:(NSArray *)perms
*/

//==============================================================================
//==============================================================================
//==============================================================================

#pragma mark Connect Methods
- (void)callMethod:(NSString *)method
     withArguments:(NSDictionary *)dict
            target:(id)target
          selector:(SEL)selector
             error:(SEL)error
{
  NSMutableDictionary *args;

  if (dict) {
    args = [NSMutableDictionary dictionaryWithDictionary:dict];
  } else {
    args = [NSMutableDictionary dictionary];
  }
  [args setObject:method forKey:@"method"];
  [args setObject:APIKey forKey:@"api_key"];
  [args setObject:kAPIVersion forKey:@"v"];
  [args setObject:@"XML" forKey:@"format"];
  [args setObject:[[NSNumber numberWithLong:time(NULL)] stringValue]
           forKey:@"call_id"];
  if ([session isValid]) {
    [args setObject:[session key] forKey:@"session_key"];
  }

  NSString *sig = [self sigForArguments:args];
  [args setObject:sig forKey:@"sig"];

  NSString *server = kRESTServerURL;
  NSURL *url = [NSURL URLWithString:[server stringByAppendingString:[NSString urlEncodeArguments:args]]];
  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
  [req setHTTPMethod:@"GET"];
  [req addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-type"];

  FBQuery *currentConnection = [[FBQuery alloc] initWithRequest:req
                                                         target:target
                                                       selector:selector
                                                          error:error];
  [currentConnection start];
}

- (void)sendFQLQuery:(NSString *)query
              target:(id)target
            selector:(SEL)selector
               error:(SEL)error
{
  NSDictionary *dict = [NSDictionary dictionaryWithObject:query forKey:@"query"];
  [self callMethod:@"Fql.query"
     withArguments:dict
            target:target
          selector:selector
             error:error];
}

- (void)sendFQLMultiquery:(NSDictionary *)queries
                   target:(id)target
                 selector:(SEL)selector
                    error:(SEL)error
{
  // Encode the NSDictionary in JSON.
  NSString *entryFormat = @"\"%@\" : \"%@\"";
  NSMutableArray *entries = [NSMutableArray array];
  for (NSString *key in queries) {
    NSString *escapedKey = [key stringByEscapingQuotesAndBackslashes];
    NSString *escapedVal = [[queries objectForKey:key] stringByEscapingQuotesAndBackslashes];
    [entries addObject:[NSString stringWithFormat:entryFormat, escapedKey,
                        escapedVal]];
  }

  NSString *finalString = [NSString stringWithFormat:@"{%@}",
                           [entries componentsJoinedByString:@","]];

  NSDictionary *dict = [NSDictionary dictionaryWithObject:finalString forKey:@"queries"];
  [self callMethod:@"Fql.multiquery"
     withArguments:dict
            target:target
          selector:selector
             error:error];
}

- (void)failedQuery:(FBQuery *)query withError:(NSError *)err
{
  if ([session isValid] && [err code] == kErrorCodeInvalidSession) {
    // We were using a session key that we'd saved as permanent, and got
    // back an error saying it was invalid. Throw away the saved session
    // data and start a login from scratch.
    [self refreshSession];
  }
  
}

//==============================================================================
//==============================================================================
//==============================================================================

#pragma mark Callbacks
- (void)gotLoggedInUser:(NSXMLDocument *)xml
{
  if ([xml rootElement] != nil) {
    isLoggedIn = YES;
    DELEGATE(@selector(fbConnectLoggedIn));
  } else {
    [self refreshSession];
  }
}

- (void)noLoggedInUser:(NSXMLDocument *)xml
{
  [self refreshSession];
}

- (void)expireSessionResponseComplete:(NSXMLDocument *)xml
{
  [session clear];
  DELEGATE(@selector(fbConnectLoggedOut));
}

- (void)failedLogout:(NSError *)error
{
  NSLog(@"fbConnect logout failed: %@", [[error userInfo] objectForKey:kFBErrorMessageKey]);
  DELEGATE(@selector(fbConnectErrorLoggingOut));
}

- (void)webViewWindowClosed
{
  if ([windowController success]) {
    isLoggedIn = YES;

    NSString *url = [[windowController lastURL] absoluteString];
    NSRange startSession = [url rangeOfString:@"session="];
    if (startSession.location != NSNotFound) {
      NSString *rawSession = [url substringFromIndex:(startSession.location + startSession.length)];
      NSDictionary *sessDict = [[rawSession stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] simpleJSONDecode];
      [session setWithDictionary:sessDict];
    } else {
      isLoggedIn = NO;
    }
  } else {
    isLoggedIn = NO;
  }
  [windowController release];

  if (isLoggedIn) {
    DELEGATE(@selector(fbConnectLoggedIn));
  } else {
    DELEGATE(@selector(fbConnectErrorLoggingIn));
  }
}

//==============================================================================
//==============================================================================
//==============================================================================

#pragma mark Private Methods
- (NSString *)sigForArguments:(NSDictionary *)dict
{
  NSArray *sortedKeys = [[dict allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
  NSMutableString *args = [NSMutableString string];
  for (NSString *key in sortedKeys) {
    [args appendString:key];
    [args appendString:@"="];
    [args appendString:[dict objectForKey:key]];
  }
  
  if ([session isValid]) {
    [args appendString:[session secret]];
  } else {
    [args appendString:appSecret];
  }
  return [FBCrypto hexMD5:args];
}

@end
