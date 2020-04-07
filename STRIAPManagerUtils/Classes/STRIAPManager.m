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
#import "Reachability/Reachability.h"

NSNotificationName const ReloadTransactionObserver = @"ReloadTransactionObserver";

@interface STRIAPManager()<SKPaymentTransactionObserver,SKProductsRequestDelegate>{
    NSString           *_purchID;
    IAPCompletionHandle _handle;
    IAPSubscribeHandle _subhandle;
    IAPLogHandle _log;
    IAPErrorderHandle _errorhandle;
    BOOL _reloading;
    NSInteger index;
    NSMutableArray *_willDelKey; // 将要结束的
//    NSMutableArray *_lodingKey; // 正在提交的
    NSMutableArray *_finishKeys;
    NSTimer *timer;
    NSString *_para;
    BOOL isError;
    BOOL _autoRestores;
    
    Reachability *reachability;
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
        _finishKeys = [[NSMutableArray alloc] init];
        _willDelKey = [[NSMutableArray alloc] init];
        reachability = [Reachability reachabilityForInternetConnection];
        __weak typeof(self) weakSelf = self;
        reachability.reachableBlock = ^(Reachability *reachability) {
            [weakSelf reloadNet];
        };
        [reachability startNotifier];
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        _autoRestores = YES;
        //定时器循环检查 本地是否有没有完成的订单  增加一层保险 只有极端的情况下 才会出现有订单而被闲置不处理的情况
        index = 0;
        timer =  [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(reloadErrorfinishTransaction) userInfo:nil repeats:YES];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTransactionObserver) name:ReloadTransactionObserver object:nil];
    }
    return self;
}

- (void)autoRestoreCompletedTransactions:(BOOL)autoRestores{
    _autoRestores = autoRestores;
}

-(void)reloadNet{
    
    if (_autoRestores){
         [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
    }
    
   [self reloadTransactionObserver];
}

-(void)reloadErrorfinishTransaction{
    index = index + 1;
//    if (index%10 == 0) {
    if (reachability.isReachable){
          [self reloadTransactionObserver];
    }
      
//    }
//    else if (_finishKeys.count > 0){
//        NSArray* transactions = [SKPaymentQueue defaultQueue].transactions;
//        NSArray *array = [[NSArray alloc] initWithArray:_finishKeys];
//        [_finishKeys removeAllObjects];
//        if (transactions.count > 0) {
//            for (SKPaymentTransaction* transaction in transactions){
//                  if ([array containsObject:transaction.transactionIdentifier]) {
//                      [_finishKeys addObject:transaction.transactionIdentifier];
//                      [self finishTransaction:transaction];
//                  }else if (transaction.transactionState == SKPaymentTransactionStateFailed){
//                        [_finishKeys addObject:transaction.transactionIdentifier];
//                        [self finishTransaction:transaction];
//                  }
//            }
//        }else{
//            [_finishKeys removeAllObjects];
//        }
//    }
}

#pragma mark - 设置订单信息的回调
- (void)setCompleteHandle:(IAPCompletionHandle)handle{
     _handle = handle;
}

#pragma mark - 🚪public
- (void)startPurchWithID:(NSString *)purchID para:(id)para tmpid:(NSString *)tmpid  info:(id)info {

    if (purchID) {
        if ([SKPaymentQueue canMakePayments]) {
            // 开始购买服务
            _purchID = purchID;
            NSArray* transactions = [SKPaymentQueue defaultQueue].transactions;
            if (transactions.count > 0) {
                for (SKPaymentTransaction* transaction in transactions){
                    if ((transaction.transactionState == SKPaymentTransactionStatePurchased || transaction.transactionState == SKPaymentTransactionStateRestored) && transaction.payment.productIdentifier == purchID) {
                        if ([_willDelKey containsObject:transaction.transactionIdentifier]){
                            [self finishTransaction:transaction];
                            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC));
                            dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
                                 NSArray* transactions2 = [SKPaymentQueue defaultQueue].transactions;
                                if (transactions2.count > 0) {
                                    for (SKPaymentTransaction* transaction2 in transactions2){
                                        if ((transaction2.transactionState == SKPaymentTransactionStatePurchased || transaction2.transactionState == SKPaymentTransactionStateRestored) && transaction2.payment.productIdentifier == purchID) {
                                            [[NSNotificationCenter defaultCenter] postNotificationName:@"showLonding" object:@"正在恢复"];
                                            [self verifyPurchaseWithPaymentTransaction:transaction2];
                                        }
                                    }
                                }else{
                                    [self beginPurchWithID:purchID para:para tmpid:tmpid info:info];
                                }
                            });
                        }else{
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"showLonding" object:@"正在恢复"];
                            [self verifyPurchaseWithPaymentTransaction:transaction];
                        }
                         return;
                    }else if (transaction.payment.productIdentifier == purchID){
//                        [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
                        double delayInSeconds = 15.0;
                        isError = YES;
                          dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                          dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
                              if (self->isError){
                                  self->isError = NO;
                                  [self finshProductIdentifier:purchID];
                                   id paras =  [[NSUserDefaults standardUserDefaults] objectForKey:purchID];
                                  if (self->_errorhandle && paras) {
                                       NSDictionary *dic = [self dictionaryWithJsonString:paras];
                                      NSString *tmpids = [dic objectForKey:@"tmpid"];
                                      if (tmpids){
                                          self->_errorhandle(tmpids);
                                      }
                                  }
                                  [self beginPurchWithID:purchID para:para tmpid:tmpid info:info];
                              }
                          });
                        return;
                    }
                }
            }
            if ([self getWillFinsh:purchID]){
//                [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
                double delayInSeconds = 15.0;
                    isError = YES;
                   dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                   dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
                       if (self->isError){
                           self->isError = NO;
                           [self finshProductIdentifier:purchID];
                            id paras =  [[NSUserDefaults standardUserDefaults] objectForKey:purchID];
                          
                           if (self->_errorhandle && paras) {
                                NSDictionary *dic = [self dictionaryWithJsonString:paras];
                               NSString *tmpids = [dic objectForKey:@"tmpid"];
                               if (tmpids){
                                   self->_errorhandle(tmpids);
                               }
                           }
                           [self beginPurchWithID:purchID para:para tmpid:tmpid info:info];
                       }
                       
                   });
                return;
            }
            [self beginPurchWithID:purchID para:para tmpid:tmpid info:info];
        }
    }
}

- (void)beginPurchWithID:(NSString *)purchID para:(id)para tmpid:(NSString *)tmpid  info:(id)info {
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    [dic setValue:para forKey:@"para"];
    [dic setValue:purchID forKey:@"purchID"];
    [dic setValue:tmpid forKey:@"tmpid"];
    [dic setValue:info forKey:@"info"];
    _para = [self dataTOjsonString:dic];

    NSSet *nsset = [NSSet setWithArray:@[purchID]];
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:nsset];
    request.delegate = self;
    [request start];
}



//根据 key 完结掉指定订单
-(void)finishTransactionByTransactionIdentifier:(NSString *)transactionIdentifier{
        NSArray* transactions = [SKPaymentQueue defaultQueue].transactions;
        if (transactions.count > 0) {
        for (SKPaymentTransaction* transaction in transactions){
            if (transaction && transaction.transactionIdentifier){
                if ([transaction.transactionIdentifier isEqualToString: transactionIdentifier]) {
                      [self finishTransaction:transaction];
                }
            }
        }
    }
}

//_errorFinishKey
- (void)finishTransaction:(SKPaymentTransaction *)transaction{
    if (!_willDelKey){
        _willDelKey = [[NSMutableArray alloc] init];
    }
    if (transaction.transactionIdentifier){
        if (![_willDelKey containsObject:transaction.transactionIdentifier]){
             [_willDelKey addObject:transaction.transactionIdentifier];
        }
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }else{
        
    }
    
}

-(void)reloadTransactionObserver{
    if (_reloading){
        return;
    }
    _reloading = YES;
    double delayInSeconds = 5.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
        self->_reloading = NO;
    });
    
    index = 1;
    NSArray* transactions = [SKPaymentQueue defaultQueue].transactions;
   if (transactions.count > 0 ) {
        NSURL *recepitURL = [[NSBundle mainBundle] appStoreReceiptURL];
        NSData *receipt = [NSData dataWithContentsOfURL:recepitURL];
       for (SKPaymentTransaction* transaction in transactions){
           if (transaction.transactionState == SKPaymentTransactionStatePurchased  || transaction.transactionState == SKPaymentTransactionStateRestored ) {
               SIAPPurchType SIAPPurchState = transaction.transactionState == SKPaymentTransactionStatePurchased ? SIAPPurchSuccess : SIAPPurchRestored;
               if (![_willDelKey containsObject:transaction.transactionIdentifier]){
                   if (!transaction.payment.applicationUsername){
                       id para =  [[NSUserDefaults standardUserDefaults] objectForKey:transaction.payment.productIdentifier];
                       if (para){
                           [self handleActionWithType:SIAPPurchState data:receipt  key:transaction.transactionIdentifier para:para];
                       }else{
                           if (_para){
                                [self handleActionWithType:SIAPPurchState data:receipt  key:transaction.transactionIdentifier para:_para];
                           }else{
                               [self finishTransaction:transaction];
                           }
                       }
                   }else{
                       [self handleActionWithType:SIAPPurchState data:receipt  key:transaction.transactionIdentifier para:transaction.payment.applicationUsername];
                   }
                   
               }
           }else if (transaction.transactionState == SKPaymentTransactionStateFailed ){
//               [[SKPaymentQueue defaultQueue] ]
//               [self reloadNet];
           }
       }
   }
}




//完结掉所有旧的订单
-(void)finishAllTransaction{
    NSArray* transactions = [SKPaymentQueue defaultQueue].transactions;
    if (transactions.count > 0) {
        for (SKPaymentTransaction* transaction in transactions){
            if (transaction.transactionState == SKPaymentTransactionStatePurchased) {
                  [self finishTransaction:transaction];
            }
        }
    }
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
        case SIAPPurchRestored:
            tips = @"购买成功";
            break;
        default:
            break;
    }
    
    #if DEBUG
    NSLog(@"%@", tips);
    [self blockLogTransactionIdentifier:key desc:tips info:@""];
    #endif
    [[NSNotificationCenter defaultCenter] postNotificationName:@"showLondTip" object:tips];
    if(_handle){
        NSDictionary *dic = [self dictionaryWithJsonString:para];
        if (!dic){
            dic = [self dictionaryWithJsonString:_para];
        }
        if (!dic){
            //参数完全丢失
            #if DEBUG
            [self blockLogTransactionIdentifier:key desc:@"交易参数完全丢失无法进行下一步 " info:@""];
            #endif
            return;
        }
        id p = [dic objectForKey:@"para"];
        NSString *purchID = [dic objectForKey:@"purchID"];
        NSString *tmpid = [dic objectForKey:@"tmpid"];
        id info = [dic objectForKey:@"info"];
        if (!info) {
            info = @"";
        }
        if (!tmpid) {
            tmpid = @"";
        }
        
        _handle(type,data,p,tmpid,key,purchID,info);
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

// 交易失败
- (void)failedTransaction:(SKPaymentTransaction *)transaction{
    if (transaction.error.code != SKErrorPaymentCancelled) {
        [self handleActionWithType:SIAPPurchFailed data:nil key:@"" para:@""];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"showLondTip" object:@"网络连接失败,请稍后尝试~"];
        //这种失败不去 finishTransaction
    }else{
        [self handleActionWithType:SIAPPurchCancle data:nil key:@"" para:@""];
//        [self finshProductIdentifier:transaction.payment.productIdentifier];
        [self finishTransaction:transaction];
    }
   
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


- (void)verifyPurchaseWithPaymentTransaction:(SKPaymentTransaction *)transaction{
    //交易验证
    NSURL *recepitURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:recepitURL];
    if(!receipt){
        // 交易凭证为空验证失败  是否要完结订单？ 存在付了钱但是订单没回来的情况
        #if DEBUG
         [self blockLogTransactionIdentifier:@"" desc:@"交易凭证为空 " info:@""];
        #endif
        [self handleActionWithType:SIAPPurchVerFailed data:nil key:@"" para:@""];
        return;
    }
     SIAPPurchType SIAPPurchState = transaction.transactionState == SKPaymentTransactionStatePurchased ? SIAPPurchSuccess : SIAPPurchRestored;
    if (!transaction.payment.applicationUsername){
        id para =  [[NSUserDefaults standardUserDefaults] objectForKey:transaction.payment.productIdentifier];
        if (para){
            [self handleActionWithType:SIAPPurchState data:receipt  key:transaction.transactionIdentifier para:para];
        }else{
            #if DEBUG
                [self blockLogTransactionIdentifier:transaction.transactionIdentifier desc:@"交易参数为空 " info:@""];
            #endif
            if (_para){
                 [self handleActionWithType:SIAPPurchState data:receipt  key:transaction.transactionIdentifier para:_para];
            }else{
                 [self finishTransaction:transaction];
            }
        }
       
    }else{
        [self handleActionWithType:SIAPPurchState data:receipt  key:transaction.transactionIdentifier para:transaction.payment.applicationUsername];
    }
    // 购买成功将交易凭证发送给服务端进行再次校验
//    [_map setObject:transaction forKey:transaction.transactionIdentifier];
    
}

#pragma mark - SKProductsRequestDelegate
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    NSArray *product = response.products;
    if([product count] <= 0){
#if DEBUG
        NSLog(@"--------------没有商品------------------");
        [self blockLogTransactionIdentifier:@"" desc:@"没有商品 " info:@""];
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

    [self blockLogTransactionIdentifier:@"" desc:@"订单生成 发送购买请求 " info:@""];
#endif

    NSString *productIdentifier = [p productIdentifier];
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:p];
    payment.applicationUsername = _para;
    [[NSUserDefaults standardUserDefaults] setObject:_para forKey:productIdentifier];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
   
}

-(void)willFinshProductIdentifier:(NSString *)productIdentifier{
     NSString *productIdentifierKey = [NSString stringWithFormat: @"%@willFinsh", productIdentifier];
      [[NSUserDefaults standardUserDefaults] setObject:@"1" forKey:productIdentifierKey];
}


-(void)finshProductIdentifier:(NSString *)productIdentifier{
     NSString *productIdentifierKey = [NSString stringWithFormat: @"%@willFinsh", productIdentifier];
    [[NSUserDefaults standardUserDefaults] setObject:@"0" forKey:productIdentifierKey];
    NSArray* transactions = [SKPaymentQueue defaultQueue].transactions;
      if (transactions.count > 0) {
          for (SKPaymentTransaction* transaction in transactions){
              if (!(transaction.transactionState == SKPaymentTransactionStatePurchased || transaction.transactionState == SKPaymentTransactionStateRestored) && transaction.payment.productIdentifier == productIdentifier){
                  [self finishTransaction:transaction];
              }
          }
      }
}

-(BOOL)getWillFinsh:(NSString *)productIdentifier{
    NSString *productIdentifierKey = [NSString stringWithFormat: @"%@willFinsh", productIdentifier];
    NSString *noFish = [[NSUserDefaults standardUserDefaults] objectForKey:productIdentifierKey];
    return ([@"1" isEqualToString:noFish]);
}


- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error{
      [self blockLogTransactionIdentifier:@"" desc:@"用户取消操作" info:@""];
      [[NSNotificationCenter defaultCenter] postNotificationName:@"showLondTip" object:@"用户取消操作"];
}

//请求失败
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"showLondTip" object:@"当前网络不给力,请稍后再试~"];
   #if DEBUG
        NSLog(@"------------------错误-----------------:%@", error);
       [self blockLogTransactionIdentifier:@"" desc:@"唤醒内购失败 " info:error.localizedDescription];
   #endif
    
}

- (void)requestDidFinish:(SKRequest *)request{
    #if DEBUG
      NSLog(@"------------------反馈信息结束-----------------");
     [self blockLogTransactionIdentifier:@"" desc:@"反馈信息结束" info:@""];
    #endif
}

#pragma mark - SKPaymentTransactionObserver

-(void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray<SKPaymentTransaction *> *)transactions{
    for (SKPaymentTransaction *tran in transactions) {
        if ([_willDelKey containsObject:tran.transactionIdentifier]){
            [_willDelKey removeObject:tran.transactionIdentifier];
        }
    }
}


- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions{
    #if DEBUG
    NSLog(@"--------------updatedTransactions------------------");
    [self blockLogTransactionIdentifier:@"" desc:[NSString stringWithFormat:@"商品出现更新,总数量%lu",(unsigned long)transactions.count] info:@""];
    #endif
    for (SKPaymentTransaction *tran in transactions) {
        switch (tran.transactionState) {
            case SKPaymentTransactionStatePurchased:
                [self verifyPurchaseWithPaymentTransaction:tran];
                #if DEBUG
                [self blockLogTransactionIdentifier:tran.transactionIdentifier desc:@"商品购买完成即将提交服务端校验" info:@""];
                #endif
                [self finshProductIdentifier:tran.payment.productIdentifier];
                isError = NO;
                break;
            case SKPaymentTransactionStatePurchasing:
                #if DEBUG
                [self blockLogTransactionIdentifier:tran.transactionIdentifier desc:@"商品添加进列表" info:@""];
                #endif
                [self willFinshProductIdentifier:tran.payment.productIdentifier];
                break;
            case SKPaymentTransactionStateRestored:
                #if DEBUG
                [self blockLogTransactionIdentifier:tran.transactionIdentifier desc:@"已经购买过商品" info:@""];
                #endif
                // 消耗型不支持恢复购买
                [[NSNotificationCenter defaultCenter] postNotificationName:@"showLonding" object:@"正在恢复"];
                 [self verifyPurchaseWithPaymentTransaction:tran];
                 [self finshProductIdentifier:tran.payment.productIdentifier];
                isError = NO;
                break;
            case SKPaymentTransactionStateFailed:
                #if DEBUG
                [self blockLogTransactionIdentifier:tran.transactionIdentifier desc:@"商品购买失败" info:tran.error.localizedDescription];
                #endif
                [self failedTransaction:tran];
                break;
            default:
                #if DEBUG
                [self blockLogTransactionIdentifier:tran.transactionIdentifier desc:@"商品出现未知状态" info:tran.error.localizedDescription];
                #endif
                break;
        }
    }
}


- (void)binLog:(IAPLogHandle)log{
    _log = log;
}

-(void)blockLogTransactionIdentifier:(NSString *)transactionIdentifier  desc:(NSString *)desc  info:(NSString *)info {
    if (_log){
        _log(transactionIdentifier,desc,info);
    }
}



- (void)dealloc{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

-(NSString*)dataTOjsonString:(id)object{
    NSString *jsonString = nil;
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:object
    options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
    error:&error];
    if (! jsonData) {
        NSLog(@"Got an error: %@", error);
    } else {
        jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    return jsonString;
}

- (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString
{
    if (jsonString == nil) {
        return nil;
    }

    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    if(err)
    {
        NSLog(@"json解析失败：%@",err);
        return nil;
    }
    return dic;
}


#pragma mark -  订单校验 前端测试用
- (void)testTransaction{

    NSURL *recepitURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:recepitURL];
    if (!receipt){
        return;
    }
    [self testTransactionData:receipt index:0];
}


- (void)testTransactionData:(NSData *)receipt index:(NSInteger)index{

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
                   NSLog(@"校验失败%ld",(long)index);
                   
               } else {
                   NSError *error;
                   NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                   if (!jsonResponse) {
                       // 苹果服务器校验数据返回为空校验失败
                       return ;
                   }
                   
                   // 先验证正式服务器,如果正式服务器返回21007再去苹果测试服务器验证,沙盒测试环境苹果用的是测试服务器
                   NSString *status = [NSString stringWithFormat:@"%@",jsonResponse[@"status"]];
                   if (status && [status isEqualToString:@"21007"]) {
                   
                       
                   }else if(status && [status isEqualToString:@"0"]){
                       
                   }
    #if DEBUG
                   NSLog(@"校验成功%ld",(long)index);
                   NSLog(@"----验证结果 %@",jsonResponse);
                 
    #endif
                   NSDictionary *receipt = [jsonResponse objectForKey:@"receipt"];
                   if (receipt){
                       NSArray *array =  [receipt objectForKey:@"in_app"];
                       if (array && array.count > 0){
                           NSDictionary *fistDic = array.firstObject;
                           if (fistDic){
                               //取到最后 一单的 transaction_id ，如果a看到这个一单没有 提交过，那么异常单中 的相同的
                               //product_id 对应的单应该是同一单，那么提交给 服务器
//                               NSString *product_id = [fistDic objectForKey:@"product_id"];
//                               NSString *transaction_id = [fistDic objectForKey:@"transaction_id"];
//                               NSArray* transactions = [SKPaymentQueue defaultQueue].transactions;
//                               NSLog(@"123");
                           }
                       }
                   }
               }
           }];
}

- (void)setErrorderHandle:(IAPErrorderHandle)handle{
    _errorhandle = handle;
}
@end
