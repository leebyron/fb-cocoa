//
//  FBConnect.m
//  FBCocoa
//
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import "FBConnect.h"
#import "FBConnect_Internal.h"
#import "FBCocoa.h"
#import "FBCallback.h"
#import "FBMethodRequest.h"
#import "FBBatchRequest.h"
#import "FBMultiqueryRequest.h"
#import "FBWebViewWindowController.h"
#import "FBSessionState.h"
#import "JSON.h"
#import "NSData+.h"
#import "NSImage+.h"
#import "NSString+.h"

// end points
#define kRESTServerURL @"http://api.%@facebook.com/restserver.php"
#define kLoginURL @"http://www.%@facebook.com/login.php"
#define kPermissionsURL @"http://www.%@facebook.com/connect/prompt_permissions.php"
#define kLoginFailureURL @"http://www.%@facebook.com/connect/login_failure.html"
#define kLoginSuccessURL @"http://www.%@facebook.com/connect/login_success.html"

// session key
#define kSessionKey @"FBUser"


@interface FBConnect (Private)

- (id)initWithAPIKey:(NSString*)key delegate:(id)obj;

- (void)promptLogin;

- (void)validateSession;

- (void)refreshSession;

- (NSString*)getPreferedFBLocale;

- (NSDictionary*)completeArgumentsForMethod:(NSString*)method
                                  arguments:(NSDictionary*)dict;

- (NSString*)sigForArguments:(NSDictionary*)dict;

- (NSString*)getRequestStringForMethod:(NSString*)method
                             arguments:(NSDictionary*)dict;

- (NSData*)postDataForMethod:(NSString*)method
                   arguments:(NSDictionary*)dict
                       files:(NSArray*)files;

- (void)complainAboutRequiredPermissions:(NSSet*)lackingPermissions;

// url functions
- (void)setSandbox:(NSString*)box;

- (NSString*)loginURL;

- (NSString*)restURL;

- (NSString*)permissionsURL;

@end


@implementation FBConnect

+ (FBConnect*)sessionWithAPIKey:(NSString*)key
                       delegate:(id)obj
{
  return [[[self alloc] initWithAPIKey:key delegate:obj] autorelease];
}

- (id)initWithAPIKey:(NSString*)key
            delegate:(id)obj
{
  if (!(self = [super init])) {
    return nil;
  }

  [self setSandbox:@""];

  APIKey        = [key retain];
  sessionState  = [[FBSessionState alloc] initWithKey:kSessionKey];
  delegate      = obj;
  isLoggedIn    = NO;
  isConnecting  = NO;

  requestedPermissions = [[NSMutableSet alloc] init];

  return self;
}

- (void)dealloc
{
  [sandbox release];

  [APIKey       release];
  [appSecret    release];
  [sessionState release];

  [requiredPermissions  release];
  [optionalPermissions  release];
  [requestedPermissions release];

  [permissionCallback release];

  [super dealloc];
}


//==============================================================================
//==============================================================================
//==============================================================================
- (void)setSandbox:(NSString*)box {
  if (!box || [box length] == 0) {
    sandbox = [[NSString stringWithString:@""] retain];
  } else {
    sandbox = [[NSString stringWithFormat:@"%@.", box] retain];
  }
}

- (NSString*)loginURL {
  return [NSString stringWithFormat:kLoginURL, sandbox];
}

- (NSString*)restURL
{
  return [NSString stringWithFormat:kRESTServerURL, sandbox];
}

- (NSString*)permissionsURL {
  return [NSString stringWithFormat:kPermissionsURL, sandbox];
}

- (NSString*)loginFailureURL {
  return [NSString stringWithFormat:kLoginFailureURL, sandbox];
}

- (NSString*)loginSuccessURL {
  return [NSString stringWithFormat:kLoginSuccessURL, sandbox];
}




//==============================================================================
//==============================================================================
//==============================================================================

- (void)setSecret:(NSString*)secret
{
  [secret retain];
  [appSecret release];
  appSecret = secret;
}

- (BOOL)isLoggedIn
{
  return isLoggedIn;
}

- (BOOL)isConnecting
{
  return isConnecting;
}

- (NSString*)uid
{
  if (![sessionState isValid]) {
    return nil;
  }
  return [sessionState uid];
}

- (void)loginWithRequiredPermissions:(NSSet*)req
                 optionalPermissions:(NSSet*)opt
{
  // remember what permissions we asked for
  [req retain];
  [requiredPermissions release];
  requiredPermissions = req;

  [opt retain];
  [optionalPermissions release];
  optionalPermissions = opt;

  [requestedPermissions removeAllObjects];
  if (requiredPermissions) {
    [requestedPermissions unionSet:requiredPermissions];
  }
  if (optionalPermissions) {
    [requestedPermissions unionSet:optionalPermissions];
  }

  if ([sessionState isValid]) {
    [self validateSession];
  } else {
    [self promptLogin];
  }
}

- (void)promptLogin
{
  // if a window exists, focus it.
  if (windowController) {
    [windowController focus];
    return;
  }

  isConnecting = YES;

  NSMutableDictionary* loginParams = [[NSMutableDictionary alloc] init];
  NSString* permissionsString = [[requestedPermissions allObjects] componentsJoinedByString:@","];
  [loginParams setObject:permissionsString          forKey:@"req_perms"];
  [loginParams setObject:APIKey                     forKey:@"api_key"];
  [loginParams setObject:[self getPreferedFBLocale] forKey:@"locale"];

  // adding this parameter keeps us from reading Safari's cookie when
  // performing a login for the first time. Sessions are still cached and
  // persistant so subsequent application launches will use their own
  // session cookie and not Safari's
  [loginParams setObject:@"true" forKey:@"skipcookie"];

  windowController =
  [[FBWebViewWindowController alloc] initWithConnect:self
                                             rootURL:[self loginURL]
                                              target:self
                                            selector:@selector(loginWindowClosed)];
  [windowController showWithParams:loginParams];
}

- (void)requestPermissions:(NSSet*)perms
                    target:(id)target
                  selector:(SEL)selector
{
  // if a window exists, focus it.
  if (windowController) {
    [windowController focus];
    return;
  }

  // store the callback
  if (permissionCallback) {
    [permissionCallback release];
  }
  permissionCallback = [[FBCallback alloc] initWithTarget:target
                                                 selector:selector];

  NSMutableDictionary* loginParams = [[NSMutableDictionary alloc] init];
  NSString* permissionsString = [[perms allObjects] componentsJoinedByString:@","];
  [loginParams setObject:permissionsString          forKey:@"ext_perm"];
  [loginParams setObject:APIKey                     forKey:@"api_key"];
  [loginParams setObject:[sessionState key]         forKey:@"session_key"];
  [loginParams setObject:[self getPreferedFBLocale] forKey:@"locale"];

  // adding this parameter keeps us from reading Safari's cookie when
  // performing a login for the first time. Sessions are still cached and
  // persistant so subsequent application launches will use their own
  // session cookie and not Safari's
  [loginParams setObject:@"true" forKey:@"skipcookie"];

  windowController =
  [[FBWebViewWindowController alloc] initWithConnect:self
                                             rootURL:[self permissionsURL]
                                              target:self
                                            selector:@selector(permissionWindowClosed)];
  [windowController showWithParams:loginParams];
}

- (void)logout
{
  [self callMethod:@"auth.expireSession"
     withArguments:nil
            target:self
          selector:@selector(expireSessionResponseComplete:)];
  [sessionState clear];
  isLoggedIn = NO;
  isConnecting = NO;
}

- (void)validateSession
{
  isConnecting = YES;

  [self startBatch];

  [self fqlQuery:[NSString stringWithFormat:@"SELECT %@ FROM permissions WHERE uid = %@",
                  [[requestedPermissions allObjects] componentsJoinedByString:@","], [self uid]]
          target:self
        selector:@selector(gotGrantedPermissions:)];

  [self callMethod:@"users.getLoggedInUser"
     withArguments:nil
            target:self
          selector:@selector(gotLoggedInUser:)];

  [self sendBatch];
}

- (void)refreshSession
{
  NSLog(@"refreshing session");
  isLoggedIn = NO;
  isConnecting = YES;
  [sessionState invalidate];
  [self loginWithRequiredPermissions:requiredPermissions
                 optionalPermissions:optionalPermissions];
}

- (BOOL)hasPermission:(NSString *)perm
{
  return [sessionState hasPermission:perm];
}

//==============================================================================
//==============================================================================
//==============================================================================

#pragma mark Connect Methods
- (id<FBRequest>)callMethod:(NSString *)method
              withArguments:(NSDictionary *)dict
                     target:(id)target
                   selector:(SEL)selector
{
  NSString *requestString = [self getRequestStringForMethod:method arguments:dict];
  FBMethodRequest* request = [FBMethodRequest requestWithRequest:requestString
                                                          parent:self
                                                          target:target
                                                        selector:selector];
  if ([self pendingBatch]) {
    [pendingBatchRequests addObject:request];
  } else {
    [request start];
  }
  return request;
}

- (id<FBRequest>)callMethod:(NSString*)method
              withArguments:(NSDictionary*)dict
                  withFiles:(NSArray*)files
                     target:(id)target
                   selector:(SEL)selector
{
  NSData* postData = [self postDataForMethod:method
                                   arguments:dict
                                       files:files];
  FBMethodRequest* request = [FBMethodRequest requestWithData:postData
                                                       parent:self
                                                       target:target
                                                     selector:selector];
  if ([self pendingBatch]) {
    [NSException raise:@"Post request during batch"
                format:@"Cannot perform a facebook method request with files after startBatch"];
  } else {
    [request start];
  }
  return request;
}

- (id<FBRequest>)fqlQuery:(NSString*)query
                   target:(id)target
                 selector:(SEL)selector
{
  return [self callMethod:@"fql.query"
            withArguments:[NSDictionary dictionaryWithObject:query forKey:@"query"]
                   target:target
                 selector:selector];
}

- (id<FBRequest>)fqlMultiquery:(NSDictionary*)queries
                        target:(id)target
                      selector:(SEL)selector
{
  NSDictionary* arguments = [NSDictionary dictionaryWithObject:[queries JSONRepresentation] forKey:@"queries"];
  NSString* requestString = [self getRequestStringForMethod:@"fql.multiquery" arguments:arguments];

  FBMethodRequest* request = [FBMultiqueryRequest requestWithRequest:requestString
                                                              parent:self
                                                              target:target
                                                            selector:selector];
  if ([self pendingBatch]) {
    [pendingBatchRequests addObject:request];
  } else {
    [request start];
  }
  return request;
}


- (void)startBatch
{
  if (isBatch) {
    [NSException raise:@"Batch Request exception"
                format:@"Cannot startBatch while there is a pendingBatch"];
    return;
  }
  isBatch = YES;
  pendingBatchRequests = [[NSMutableArray alloc] init];
}

- (BOOL)pendingBatch
{
  // if start has been called and send hasnt yet
  return isBatch;
}

- (void)cancelBatch
{
  isBatch = NO;
  [pendingBatchRequests release];
  pendingBatchRequests = nil;
}

- (id<FBRequest>)sendBatch
{
  if (!isBatch) {
    [NSException raise:@"Batch Request exception"
                format:@"Cannot sendBatch if there is no pendingBatch"];
    return nil;
  }
  isBatch = NO;

  // call batch.run with the results of all the queued methods, using fbbatchrequest
  FBMethodRequest* request;
  if ([pendingBatchRequests count] > 0) {
    NSDictionary* arguments = [NSDictionary dictionaryWithObject:[pendingBatchRequests JSONRepresentation] forKey:@"method_feed"];
    NSString* requestString = [self getRequestStringForMethod:@"batch.run" arguments:arguments];
    request = [FBBatchRequest requestWithRequest:requestString
                                        requests:pendingBatchRequests
                                          parent:self];
    [request start];
  }

  [pendingBatchRequests release];
  pendingBatchRequests = nil;

  return request;
}

//==============================================================================
//==============================================================================
//==============================================================================

#pragma mark Callbacks
- (void)failedQuery:(FBMethodRequest *)query withError:(NSError *)err
{
  int errorCode = [err code];
  if ([sessionState exists] && isLoggedIn &&
      (errorCode == FBParamSessionKeyError ||
       errorCode == FBPermissionError ||
       errorCode == FBSessionExpiredError ||
       errorCode == FBSessionInvalidError ||
       errorCode == FBSessionRequiredError ||
       errorCode == FBSessionRequiredForSecretError)) {
    // We were using a session key that we'd saved as permanent, and got
    // back an error saying it was invalid. Throw away the saved session
    // data and start a login from scratch.
    [self performSelector:@selector(refreshSession) withObject:nil afterDelay:0.0];
  }
}

- (void)gotGrantedPermissions:(id<FBRequest>)req
{
  if ([req error]) {
    NSLog(@"grant perms error: %@", [req error]);
  }

  NSDictionary* response = [[req response] objectAtIndex:0];

  NSEnumerator *enumerator = [response keyEnumerator];
  NSString* perm;
  while ((perm = [enumerator nextObject])) {
    if ([[response objectForKey:perm] intValue] != 0) {
      [sessionState addPermission:perm];
    }
  }
}

- (void)gotLoggedInUser:(id<FBRequest>)req
{
  if ([req error]) {
    if ([[req error] code] > 0) {
      // fb error, bad login
      [self promptLogin];
    } else {
      // net error, retry
      [self performSelector:@selector(validateSession)
                 withObject:nil
                 afterDelay:60.0];
    }
    return;
  }

  // check for granted permissions
  BOOL needsNewPermissions = NO;
  NSEnumerator* enumerator = [requiredPermissions objectEnumerator];
  NSString* perm;
  while (perm = [enumerator nextObject]) {
    if (![self hasPermission:perm]) {
      needsNewPermissions = YES;
      break;
    }
  }

  isConnecting = NO;

  // if needs a permission, prompt. if session is valid, notify. else refresh.
  if (needsNewPermissions) {
    [self promptLogin];
  } else if ([[[req response] stringValue] isEqualToString:[self uid]]) {
    isLoggedIn = YES;
    [delegate facebookConnectLoggedIn:self withError:nil];
  } else {
    [self refreshSession];
  }
}

- (void)failedValidateSession:(id<FBRequest>)req
{
  if ([[req error] code] > 0) {
    // fb error, bad login
    [self promptLogin];
  } else {
    // net error, retry
    [self performSelector:@selector(validateSession)
               withObject:nil
               afterDelay:60.0];
  }
}

- (void)expireSessionResponseComplete:(id<FBRequest>)req
{
  [delegate facebookConnectLoggedOut:self withError:[req error]];
}

- (void)loginWindowClosed
{
  isConnecting = NO;

  if ([windowController success]) {
    isLoggedIn = YES;

    NSDictionary* args = [[[windowController lastURL] query] urlDecodeArguments];
    if ([args valueForKey:@"session"] != nil) {
      [sessionState setWithDictionary:[[args valueForKey:@"session"] JSONValue]];

      // support for new permissions append, but if it doesn't exist, assume all were accepted
      if ([args valueForKey:@"permissions"] != nil) {
        [sessionState setPermissions:[[args valueForKey:@"permissions"] JSONValue]];
      } else {
        [sessionState setPermissions:requestedPermissions];
      }

      // check permissions against required permissions
      if (![requiredPermissions isSubsetOfSet:[sessionState permissions]]) {
        isLoggedIn = NO;

        NSMutableSet* lackingPermissions = [requiredPermissions mutableCopy];
        [lackingPermissions minusSet:[sessionState permissions]];

        [self performSelector:@selector(complainAboutRequiredPermissions:)
                   withObject:lackingPermissions
                   afterDelay:0.0];
      }
    } else {
      isLoggedIn = NO;
    }
  } else {
    isLoggedIn = NO;
  }

  // release the web window
  [windowController release];
  windowController = nil;

  if (isLoggedIn) {
    [delegate facebookConnectLoggedIn:self withError:nil];
  } else {
    NSError* err = [NSError errorWithDomain:kFBErrorDomainKey code:FBAPIUnknownError userInfo:nil];
    [delegate facebookConnectLoggedIn:self withError:err];
  }
}

- (void)complainAboutRequiredPermissions:(NSSet *)lackingPermissions
{
  // TODO: this language should be cleaned up, permissions are not referred to by description

  NSString* appName = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleDisplayName"];
  NSString* permissions = [[lackingPermissions allObjects] componentsJoinedByString:@", "];
  NSLog(@"Need the required permissions: %@ to be useful. Refusing to log in.", permissions);

  NSAlert* alert = [[NSAlert alloc] init];
  [alert addButtonWithTitle:@"OK"];
  [alert setAlertStyle:NSCriticalAlertStyle];
  [alert setMessageText:NSLocalizedString(@"Need more permissions", nil)];
  [alert setInformativeText:[NSString stringWithFormat:
                             NSLocalizedString(@"%@ requires you allow the %@ permissions to be useful.\n\nYou are not logged in.", nil),
                             appName, permissions]];
  [alert runModal];
  [alert release];
}

- (void)permissionWindowClosed
{
  NSDictionary* args = [[[windowController lastURL] query] urlDecodeArguments];
  NSArray* acceptedPerms = [[args valueForKey:@"accepted_permissions"] componentsSeparatedByString:@","];
  [sessionState addPermissions:acceptedPerms];

  // release the web window
  [windowController release];
  windowController = nil;

  // fire and release the callback
  [permissionCallback success:acceptedPerms];
  [permissionCallback release];
  permissionCallback = nil;
}

//==============================================================================
//==============================================================================
//==============================================================================

#pragma mark Private Methods
- (NSString*)getPreferedFBLocale
{
  NSString* preferredLang = @"en_US"; // start with default language

  // commented out locales do not have an OS X equivalent
  // TODO: facebook supports even more languages!
  NSDictionary* fbLocales = [NSDictionary dictionaryWithObjectsAndKeys:
    @"af_ZA", @"af", // Afrikaans - Afrikaans
    @"sq_AL", @"sq", // Albanian - Shqip
    @"ar_AR", @"ar", // Arabic - العربية
    @"eu_ES", @"eu", // Basque - Euskara
    @"bn_IN", @"bn", // Bengali - বাংলা
    @"bs_BA", @"bs", // Bosnian - Bosanski
    @"bg_BG", @"bg", // Bulgarian - Български
    @"ca_ES", @"ca", // Catalan - Català
    @"zh_HK", @"zh-Hant", // Chinese (Hong Kong) - 中文(香港)
    //@"zh_TW", @"???", // Chinese (Taiwan) - 中文(台灣)
    @"zh_CN", @"zh-Hans", // Chinese (Simplified) - 中文(简体)
    @"hr_HR", @"hr", // Croatian - Hrvatski
    @"cs_CZ", @"cs", // Czech - Čeština
    @"kw_GB", @"kw", // Cornish - Kernewek
    @"da_DK", @"da", // Danish - Dansk
    @"nl_NL", @"nl", // Dutch - Nederlands
    //@"en_PI", @"???", // English (Pirate) - English (Pirate)
    @"en_US", @"en", // English (US) - English (US)
    @"en_GB", @"en-GB", // English (UK) - English (UK)
    @"en_US", @"en-US", // English (US) - English (US)
    @"en_US", @"en-CA", // English (US) - English (US)
    @"eo_EO", @"eo", // Esperanto - Esperanto
    @"et_EE", @"et", // Estonian - Eesti
    //@"tl_PH", @"???", // Filipino - Filipino
    @"fi_FI", @"fi", // Finnish - Suomi
    @"fr_CA", @"fr-CA", // French (Canada) - Français (Canada)
    @"fr_FR", @"fr", // French (France) - Français (France)
    @"fr_FR", @"fr-CH", // French (France) - Français (France)
    @"gl_ES", @"gl", // Galician - Galego
    @"de_DE", @"de", // German - Deutsch
    @"de_DE", @"de-CH", // German - Deutsch
    @"el_GR", @"el", // Greek - Ελληνικά
    @"he_IL", @"he", // Hebrew - עברית
    //@"hi_IN", @"???", // Hindi - हिन्दी
    @"hu_HU", @"hu", // Hungarian - Magyar
    @"is_IS", @"is", // Icelandic - Íslenska
    @"id_ID", @"id", // Indonesian - Bahasa Indonesia
    @"ga_IE", @"ga", // Irish - Gaeilge
    @"it_IT", @"it", // Italian - Italiano
    @"ja_JP", @"ja", // Japanese - 日本語
    @"ko_KR", @"ko", // Korean - 한국어
    @"lv_LV", @"lv", // Latvian - Latviešu
    @"lt_LT", @"lt", // Lithuanian - Lietuvių
    @"mk_MK", @"mk", // Macedonian - Македонски
    @"ms_MY", @"ms", // Malay - Bahasa Melayu
    //@"ml_IN", @"???", // Malayalam - മലയാളം
    @"nb_NO", @"nb", // Norwegian (bokmal) - Norsk (bokmål)
    @"nn_NO", @"nn", // Norwegian (nynorsk) - Norsk (nynorsk)
    @"fa_IR", @"fa", // Persian - فارسی
    @"pl_PL", @"pl", // Polish - Polski
    @"pt_BR", @"pt-BR", // Portuguese (Brazil) - Português (Brasil)
    @"pt_PT", @"pt-PT", // Portuguese (Portugal) - Português (Portugal)
    @"pt_PT", @"pt", // Portuguese (Portugal) - Português (Portugal)
    //@"pa_IN", @"???", // Punjabi - ਪੰਜਾਬੀ
    @"ro_RO", @"ro", // Romanian - Română
    @"ru_RU", @"ru", // Russian - Русский
    @"sr_RS", @"sr", // Serbian - Српски
    @"sk_SK", @"sk", // Slovak - Slovenčina
    @"sl_SI", @"sl", // Slovenian - Slovenščina
    @"es_LA", @"es", // Spanish - Español
    @"es_ES", @"es-ES", // Spanish (Spain) - Español (España)
    @"es_LA", @"es-419", // Spanish - Español
    @"sw_KE", @"sw", // Swahili - Kiswahili
    @"sv_SE", @"sv", // Swedish - Svenska
    //@"ta_IN", @"???", // Tamil - தமிழ்
    //@"te_IN", @"???", // Telugu - తెలుగు
    @"th_TH", @"th", // Thai - ภาษาไทย
    @"tr_TR", @"tr", // Turkish - Türkçe
    @"uk_UA", @"uk", // Ukrainian - Українська
    @"vi_VN", @"vi", // Vietnamese - Tiếng Việt
    @"cy_GB", @"cy", // Welsh - Cymraeg
    nil];

  NSArray* languages = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"];
  NSString* language;
  for (int i = 0; i < [languages count]; i++) {
    language = [languages objectAtIndex:i];
    if ([fbLocales objectForKey:language]) {
      preferredLang = [fbLocales objectForKey:language];
      break;
    }
  }
  return preferredLang;
}

//////

- (NSDictionary*)completeArgumentsForMethod:(NSString*)method
                                  arguments:(NSDictionary*)dict
{
  NSMutableDictionary* args;
  if (dict) {
    args = [NSMutableDictionary dictionaryWithDictionary:dict];
  } else {
    args = [NSMutableDictionary dictionary];
  }
  [args setObject:method forKey:@"method"];
  [args setObject:APIKey forKey:@"api_key"];
  [args setObject:kAPIVersion forKey:@"v"];
  [args setObject:@"json" forKey:@"format"];
  [args setObject:@"true" forKey:@"ss"];
  [args setObject:[[NSNumber numberWithLong:time(NULL)] stringValue]
           forKey:@"call_id"];
  if ([sessionState isValid]) {
    [args setObject:[sessionState key] forKey:@"session_key"];
  }

  [args setObject:[self sigForArguments:args] forKey:@"sig"];

  return args;
}

- (NSString*)sigForArguments:(NSDictionary*)dict
{
  NSArray* sortedKeys = [[dict allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
  NSMutableString* args = [NSMutableString string];
  NSString* key;
  for (int i = 0; i < [sortedKeys count]; i++) {
    key = [sortedKeys objectAtIndex:i];
    NSString *value = [dict objectForKey:key];
    if (key != nil && value != nil) {
      [args appendString:key];
      [args appendString:@"="];
      [args appendString:value];
    }
  }

  if ([sessionState isValid] && [sessionState secret] != nil) {
    [args appendString:[sessionState secret]];
  } else if (appSecret != nil) {
    [args appendString:appSecret];
  }

  return [[args dataUsingEncoding:NSUTF8StringEncoding] md5];
}

- (NSString*)getRequestStringForMethod:(NSString*)method
                             arguments:(NSDictionary*)dict
{
  NSDictionary* args = [self completeArgumentsForMethod:method
                                              arguments:dict];
  return [NSString urlEncodeArguments:args];
}

- (NSData*)postDataForMethod:(NSString*)method
                   arguments:(NSDictionary*)dict
                       files:(NSArray*)files
{
  NSDictionary* args = [self completeArgumentsForMethod:method
                                              arguments:dict];

  // start data
  NSMutableData* postBody = [NSMutableData data];
  NSData* endLine = [[NSString stringWithFormat:@"\r\n--%@\r\n", kPostFormDataBoundary] dataUsingEncoding:NSUTF8StringEncoding];
  [postBody appendData:[[NSString stringWithFormat:@"--%@\r\n", kPostFormDataBoundary] dataUsingEncoding:NSUTF8StringEncoding]];

  // enumerate, adding to the post body
  NSEnumerator* keyEnumerator = [args keyEnumerator];
  NSString* key;
  while (key = [keyEnumerator nextObject]) {
    NSString* startLine = [NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key];
    [postBody appendData:[startLine dataUsingEncoding:NSUTF8StringEncoding]];
    [postBody appendData:[[args valueForKey:key] dataUsingEncoding:NSUTF8StringEncoding]];
    [postBody appendData:endLine];
  }

  // add files
  for (int i = 0; i < [files count]; i++) {

    // image type
    if ([[files objectAtIndex:i] isKindOfClass:[NSImage class]]) {
      // get image data, sizing to fit
      NSImage* image = [(NSImage*)[files objectAtIndex:i] copy];
      [image resizeToFit:NSMakeSize(kMaxPhotoSize, kMaxPhotoSize) usingMode:0];
      NSBitmapImageRep* bmp = [[NSBitmapImageRep alloc] initWithData:[image TIFFRepresentation]];
      NSData* imageData = [bmp representationUsingType:NSPNGFileType properties:nil];

      // write image to post body
      NSString* md5 = [imageData md5];
      NSString* startLine = [NSString stringWithFormat:@"Content-Disposition: form-data; filename=\"%@\"\r\n", md5];
      [postBody appendData:[startLine dataUsingEncoding:NSUTF8StringEncoding]];
      [postBody appendData:[@"Content-Type: image/png\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
      [postBody appendData:imageData];
      [postBody appendData:endLine];
    }
  }

  return postBody;
}

@end
