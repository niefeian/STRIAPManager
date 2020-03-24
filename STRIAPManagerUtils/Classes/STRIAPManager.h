

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum {
    SIAPPurchSuccess = 0,       // 购买成功
    SIAPPurchFailed = 1,        // 购买失败
    SIAPPurchCancle = 2,        // 取消购买
    SIAPPurchVerFailed = 3,     // 订单校验失败
    SIAPPurchVerSuccess = 4,    // 订单校验成功
    SIAPPurchNotArrow = 5,      // 不允许内购
}SIAPPurchType;

// key -> transaction.transactionIdentifier
typedef void (^IAPCompletionHandle)(SIAPPurchType type , NSData *data , NSString *key , NSString *para);

typedef void (^IAPSubscribeHandle)(NSMutableArray *data);



@interface STRIAPManager : NSObject

+ (instancetype)shareSIAPManager;

- (void)setCompleteHandle:(IAPCompletionHandle)handle;

//开始内购
- (void)startPurchWithID:(NSString *)purchID para:(NSString *)para ;

- (void)restoreCompletedTransactions;

- (NSData *)verifyPurchase;

//完结掉所有旧的订单
- (void)finishAllTransaction;

-(void)finishTransactionByKey:(NSString *)key;
//重新设置代理
- (void)reloadTransactionObserver;

//这个是会员恢复用的
- (void)verifySubscribe:(IAPSubscribeHandle)handle;

//失败的时候进行一次测试
-(void)testTransaction;
@end

NS_ASSUME_NONNULL_END
