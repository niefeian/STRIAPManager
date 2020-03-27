

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
/*
    type -> SIAPPurchType 购买状态
    data -> 回执
    key -> 流水号 收到服务端结果后前端根据 流水号完结指定订单
    para -> 参数
 */
typedef void (^IAPCompletionHandle)(SIAPPurchType type , NSData *data , id para , NSString *tmpid ,  NSString *transactionIdentifier , NSString *orderId );

typedef void (^IAPSubscribeHandle)(NSMutableArray *data);


@interface STRIAPManager : NSObject

/*
    单利
 */
+ (instancetype)shareSIAPManager;

/*
    设置订单回调，所有购买都从一个入口去h处理 根据 IAPCompletionHandle 区分订单
 */
- (void)setCompleteHandle:(IAPCompletionHandle)handle;

/*
    开启内购
    purchID -> 商品id
    para -> 订单参数
 */
- (void)startPurchWithID:(NSString *)purchID para:(id)para tmpid:(NSString *)tmpid;

//完结掉所有旧的订单 谨慎使用
//- (void)finishAllTransaction;

/*
    根据 key 完结掉指定订单
 */
-(void)finishTransactionByKey:(NSString *)key;


/*
    刷新订单列表，检查是否有未完成的订单
    内部有通过定时器进行调用
    外部可以在重新联网、应用进入前台等情况调用
 */
- (void)reloadTransactionObserver;


#pragma mark - 以下涉及到自动续订会员恢复
- (void)restoreCompletedTransactions;

- (void)verifySubscribe:(IAPSubscribeHandle)handle;

#pragma mark -  订单校验 前端s测试用
- (void)testTransaction;

- (NSData *)verifyPurchase;

/*校验订单前端是否能成功*/
- (void)testTransactionData:(NSData *)receipt index:(NSInteger)index;


@end

NS_ASSUME_NONNULL_END
