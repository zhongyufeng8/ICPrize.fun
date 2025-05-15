import Time "mo:base/Time";
import Result "mo:base/Result";
import Principal "mo:base/Principal";

module {
  // 代币信息
  public type TokenInfo = {
    ledger: Text;         // 账本地址
    symbol: Text;         // 代币符号
    decimals: Nat8;       // 小数位
    fee: Nat;             // 网络费用
    logo: ?Text;          // 代币logo元数据
    supportsBlockQuery: Bool; // 是否支持区块查询
  };

  // 查询区块的请求参数
  public type BlocksRequest = {
    start: Nat;
    length: Nat;
  };

  // 池子状态
  public type PoolStatus = {
    #Pending;             // 待激活（等待初始资金验证）
    #Active;              // 活跃中
    #Settling;            // 结算中
    #Completed;           // 已完成
    #Canceled;            // 已取消
  };

  // 下注信息
  public type Bet = {
    user: Text;           // 用户地址
    amount: Nat;          // 下注金额
    timestamp: Time.Time; // 下注时间
  };

  // 池子信息
  public type Pool = {
    id: Text;             // 池子ID
    creator: Text;        // 创建者地址
    token: TokenInfo;     // 代币信息
    totalAmount: Nat;     // 总奖池金额
    initialAmount: Nat;   // 初始投入金额
    betAmount: Nat;       // 下注金额
    winnerCount: Nat;     // 分奖人数
    status: PoolStatus;   // 池子状态
    createdAt: Time.Time; // 创建时间
    lastBetTime: ?Time.Time; // 最后一次下注时间
    bets: [Bet];          // 下注记录
  };

  // 消息类型
  public type Message = {
    sender: Text;         // 发送者
    content: Text;        // 消息内容
    timestamp: Time.Time; // 发送时间
  };

  // 转账参数
  public type TransferArgs = {
    to: Text;             // 接收地址
    amount: Nat;          // 转账金额
  };

  // 转账结果
  public type TransferResult = Result.Result<Nat, Text>;

  // 转账用途
  public type TransferPurpose = {
    #CreatePool : Text;    // 创建池子，包含池子ID
    #PlaceBet : Text;      // 投注，包含池子ID
    #Other;                // 其他用途
  };

  // 转账记录
  public type Transfer = {
    from: Text;           // 发送者地址
    to: Text;            // 接收者地址
    amount: Nat;         // 转账金额
    timestamp: Time.Time; // 转账时间
    memo: ?Blob;         // 转账备注（用于标识用途）
    purpose: TransferPurpose; // 转账用途
  };

  // 转账验证结果
  public type TransferValidation = {
    #Valid;              // 验证通过
    #Invalid : Text;     // 验证失败，包含错误信息
    #Expired;            // 转账已过期
    #Used;               // 转账已被使用
  };

  // ICRC-1 标准接口类型
  public type Account = {
    owner: Principal;
    subaccount: ?Blob;
  };

  public type ICRC1TransferArgs = {
    from_subaccount: ?Blob;    // 发送者子账户
    to: Account;               // 接收者地址（修正为标准格式）
    amount: Nat;              // 转账金额
    fee: ?Nat;                // 可选的手续费
    memo: ?Blob;              // 可选的备注
    created_at_time: ?Nat64;  // 可选的时间戳
  };

  public type ICRC1TransferResult = {
    #Ok: Nat;                // 成功，返回区块高度
    #Err: ICRC1TransferError; // 失败，返回错误信息
  };

  public type ICRC1TransferError = {
    #BadFee: { expected_fee: Nat };           // 手续费错误
    #BadBurn: { min_burn_amount: Nat };       // 销毁金额错误
    #InsufficientFunds: { balance: Nat };     // 余额不足
    #TooOld;                                  // 交易太旧
    #CreatedInFuture: { ledger_time: Nat64 }; // 未来时间
    #Duplicate: { duplicate_of: Nat };        // 重复交易
    #TemporarilyUnavailable;                  // 暂时不可用
    #GenericError: { error_code: Nat; message: Text }; // 通用错误
  };
} 