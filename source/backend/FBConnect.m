//
//  FBConnect.m
//  FBCocoa
//
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import "FBConnect.h"
#import "FBCocoa.h"
#import "FBRequest.h"
#import "FBBatchRequest.h"
#import "FBMultiqueryRequest.h"
#import "FBWebViewWindowController.h"
#import "FBSessionState.h"
#import "NSString+.h"

#define DELEGATE(sel) {if (delegate && [delegate respondsToSelector:(sel)]) {\
[delegate performSelector:(sel) withObject:self];}}


@interface FBConnect (Private)

- (void)promptLogin;
- (void)validateSession;
- (void)refreshSession;
- (NSString *)getPreferedFBLocale;
- (NSString *)getRequestStringForMethod:(NSString *)method arguments:(NSDictionary *)dict;
- (NSString *)sigForArguments:(NSDictionary *)dict;

@end


@implementation FBConnect

+ (FBConnect *)sessionWithAPIKey:(NSString *)key
                        delegate:(id)obj
{
  return [[self alloc] initWithAPIKey:key delegate:obj];
}

- (id)initWithAPIKey:(NSString *)key
            delegate:(id)obj
{
  if (!(self = [super init])) {
    return nil;
  }

  APIKey        = [key retain];
  sessionState  = [[FBSessionState alloc] init];
  delegate      = obj;
  isLoggedIn    = NO;

  return self;
}

- (void)dealloc
{
  [APIKey       release];
  [appSecret    release];
  [sessionState release];
  [super dealloc];
}

//==============================================================================
//==============================================================================
//==============================================================================

- (void)setSecret:(NSString *)secret
{
  [secret retain];
  [appSecret release];
  appSecret = secret;
}

- (BOOL)isLoggedIn
{
  return isLoggedIn;
}

- (NSString *)uid
{
  if (![sessionState isValid]) {
    return nil;
  }
  return [sessionState uid];
}

- (void)loginWithPermissions:(NSArray *)permissions
{
  // remember what permissions we asked for
  [permissions retain];
  [requestedPermissions release];
  requestedPermissions = permissions;

  if ([sessionState isValid]) {
    [self validateSession];
  } else {
    [self promptLogin];
  }
}

- (void)promptLogin
{
  NSMutableDictionary *loginParams = [[NSMutableDictionary alloc] init];
  if (requestedPermissions) {
    NSString *permissionsString = [requestedPermissions componentsJoinedByString:@","];
    [loginParams setObject:permissionsString forKey:@"req_perms"];
  }
  [loginParams setObject:APIKey      forKey:@"api_key"];
  [loginParams setObject:kAPIVersion forKey:@"v"];
  [loginParams setObject:[self getPreferedFBLocale] forKey:@"locale"];

  // adding this parameter keeps us from reading Safari's cookie when
  // performing a login for the first time. Sessions are still cached and
  // persistant so subsequent application launches will use their own
  // session cookie and not Safari's
  [loginParams setObject:@"true" forKey:@"skipcookie"];

  if (windowController) {
    [[windowController window] makeKeyAndOrderFront:self];
  } else {
    windowController =
    [[FBWebViewWindowController alloc] initWithCloseTarget:self
                                                  selector:@selector(webViewWindowClosed)];
    [windowController showWithParams:loginParams];
  }
}

- (void)logout
{
  [self callMethod:@"auth.expireSession"
     withArguments:nil
            target:self
          selector:@selector(expireSessionResponseComplete:)
             error:@selector(failedLogout:)];
  [sessionState clear];
  isLoggedIn = NO;
}

- (void)validateSession
{
  [self startBatch];
  [self fqlQuery:[NSString stringWithFormat:@"SELECT %@ FROM permissions WHERE uid = %@",
                      [requestedPermissions componentsJoinedByString:@","], [self uid]]
              target:self
            selector:@selector(gotGrantedPermissions:)
               error:nil];
  [self callMethod:@"users.getLoggedInUser"
     withArguments:nil
            target:self
          selector:@selector(gotLoggedInUser:)
             error:@selector(failedValidateSession:)];
  [self sendBatch];
}

- (void)refreshSession
{
  NSLog(@"refreshing session");
  isLoggedIn = NO;
  [sessionState invalidate];
  [self loginWithPermissions:requestedPermissions];
}

- (BOOL)hasPermission:(NSString *)perm
{
  return [sessionState hasPermission:perm];
}

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
  NSString *requestString = [self getRequestStringForMethod:method arguments:dict];
  FBRequest *request = [FBRequest requestWithRequest:requestString
                                              parent:self
                                              target:target
                                            selector:selector
                                               error:error];
  if ([self pendingBatch]) {
    [pendingBatchRequests addObject:request];
  } else {
    [request start];
  }
}

- (void)fqlQuery:(NSString *)query
              target:(id)target
            selector:(SEL)selector
               error:(SEL)error
{
  [self callMethod:@"fql.query"
     withArguments:[NSDictionary dictionaryWithObject:query forKey:@"query"]
            target:target
          selector:selector
             error:error];
}

- (void)fqlMultiquery:(NSDictionary *)queries
               target:(id)target
             selector:(SEL)selector
                error:(SEL)error
{
  NSDictionary* arguments = [NSDictionary dictionaryWithObject:[queries JSONRepresentation] forKey:@"queries"];
  NSString* requestString = [self getRequestStringForMethod:@"fql.multiquery" arguments:arguments];
  FBRequest* request = [FBMultiqueryRequest requestWithRequest:requestString
                                                        parent:self
                                                        target:target
                                                      selector:selector
                                                         error:error];
  if ([self pendingBatch]) {
    [pendingBatchRequests addObject:request];
  } else {
    [request start];
  }
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

- (void)sendBatch
{
  if (!isBatch) {
    [NSException raise:@"Batch Request exception"
                format:@"Cannot sendBatch if there is no pendingBatch"];
    return;
  }
  isBatch = NO;

  // call batch.run with the results of all the queued methods, using fbbatchrequest
  if ([pendingBatchRequests count] > 0) {
    NSDictionary* arguments = [NSDictionary dictionaryWithObject:[pendingBatchRequests JSONRepresentation] forKey:@"method_feed"];
    NSString *requestString = [self getRequestStringForMethod:@"batch.run" arguments:arguments];
    FBRequest *request = [FBBatchRequest requestWithRequest:requestString
                                                   requests:pendingBatchRequests
                                                     parent:self];
    [request start];
  }

  [pendingBatchRequests release];
  pendingBatchRequests = nil;
}

//==============================================================================
//==============================================================================
//==============================================================================

#pragma mark Callbacks
- (void)failedQuery:(FBRequest *)query withError:(NSError *)err
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
    [self refreshSession];
  }
}

- (void)gotGrantedPermissions:(id)response
{
  response = [response objectAtIndex:0];
  for (NSString* perm in response) {
    if ([[response objectForKey:perm] intValue] != 0) {
      [sessionState addPermission:perm];
    }
  }
}

- (void)gotLoggedInUser:(id)response
{
  // check for granted permissions
  BOOL needsNewPermissions = NO;
  for (NSString *perm in requestedPermissions) {
    if (![self hasPermission:perm]) {
      needsNewPermissions = YES;
      break;
    }
  }

  // if needs a permission, prompt. if session is valid, notify. else refresh.
  if (needsNewPermissions) {
    [self promptLogin];
  } else if ([[response stringValue] isEqualToString:[self uid]]) {
    isLoggedIn = YES;
    DELEGATE(@selector(FBConnectLoggedIn:));
  } else {
    [self refreshSession];
  }
}

- (void)failedValidateSession:(NSError *)error
{
  if ([error code] > 0) {
    // fb error, bad login
    [self promptLogin];
  } else {
    // net error, retry
    [self performSelector:@selector(validateSession)
               withObject:nil
               afterDelay:60.0];
  }
}

- (void)expireSessionResponseComplete:(id)json
{
  DELEGATE(@selector(FBConnectLoggedOut:));
}

- (void)failedLogout:(NSError *)error
{
  DELEGATE(@selector(FBConnectErrorLoggingOut:));
}

- (void)webViewWindowClosed
{
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
    } else {
      isLoggedIn = NO;
    }
  } else {
    isLoggedIn = NO;
  }
  [windowController release];
  windowController = nil;

  if (isLoggedIn) {
    DELEGATE(@selector(FBConnectLoggedIn:));
  } else {
    DELEGATE(@selector(FBConnectErrorLoggingIn:));
  }
}

//==============================================================================
//==============================================================================
//==============================================================================

#pragma mark Private Methods
- (NSString *)getPreferedFBLocale
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
  for (NSString* language in languages) {
    if ([fbLocales objectForKey:language]) {
      preferredLang = [fbLocales objectForKey:language];
      break;
    }
  }
  return preferredLang;
}

- (NSString *)getRequestStringForMethod:(NSString *)method arguments:(NSDictionary *)dict
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
  [args setObject:@"json" forKey:@"format"];
  [args setObject:@"true" forKey:@"ss"];
  [args setObject:[[NSNumber numberWithLong:time(NULL)] stringValue]
           forKey:@"call_id"];
  if ([sessionState isValid]) {
    [args setObject:[sessionState key] forKey:@"session_key"];
  }

  NSString *sig = [self sigForArguments:args];
  [args setObject:sig forKey:@"sig"];

  return [NSString urlEncodeArguments:args];
}

- (NSString *)sigForArguments:(NSDictionary *)dict
{
  NSArray *sortedKeys = [[dict allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
  NSMutableString *args = [NSMutableString string];
  for (NSString *key in sortedKeys) {
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
  return [args hexMD5];
}

@end
