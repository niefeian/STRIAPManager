/*注意事项：
 1.沙盒环境测试appStore内购流程的时候，请使用没越狱的设备。
 2.请务必使用真机来测试，一切以真机为准。
 3.项目的Bundle identifier需要与您申请AppID时填写的bundleID一致，不然会无法请求到商品信息。
 4.如果是你自己的设备上已经绑定了自己的AppleID账号请先注销掉,否则你哭爹喊娘都不知道是怎么回事。
 5.订单校验 苹果审核app时，仍然在沙盒环境下测试，所以需要先进行正式环境验证，如果发现是沙盒环境则转到沙盒验证。
 识别沙盒环境订单方法：
 1.根据字段 environment = sandbox。
 2.根据验证接口返回的状态码,如果status=21007，则表示当前为沙盒环境。
 苹果反馈的状态码：
 21000 App Store无法读取你提供的JSON数据
 21002 订单数据不符合格式
 21003 订单无法被验证
 21004 你提供的共享密钥和账户的共享密钥不一致
 21005 订单服务器当前不可用
 21006 订单是有效的，但订阅服务已经过期。当收到这个信息时，解码后的收据信息也包含在返回内容中
 21007 订单信息是测试用（sandbox），但却被发送到产品环境中验证
 21008 订单信息是产品环境中使用，但却被发送到测试环境中验证
 */

#import "STRIAPManager.h"
#import <StoreKit/StoreKit.h>

@interface STRIAPManager()<SKPaymentTransactionObserver,SKProductsRequestDelegate>{
    NSString           *_purchID;
    IAPCompletionHandle _handle;
    IAPSubscribeHandle _subhandle;
    NSMutableDictionary *_map;
    NSTimer *timer;
    NSString *_para;
}
@end
@implementation STRIAPManager

#pragma mark - ♻️life cycle

+ (instancetype)shareSIAPManager{
    static STRIAPManager *IAPManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        IAPManager = [[STRIAPManager alloc] init];
    });
    return IAPManager;
}

- (instancetype)init{
    self = [super init];
    if (self) {
         _map = [[NSMutableDictionary alloc] init];
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        //定时器循环检查 本地是否有没有完成的订单  增加一层保险 只有极端的情况下 才会出现有订单而被闲置不处理的情况
        timer =  [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(reloadTransactionObserver) userInfo:nil repeats:YES];
    }
    return self;
}


#pragma mark - 设置订单信息的回调
- (void)setCompleteHandle:(IAPCompletionHandle)handle{
     _handle = handle;
}

#pragma mark - 🚪public
- (void)startPurchWithID:(NSString *)purchID para:(NSString *)para {
    if (purchID) {
        if ([SKPaymentQueue canMakePayments]) {
            // 开始购买服务
            _purchID = purchID;
            _para = para;
            NSSet *nsset = [NSSet setWithArray:@[purchID]];
            SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:nsset];
            request.delegate = self;
            [request start];
        }
    }
}


//根据 key 完结掉指定订单
-(void)finishTransactionByKey:(NSString *)key{
    SKPaymentTransaction *transaction = [_map objectForKey:key];
    if (transaction) {
         [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        [_map removeObjectForKey:key];
    }
}


-(void)reloadTransactionObserver{
        /*重设KVO的方式依旧会存在页面卡死在Loding页的情况*/
//     [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
//     [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    
    //将数据存在 _map ,支付完成的数据都会在这边 ，然后通过 key - value 进行完结指定的订单
    if (_map != nil && _map.allValues.count > 0) {
        NSURL *recepitURL = [[NSBundle mainBundle] appStoreReceiptURL];
        NSData *receipt = [NSData dataWithContentsOfURL:recepitURL];
        for (SKPaymentTransaction * transaction in _map.allValues) {
            [self handleActionWithType:SIAPPurchSuccess data:receipt  key:transaction.transactionIdentifier para:transaction.payment.applicationUsername];
        }
    }
    // 购买成功将交易凭证发送给服务端进行再次校验
}


//完结掉所有旧的订单
-(void)finishAllTransaction{
    NSArray* transactions = [SKPaymentQueue defaultQueue].transactions;
    if (transactions.count > 0) {
        for (SKPaymentTransaction* transaction in transactions){
            if (transaction.transactionState == SKPaymentTransactionStatePurchased) {
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            }
        }
        [_map removeAllObjects];
    }
}

#pragma mark -  订单校验 前端测试用
- (void)testTransaction{

    NSURL *recepitURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:recepitURL];
    NSError *error;
    NSDictionary *requestContents = @{
                      @"receipt-data": [receipt base64EncodedStringWithOptions:0]
                      };
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents
                                          options:0
                                            error:&error];



    //In the test environment, use https://sandbox.itunes.apple.com/verifyReceipt
    //In the real environment, use https://buy.itunes.apple.com/verifyReceipt

    NSString *serverString = @"https://sandbox.itunes.apple.com/verifyReceipt";

    NSURL *storeURL = [NSURL URLWithString:serverString];
    NSMutableURLRequest *storeRequest = [NSMutableURLRequest requestWithURL:storeURL];
    [storeRequest setHTTPMethod:@"POST"];
    [storeRequest setHTTPBody:requestData];

    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:storeRequest queue:queue
           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
               if (connectionError) {
                   // 无法连接服务器,购买校验失败
                  
                   
               } else {
                   NSError *error;
                   NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                   if (!jsonResponse) {
                       // 苹果服务器校验数据返回为空校验失败
                     
                   }
                   
                   // 先验证正式服务器,如果正式服务器返回21007再去苹果测试服务器验证,沙盒测试环境苹果用的是测试服务器
                   NSString *status = [NSString stringWithFormat:@"%@",jsonResponse[@"status"]];
                   if (status && [status isEqualToString:@"21007"]) {
                   
                       
                   }else if(status && [status isEqualToString:@"0"]){
                     
                   }
    #if DEBUG
                   NSLog(@"----验证结果 %@",jsonResponse);
    #endif
               }
           }];
}


#pragma mark - 🔒private
- (void)handleActionWithType:(SIAPPurchType)type data:(NSData *)data key:(NSString *)key para:(NSString *)para {
    NSString *tips = @"";
    switch (type) {
        case SIAPPurchSuccess:
            tips = @"购买成功";
            break;
        case SIAPPurchFailed:
            tips = @"购买失败";
            break;
        case SIAPPurchCancle:
             tips = @"用户取消购买";
            break;
        case SIAPPurchVerFailed:
             tips = @"订单校验失败";
            break;
        case SIAPPurchVerSuccess:
             tips = @"订单校验成功";
            break;
        case SIAPPurchNotArrow:
             tips = @"不允许程序内付费";
            break;
        default:
            break;
    }
    
    #if DEBUG
    NSLog(@"%@", tips);
    #endif
    [[NSNotificationCenter defaultCenter] postNotificationName:@"showLondTip" object:tips];
    if(_handle){
        _handle(type,data,key,para);
    }
}


#pragma mark - 以下涉及到自动续订会员恢复
-(void)restoreCompletedTransactions{
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void) paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue{
     NSMutableArray *purchasedItemIDs = [[NSMutableArray alloc] init];
        for (SKPaymentTransaction *transaction in queue.transactions){
            NSString *productID = transaction.payment.productIdentifier;
            [purchasedItemIDs addObject:productID];
        }
        
        if(_subhandle){
          _subhandle(purchasedItemIDs);
        }

}

- (void)verifySubscribe:(IAPSubscribeHandle)handle{
    _subhandle = handle;
}

#pragma mark - 🍐delegate
// 交易结束
- (void)completeTransaction:(SKPaymentTransaction *)transaction{
    // Your application should implement these two methods.
    [self verifyPurchaseWithPaymentTransaction:transaction isTestServer:NO];
}

// 交易失败
- (void)failedTransaction:(SKPaymentTransaction *)transaction{
    if (transaction.error.code != SKErrorPaymentCancelled) {
        [self handleActionWithType:SIAPPurchFailed data:nil key:@"" para:@""];
    }else{
        [self handleActionWithType:SIAPPurchCancle data:nil key:@"" para:@""];
    }
    
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (NSData *)verifyPurchase{
    //交易验证
    NSURL *recepitURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:recepitURL];
    if  (receipt == nil){
        return [NSData new];
    }
    return receipt;
}


- (void)verifyPurchaseWithPaymentTransaction:(SKPaymentTransaction *)transaction isTestServer:(BOOL)flag{
    //交易验证
    NSURL *recepitURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:recepitURL];
    
    if(!receipt){
        // 交易凭证为空验证失败  是否要完结订单？ 存在付了钱但是订单没回来的情况
        [self handleActionWithType:SIAPPurchVerFailed data:nil key:@"" para:@""];
        return;
    }
    
    // 购买成功将交易凭证发送给服务端进行再次校验
    [_map setObject:transaction forKey:transaction.transactionIdentifier];
    [self handleActionWithType:SIAPPurchSuccess data:receipt  key:transaction.transactionIdentifier para:transaction.payment.applicationUsername];
}

#pragma mark - SKProductsRequestDelegate
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    NSArray *product = response.products;
    if([product count] <= 0){
#if DEBUG
        NSLog(@"--------------没有商品------------------");
#endif
        return;
    }
    
    SKProduct *p = nil;
    for(SKProduct *pro in product){
        if([pro.productIdentifier isEqualToString:_purchID]){
            p = pro;
            break;
        }
    }
    
#if DEBUG
    NSLog(@"productID:%@", response.invalidProductIdentifiers);
    NSLog(@"产品付费数量:%lu",(unsigned long)[product count]);
    NSLog(@"%@",[p description]);
    NSLog(@"%@",[p localizedTitle]);
    NSLog(@"%@",[p localizedDescription]);
    NSLog(@"%@",[p price]);
    NSLog(@"%@",[p productIdentifier]);
    NSLog(@"发送购买请求");
#endif

    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:p];
    payment.applicationUsername = _para;
    
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error{
      [[NSNotificationCenter defaultCenter] postNotificationName:@"showLondTip" object:@"用户取消操作"];
}
//请求失败
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error{
#if DEBUG
    NSLog(@"------------------错误-----------------:%@", error);
#endif
}

- (void)requestDidFinish:(SKRequest *)request{
#if DEBUG
    NSLog(@"------------反馈信息结束-----------------");
#endif
}

#pragma mark - SKPaymentTransactionObserver
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions{
    NSLog(@"--------------updatedTransactions------------------");
    for (SKPaymentTransaction *tran in [transactions reverseObjectEnumerator]) {
        switch (tran.transactionState) {
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:tran];
                break;
            case SKPaymentTransactionStatePurchasing:
#if DEBUG
                NSLog(@"商品添加进列表");
#endif
                break;
            case SKPaymentTransactionStateRestored:
#if DEBUG
                NSLog(@"已经购买过商品");
#endif
                // 消耗型不支持恢复购买
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                break;
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:tran];
                break;
            default:
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                break;
        }
    }
}

- (void)dealloc{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}
@end
