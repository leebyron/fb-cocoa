/*
 *  FBCocoa.h
 *  FBCocoa
 *
 *  Copyright 2009 Facebook Inc. All rights reserved.
 *
 */

#define kAPIVersion @"1.0"

enum { // Facebook Connect Error Codes

  // Not Really an Error
  FBSuccess                        = 0,

  // General Errors
  FBAPIUnknownError                = 1,
  FBAPIServiceError                = 2,
  FBAPIMethodError                 = 3,
  FBAPITooManyCallsError           = 4,
  FBAPIBadIPError                  = 5,
  FBAPISecureError                 = 8,
  FBAPIRateError                   = 9,
  FBAPIPermissionDeniedError       = 10,
  FBAPIDeprecatedError             = 11,
  FBAPIVersionError                = 12,

  // Parameter Errors
  FBParamError                     = 100,
  FBParamAPIKeyError               = 101,
  FBParamSessionKeyError           = 102,
  FBParamCallIDError               = 103,
  FBParamSignatureError            = 104,
  FBParamUserIDError               = 110,
  FBParamUserFieldError            = 111,
  FBParamSocialFieldError          = 112,
  FBParamAlbumIDError              = 120,
  FBParamBadEIDError               = 150,
  FBParamUnknownCityError          = 151,

  // User Permission Errors
  FBPermissionError                = 200,
  FBPermissionUserError            = 210,
  FBPermissionAlbumError           = 220,
  FBPermissionPhotoError           = 221,
  FBPermissionEventError           = 290,
  FBPermissionRSVPEventError       = 299,

  // Authentication Errors
  FBAuthenticationEmailError       = 400,
  FBAuthenticationLoginError       = 401,
  FBAuthenticationSignatureError   = 402,
  FBAuthenticationTimestampError   = 403,

  // Session Errors
  FBSessionExpiredError            = 450,
  FBSessionMethodError             = 451,
  FBSessionInvalidError            = 452,
  FBSessionRequiredError           = 453,
  FBSessionRequiredForSecretError  = 454,
  FBSessionCannotUseSecretError    = 455,

  // Application Messaging Errors
  FBMessageBannedError             = 500,
  FBMessageNoBodyError             = 501,
  FBMessageTooLongError            = 502,
  FBMessageRateError               = 503,
  FBMessageInvalidThreadError      = 504,
  FBMessageInvalidRecipientError   = 505,
  FBPokeInvalidRecipientError      = 510,
  FBPokeOutstandingError           = 511,
  FBPokeRateError                  = 512,

  // FQL Errors
  FBFQLParserError                 = 601,
  FBFQLUnknownFieldError           = 602,
  FBFQLUnknownTableError           = 603,
  FBFQLNotIndexableError           = 604,

  // Data Store Errors
  FBDataUnknownError               = 800,
  FBDataInvalidOperationError      = 801,
  FBDataQuotaExceededError         = 802,
  FBDataObjectNotFoundError        = 803,
  FBDataObjectAlreadyExistsError   = 804,
  FBDataDatabaseError              = 805,

  // Batch Errors
  FBBatchAlreadyStartedError       = 951,
  FBBatchNotStartedError           = 952,
  FBBatchMethodNotAllowedError     = 953
};
typedef NSUInteger FBErrorCode;


#import <FBCocoa/FBConnect.h>
#import <FBCocoa/FBRequest.h>
