

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
typedef void (^IAPLog)(NSString *log);
typedef void (^IAPData)(NSData *data);

/*
 transactionIdentifier 流水号
 desc 报错描述
 info 报错信息
 */
typedef void (^IAPLogHandle)(NSString *transactionIdentifier ,NSString * desc , NSError *error , NSString *applicationUsername , NSString *purchID);


@interface STRIAPManager : NSObject

/*
 自动续订的id ，当出现此id 是续订流程将会简化
 */
@property(nonatomic,strong) NSString* subscribeId;

@property(nonatomic,assign) NSInteger version;//如果是0 的话所有代码都会走 1 的话会少走 一点代码，比如错误返回，跟一些通知

@property(nonatomic,assign) BOOL beginTimer;//开启定时器 ，默认是YES ，关闭定时器，可能会出现丢单问题

//是否自动尝试恢复订单默认yes 自动续订 需要设置为false 因为自动续订会一直恢复回来，并且数据特别多
- (void)autoRestoreCompletedTransactions:(BOOL)autoRestores;

//恢复某种商品的订单  purchID 为商品id handle 为恢复后的数据 sdk 先简单处理，获得恢复后数据直接返回 后续再过滤
- (void)restoreCompletedTransactions:(NSString *)purchID handle:(IAPData)handle;

- (void)setErrorderHandle:(IAPErrorderHandle)handle;

- (void)finishTransactionByPurchID:(NSString *)purchID;



/*
    单利
 */
+ (instancetype)shareSIAPManager;

/*
    设置订单回调，所有购买都从一个入口去h处理 根据 IAPCompletionHandle 区分订单
 */
//自动续订的恢复购买走下面的接口 verifySubscribe 这边会返回自动续订的商品信息，需要自己去拦截掉  SIAPPurchRestored 
- (void)setCompleteHandle:(IAPCompletionHandle)handle;

/*
    开启内购
    purchID -> 商品id
    para -> 订单参数
 */
- (void)startPurchWithID:(NSString *)purchID para:(id)para tmpid:(NSString *)tmpid  info:(id)info;


- (void)beginPurchWithID:(NSString *)purchID applicationUsername:(NSString*)applicationUsername;


//完结掉所有旧的订单 谨慎使用
- (void)finishAllTransaction;

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
- (void)restoreCompletedTransactionsPara:(id)para ;

//试验结果，发现依旧会全部回来，弃用
- (void)restoreCompletedapplicationUsername:(NSString *)applicationUsername ;

//自动续订的恢复购买走这边的流程
- (void)verifySubscribe:(IAPSubscribeHandle)handle;

#pragma mark -  订单校验 前端s测试用
- (void)testTransaction;

//获取当前存在的回执
- (NSData *)verifyPurchase;

/*校验订单前端是否能成功*/
- (void)testTransactionData:(NSData *)receipt index:(NSInteger)index;

#pragma mark -  订单校验 添加log 回调 更新支付状态
//内购报错回调
- (void)binLog:(IAPLogHandle)log;

//内购流程回调
- (void)binAppLog:(IAPLog)appLog;


@end

NS_ASSUME_NONNULL_END
