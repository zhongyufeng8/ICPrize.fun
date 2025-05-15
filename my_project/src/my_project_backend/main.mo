import Result "mo:base/Result";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Option "mo:base/Option";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Int "mo:base/Int";
import Nat64 "mo:base/Nat64";
import Error "mo:base/Error";
import Debug "mo:base/Debug";
import Cycles "mo:base/ExperimentalCycles";
import Iter "mo:base/Iter";

import Types "./types";
import Token "./token";
import Pool "./pool";
import Message "./message";
import ICP "./icp";
import ICRC1 "./icrc1";

actor PlayerX {
  // 定义更具体的区块类型
  type BlockData = {
    #Map : [(Text, BlockValue)];
  };

  type BlockValue = {
    #Nat64 : Nat64;
    #Text : Text;
    #Blob : Blob;
    #Array : [BlockValue];
    #Map : [(Text, BlockValue)];
  };

  // 初始化各个管理器
  private let tokenManager = Token.TokenManager();
  private let poolManager = Pool.PoolManager(tokenManager);
  private let messageManager = Message.MessageManager();
  
  // 记录用户最后一次查询消息的时间
  private var lastMessageCheck = HashMap.HashMap<Text, Time.Time>(20, Text.equal, Text.hash);
  
  // 记录已使用的转账
  private var usedTransfers = HashMap.HashMap<Text, Time.Time>(100, Text.equal, Text.hash);
  
  // =================== 代币管理接口 ===================
  
  // 添加代币
  public func addToken(ledger: Text) : async Result.Result<Types.TokenInfo, Text> {
    await tokenManager.addToken(ledger)
  };
  
  // 获取代币信息
  public query func getToken(ledger: Text) : async ?Types.TokenInfo {
    tokenManager.getToken(ledger)
  };
  
  // 获取所有代币
  public query func getAllTokens() : async [Types.TokenInfo] {
    tokenManager.getAllTokens()
  };
  
  // 获取所有代币符号
  public query func getAllTokenSymbols() : async [Text] {
    let tokens = tokenManager.getAllTokens();
    Array.map<Types.TokenInfo, Text>(tokens, func (token) { token.symbol })
  };
  
  // 获取代币的最小下注金额
  public query func getMinimumBet(ledger: Text) : async ?Nat {
    switch (tokenManager.getToken(ledger)) {
      case (null) { null };
      case (?token) { ?tokenManager.calculateMinimumBet(token) };
    }
  };
  
  // =================== 池子管理接口 ===================
  
  // 创建池子
  public shared(msg) func createPool(
    tokenSymbol: Text,
    winnerCount: Nat,
    betAmount: Nat,
    initialAmount: Nat
  ) : async Result.Result<Text, Text> {
    // 从调用者信息中获取创建者地址
    let creator = Principal.toText(msg.caller);
    
    // 通过符号查找代币
    let tokenOpt = await findTokenBySymbol(tokenSymbol);
    
    switch (tokenOpt) {
      case (null) {
        return #err("代币符号不存在，请先添加代币");
      };
      case (?token) {
        // 检查之前的池子，结算已到期的
        await poolManager.checkAndSettlePools();
        
        // 创建新池子
        let result = poolManager.createPool(creator, token.ledger, winnerCount, betAmount, initialAmount);
        
        // 如果创建成功，生成更友好的池子ID格式
        switch (result) {
          case (#err(e)) {
            return #err(e);
          };
          case (#ok(poolId)) {
            // 返回友好格式的池子ID
            return #ok(token.symbol # poolId);
          };
        };
      };
    }
  };
  
  // 验证初始资金并激活池子
  public shared(msg) func verifyInitialFundAndActivatePool(poolId: Text, blockIndex: Nat) : async Result.Result<(), Text> {
    // 从调用者信息中获取创建者地址
    let user = Principal.toText(msg.caller);
    
    // 获取池子信息
    switch (poolManager.getPool(poolId)) {
      case (null) {
        return #err("池子不存在");
      };
      case (?pool) {
        // 池子状态检查
        if (pool.status != #Pending) {
          return #err("池子状态不是待激活");
        };
        
        // 创建者身份验证
        if (Text.notEqual(user, pool.creator)) {
          return #err("只有创建者可以激活池子");
        };
        
        // 获取代币信息
        switch (tokenManager.getToken(pool.token.ledger)) {
          case (null) {
            return #err("代币信息不存在");
          };
          case (?token) {
            // 检查交易是否已使用
            if (Option.isSome(usedTransfers.get(user # Nat.toText(blockIndex)))) {
              return #err("该笔转账已被使用，请重新转账并验证");
            };
            
            try {
              // 根据代币类型选择不同的验证方式
              var verificationSuccess = false;
              var transactionAmount : Nat = 0;
              var transactionMemo : Text = "";
              
              // 判断是ICP还是其他ICRC1代币
              if (Text.equal(token.symbol, "ICP")) {
                // 使用ICP模块验证交易
                let verificationResult = await ICP.verifyTransaction(Nat64.fromNat(blockIndex));
                Debug.print("ICP交易验证结果: " # verificationResult);
                
                // 检查验证是否成功
                if (Text.contains(verificationResult, #text("交易验证成功"))) {
                  verificationSuccess := true;
                  
                  // 假设验证成功时，可以从结果中提取金额和备注
                  // 这里使用硬编码的方式，前端应该已经验证过这些信息
                  transactionAmount := pool.initialAmount; // 简化处理，假设金额足够
                  transactionMemo := Text.replace(poolId, #text(token.symbol), ""); // 直接用内部池子ID
                } else {
                  return #err("ICP交易验证失败: " # verificationResult);
                };
              } else {
                // 使用ICRC1模块验证交易
                let verificationResult = await ICRC1.verifyICRC1Transaction(pool.token.ledger, blockIndex);
                Debug.print("ICRC1交易验证结果: " # verificationResult);
                
                // 检查验证是否成功
                if (Text.contains(verificationResult, #text("ICRC-1 交易验证成功"))) {
                  verificationSuccess := true;
                  
                  // 假设验证成功时，可以从结果中提取金额和备注
                  // 这里使用硬编码的方式，前端应该已经验证过这些信息
                  transactionAmount := pool.initialAmount; // 简化处理，假设金额足够
                  transactionMemo := Text.replace(poolId, #text(token.symbol), ""); // 直接用内部池子ID
                } else {
                  return #err("ICRC1交易验证失败: " # verificationResult);
                };
              };
              
              // 验证成功后才进行后续处理
              if (verificationSuccess) {
                // 验证金额是否足够
                if (transactionAmount < pool.initialAmount) {
                  return #err("转账金额小于池子所需初始资金：实际 " # Nat.toText(transactionAmount) # " < 要求 " # Nat.toText(pool.initialAmount));
                };
                
                // 验证备注是否匹配
                let internalPoolId = Text.replace(poolId, #text(token.symbol), "");
                if (Text.notEqual(transactionMemo, internalPoolId)) {
                  return #err("转账备注与池子内部ID不匹配,预期：" # internalPoolId # "，实际：" # transactionMemo);
                };
                
                // 所有验证通过，记录转账使用记录
                usedTransfers.put(user # Nat.toText(blockIndex), Time.now());
                
                // 激活池子
                Debug.print("验证通过，即将激活池子：" # pool.id);
                return poolManager.activatePool(pool.id);
              } else {
                return #err("交易验证失败");
              };
            } catch (error) {
              return #err("验证过程中发生错误: " # Error.message(error));
            };
          };
        };
      };
    }
  };
  

  // 通过符号查找代币
  public query func findTokenBySymbol(symbol: Text) : async ?Types.TokenInfo {
    let tokens = tokenManager.getAllTokens();
    for (token in tokens.vals()) {
      if (Text.equal(token.symbol, symbol)) {
        return ?token;
      };
    };
    null
  };
  
  // 获取池子信息
  public query func getPool(poolId: Text) : async ?Types.Pool {
    poolManager.getPool(poolId)
  };
  
  // 获取活跃池子（支持分页）
  public query func getActivePools(offset: Nat, limit: ?Nat) : async [Types.Pool] {
    poolManager.getActivePools(offset, limit)
  };
  
  // 下注验证
  public shared(msg) func placeBet(poolId: Text, blockIndex: Nat) : async Result.Result<(), Text> {
    // 从调用者信息中获取用户地址
    let user = Principal.toText(msg.caller);
    
    // 获取池子信息
    switch (poolManager.getPool(poolId)) {
      case (null) {
        return #err("池子不存在");
      };
      case (?pool) {
        // 检查池子状态
        if (pool.status != #Active) {
          return #err("池子已结束，无法投注");
        };
        
        // 获取代币信息
        switch (tokenManager.getToken(pool.token.ledger)) {
          case (null) {
            return #err("代币信息不存在");
          };
          case (?token) {
            // 检查交易是否已使用
            if (Option.isSome(usedTransfers.get(user # Nat.toText(blockIndex)))) {
              return #err("该笔转账已被使用，请重新转账");
            };
            
            try {
              // 根据代币类型选择不同的验证方式
              var verificationSuccess = false;
              var transactionAmount : Nat = 0;
              var transactionMemo : Text = "";
              
              // 判断是ICP还是其他ICRC1代币
              if (Text.equal(token.symbol, "ICP")) {
                // 使用ICP模块验证交易
                let verificationResult = await ICP.verifyTransaction(Nat64.fromNat(blockIndex));
                Debug.print("ICP交易验证结果: " # verificationResult);
                
                // 检查验证是否成功
                if (Text.contains(verificationResult, #text("交易验证成功"))) {
                  verificationSuccess := true;
                  transactionAmount := pool.betAmount; // 使用池子设置的下注金额
                  transactionMemo := poolId; // 使用池子ID作为备注
                } else {
                  return #err("ICP交易验证失败: " # verificationResult);
                };
              } else {
                // 使用ICRC1模块验证交易
                let verificationResult = await ICRC1.verifyICRC1Transaction(pool.token.ledger, blockIndex);
                Debug.print("ICRC1交易验证结果: " # verificationResult);
                
                // 检查验证是否成功
                if (Text.contains(verificationResult, #text("ICRC-1 交易验证成功"))) {
                  verificationSuccess := true;
                  transactionAmount := pool.betAmount; // 使用池子设置的下注金额
                  transactionMemo := poolId; // 使用池子ID作为备注
                } else {
                  return #err("ICRC1交易验证失败: " # verificationResult);
                };
              };
              
              // 验证成功后才进行后续处理
              if (verificationSuccess) {
                // 验证金额是否匹配
                if (transactionAmount != pool.betAmount) {
                  return #err("转账金额与池子设置的下注金额不匹配：实际 " # Nat.toText(transactionAmount) # " != 要求 " # Nat.toText(pool.betAmount));
                };
                
                // 验证备注是否匹配
                if (Text.notEqual(transactionMemo, poolId)) {
                  return #err("转账备注与池子ID不匹预期：" # poolId # "，实际：" # transactionMemo);
                };
                
                // 所有验证通过，记录转账使用记录
                usedTransfers.put(user # Nat.toText(blockIndex), Time.now());
                
                // 下注
                let result = poolManager.placeBet(pool.id, user, pool.betAmount);
                // 如果下注成功，异步检查其他池子
                if (Result.isOk(result)) {
                  ignore async { await poolManager.checkAndSettlePools() };
                };
                return result;
              } else {
                return #err("交易验证失败");
              };
            } catch (error) {
              return #err("处理区块信息时出错: " # Error.message(error));
            };
          };
        };
      };
    }
  };
  
  // 手动结算池子（如果满足条件）
  public func settlePool(poolId: Text) : async Result.Result<(), Text> {
    if (poolManager.shouldSettlePool(poolId)) {
      await poolManager.settlePool(poolId)
    } else {
      #err("池子不满足结算条件")
    }
  };
  
  // 获取倒计时（返回剩余纳秒数）
  public query func getCountdown(poolId: Text) : async ?Int {
    switch (poolManager.getPool(poolId)) {
      case (null) {
        null
      };
      case (?pool) {
        if (pool.status != #Active) {
          return ?0; // 已完成或取消
        };
        
        switch (pool.lastBetTime) {
          case (null) {
            null
          };
          case (?lastBetTime) {
            let currentTime = Time.now();
            let elapsed = currentTime - lastBetTime;
            let timeout = 60_000_000_000; // 60秒（纳秒）
            
            if (elapsed >= timeout) {
              ?0 // 已超时
            } else {
              ?(timeout - elapsed) // 剩余时间
            }
          };
        }
      };
    }
  };
  
  // =================== 消息接口 ===================
  
  // 发送消息
  public shared(msg) func sendMessage(content: Text) : async () {
    let sender = Principal.toText(msg.caller);
    messageManager.sendMessage(sender, content)
  };
  
  // 获取最新消息
  public query func getLatestMessages(count: Nat) : async [Types.Message] {
    messageManager.getLatestMessages(count)
  };
  
  // 检查是否有新消息
  public shared query(msg) func hasNewMessages() : async Bool {
    let user = Principal.toText(msg.caller);
    let lastCheck = switch (lastMessageCheck.get(user)) {
      case (null) { 0 };
      case (?time) { time };
    };
    
    messageManager.hasNewMessages(lastCheck)
  };
  
  // 更新用户最后查询消息的时间
  public shared(msg) func updateLastMessageCheck() : async () {
    let user = Principal.toText(msg.caller);
    lastMessageCheck.put(user, Time.now());
  };
  
  // =================== ICRC-1 转账 ===================
  
  // 转账函数
  public func transferToken(ledger: Text, to: Text, amount: Nat) : async Types.TransferResult {
    await tokenManager.transferToken(ledger, to, amount)
  };
  
  // =================== 系统信息 ===================
  
   
  // 查询系统周期信息
  public query func getSystemCycleInfo() : async {
    activePools: Nat;
    pendingPools: Nat;
    completedPools: Nat;
    totalBets: Nat;
    currentTime: Time.Time;
    avgBetAmount: ?Nat;
    tokenCount: Nat;
  } {
    let pools = poolManager.getAllPools();
    var activePools : Nat = 0;
    var pendingPools : Nat = 0;
    var completedPools : Nat = 0;
    var totalBets : Nat = 0;
    var totalBetAmount : Nat = 0;
    
    for (pool in pools.vals()) {
      switch (pool.status) {
        case (#Active) { activePools += 1; };
        case (#Pending) { pendingPools += 1; };
        case (#Completed) { completedPools += 1; };
        case (#Canceled) { /* 已取消的不计入统计 */ };
        case (#Settling) { activePools += 1; }; // 结算中的池子计入活跃池子
      };
      
      // 计算下注数量和金额
      let betCount = Array.size(pool.bets);
      totalBets += betCount;
      
      for (bet in pool.bets.vals()) {
        totalBetAmount += bet.amount;
      };
    };
    
    // 计算平均下注金额
    let avgBetAmount = if (totalBets > 0) { ?Nat.div(totalBetAmount, totalBets) } else { null };
    
    // 获取代币数量
    let tokenCount = Array.size(tokenManager.getAllTokens());
    
    return {
      activePools = activePools;
      pendingPools = pendingPools;
      completedPools = completedPools;
      totalBets = totalBets;
      currentTime = Time.now();
      avgBetAmount = avgBetAmount;
      tokenCount = tokenCount;
    };
  };

 //查询当前周期余额
  public query func checkBalance() : async Nat {
    return Cycles.balance();
  };
  
  // 查询用户在池子中的获奖排名
  public query func getUserPoolRank(poolId: Text, userAddress: Text) : async ?Nat {
    switch (poolManager.getPool(poolId)) {
      case (null) { null }; // 池子不存在
      case (?pool) {
        // 检查池子状态，只有已完成的池子才有确定的获奖名单
        if (pool.status != #Completed) {
          // 如果池子仍在活跃中，可以查看用户当前的潜在排名
          if (pool.status == #Active or pool.status == #Settling) {
            let betCount = Array.size(pool.bets);
            if (betCount == 0) { return null }; // 没有下注记录
            
            // 计算潜在获奖区间的起始索引
            let startIndex = if (betCount > pool.winnerCount) { 
              Nat.sub(betCount, pool.winnerCount)
            } else { 
              0 
            };
            
            // 查找用户当前的排名
            var currentRank : Nat = 1;
            for (i in Iter.range(startIndex, betCount - 1)) {
              if (i < Array.size(pool.bets)) {
                let bet = pool.bets[i];
                if (Text.equal(bet.user, userAddress)) {
                  return ?currentRank;
                };
                currentRank += 1;
              };
            };
            return null; // 用户不在潜在获奖区间内
          } else {
            return null; // 池子状态不是活跃或已完成
          };
        } else {
          // 池子已完成，获取获奖区间
          let betCount = Array.size(pool.bets);
          if (betCount == 0) { return null }; // 没有下注记录
          
          // 计算获奖区间的起始索引
          let startIndex = if (betCount > pool.winnerCount) { 
            Nat.sub(betCount, pool.winnerCount)
          } else { 
            0 
          };
          
          // 查找用户在获奖名单中的排名
          var currentRank : Nat = 1;
          for (i in Iter.range(startIndex, betCount - 1)) {
            if (i < Array.size(pool.bets)) {
              let bet = pool.bets[i];
              if (Text.equal(bet.user, userAddress)) {
                return ?currentRank;
              };
              currentRank += 1;
            };
          };
          return null; // 用户不在获奖名单中
        };
      };
    };
  };
}
