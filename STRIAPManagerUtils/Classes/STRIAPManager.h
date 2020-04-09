

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
UIKIT_EXTERN NSNotificationName const ReloadTransactionObserver;

typedef enum {
    SIAPPurchSuccess = 0,       // 购买成功
    SIAPPurchFailed = 1,        // 购买失败
    SIAPPurchCancle = 2,        // 取消购买
    SIAPPurchVerFailed = 3,     // 订单校验失败
    SIAPPurchVerSuccess = 4,    // 订单校验成功
    SIAPPurchNotArrow = 5,      // 不允许内购
    SIAPPurchRestored  = 6, //恢复
}SIAPPurchType;

// key -> transaction.transactionIdentifier
/*
    type -> SIAPPurchType 购买状态
    data -> 回执
    key -> 流水号 收到服务端结果后前端根据 流水号完结指定订单
    para -> 参数
    info->自定义携带参数，方便下级页面跳转分析
 */
typedef void (^IAPCompletionHandle)(SIAPPurchType type , NSData *data , id para , NSString *tmpid ,  NSString *transactionIdentifier , NSString *orderId , id info);

typedef void (^IAPSubscribeHandle)(NSMutableArray *data);
typedef void (^IAPErrorderHandle)(NSString *tmpid);

/*
 transactionIdentifier 流水号
 desc 报错描述
 info 报错信息
 */
typedef void (^IAPLogHandle)(NSString *transactionIdentifier ,NSString * desc ,NSString * info);


@interface STRIAPManager : NSObject


//是否自动尝试恢复订单默认yes 自动续订 需要设置为false
- (void)autoRestoreCompletedTransactions:(BOOL)autoRestores;

- (void)setErrorderHandle:(IAPErrorderHandle)handle;


-(void)finishTransactionByPurchID:(NSString *)purchID;
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
- (void)startPurchWithID:(NSString *)purchID para:(id)para tmpid:(NSString *)tmpid  info:(id)info;

//完结掉所有旧的订单 谨慎使用
//- (void)finishAllTransaction;

/*
    根据 key 完结掉指定订单
 */
-(void)finishTransactionByTransactionIdentifier:(NSString *)transactionIdentifier;


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

//获取当前存在的回执
- (NSData *)verifyPurchase;

/*校验订单前端是否能成功*/
- (void)testTransactionData:(NSData *)receipt index:(NSInteger)index;

#pragma mark -  订单校验 添加log 回调 更新支付状态
- (void)binLog:(IAPLogHandle)log;
@end

NS_ASSUME_NONNULL_END
