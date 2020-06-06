# STRIAPManagerUtils


## version 0.2.5
```
新增接口
//恢复某种商品的订单  purchID 为商品id handle 为恢复后的数据 sdk 先简单处理，获得恢复后数据直接返回 后续再过滤
-(void)restoreCompletedTransactions:(NSString *)purchID handle:(IAPData)handle;
```

## version 0.2.4
```
处理内购恢复失败导致无法继续下单的问题
```
## version 0.2.0
```
新增接口
- (void)binAppLog:(IAPLog)appLog;

返回所有log
```
## version 0.1.7
```
新增接口
- (void)restoreCompletedapplicationUsername:(NSString *)applicationUsername

IAPLogHandle 增加字段 
typedef void (^IAPLogHandle)(NSString *transactionIdentifier ,NSString * desc , NSError *error , NSString *applicationUsername , NSString *purchID);

在收到 - (void)binLog:(IAPLogHandle)log; 错误时，
可以根据想法是否进行恢复购买

```

## version 0.1.8 苹果错误码对照

[typedef NS_ENUM(NSInteger,SKErrorCode) {
    SKErrorUnknown,
    SKErrorClientInvalid,                                                                         // client is not allowed to issue the request, etc.
    SKErrorPaymentCancelled,                                                                      // user cancelled the request, etc.
    SKErrorPaymentInvalid,                                                                        // purchase identifier was invalid, etc.
    SKErrorPaymentNotAllowed,                                                                     // this device is not allowed to make the payment
    SKErrorStoreProductNotAvailable API_AVAILABLE(ios(3.0), macos(10.15)),                        // Product is not available in the current storefront
    SKErrorCloudServicePermissionDenied API_AVAILABLE(ios(9.3)) API_UNAVAILABLE(macos),           // user has not allowed access to cloud service information
    SKErrorCloudServiceNetworkConnectionFailed API_AVAILABLE(ios(9.3)) API_UNAVAILABLE(macos),    // the device could not connect to the nework
    SKErrorCloudServiceRevoked API_AVAILABLE(ios(10.3)) API_UNAVAILABLE(macos),                   // user has revoked permission to use this cloud service
    SKErrorPrivacyAcknowledgementRequired API_AVAILABLE(ios(12.2), macos(10.14.4)),               // The user needs to acknowledge Apple's privacy policy
    SKErrorUnauthorizedRequestData API_AVAILABLE(ios(12.2), macos(10.14.4)),                      // The app is attempting to use SKPayment's requestData property, but does not have the appropriate entitlement
    SKErrorInvalidOfferIdentifier API_AVAILABLE(ios(12.2), macos(10.14.4)),                       // The specified subscription offer identifier is not valid
    SKErrorInvalidSignature API_AVAILABLE(ios(12.2), macos(10.14.4)),                             // The cryptographic signature provided is not valid
    SKErrorMissingOfferParams API_AVAILABLE(ios(12.2), macos(10.14.4)),                           // One or more parameters from SKPaymentDiscount is missing
    SKErrorInvalidOfferPrice API_AVAILABLE(ios(12.2), macos(10.14.4))                             // The price of the selected offer is not valid (e.g. lower than the current base subscription price)
} API_AVAILABLE(ios(3.0), macos(10.7));

-1001 、-1003 连接服务器失败


[![CI Status](https://img.shields.io/travis/335074307@qq.com/STRIAPManagerUtils.svg?style=flat)](https://travis-ci.org/335074307@qq.com/STRIAPManagerUtils)
[![Version](https://img.shields.io/cocoapods/v/STRIAPManagerUtils.svg?style=flat)](https://cocoapods.org/pods/STRIAPManagerUtils)
[![License](https://img.shields.io/cocoapods/l/STRIAPManagerUtils.svg?style=flat)](https://cocoapods.org/pods/STRIAPManagerUtils)
[![Platform](https://img.shields.io/cocoapods/p/STRIAPManagerUtils.svg?style=flat)](https://cocoapods.org/pods/STRIAPManagerUtils)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

STRIAPManagerUtils is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'STRIAPManagerUtils'
```

## Author

335074307@qq.com, oncwnuOFQIPUqFMr48EisEyZQvmM@git.weixin.qq.com

## License

STRIAPManagerUtils is available under the MIT license. See the LICENSE file for more info.
