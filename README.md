# STRIAPManagerUtils



## version 0.1.7
```
新增接口
- (void)restoreCompletedapplicationUsername:(NSString *)applicationUsername

IAPLogHandle 增加字段 
typedef void (^IAPLogHandle)(NSString *transactionIdentifier ,NSString * desc , NSError *error , NSString *applicationUsername , NSString *purchID);

在收到 - (void)binLog:(IAPLogHandle)log; 错误时，
可以根据想法是否进行恢复购买

```


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
