import Result "mo:base/Result";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Time "mo:base/Time";
import HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Types "./types";
import Token "./token";

module {
  public class PoolManager(tokenManager: Token.TokenManager) {
    // 存储创建的池子
    private var pools = HashMap.HashMap<Text, Types.Pool>(20, Text.equal, Text.hash);
    
    // 创建池子的计数器（用于生成唯一ID）
    private var poolCounter : Nat = 0;
    
    // 所有池子ID的列表
    private var allPoolIds = Buffer.Buffer<Text>(20);
    
    // 开发者地址
    private let developerAddress : Text = "uu7pn-d75f5-wbol7-bgm3r-eyxl7-rslak-deudv-2o5e6-5iwbc-xv3im-jqe";

    // 创建新的游戏池
    public func createPool(
      creator: Text,
      tokenLedger: Text,
      winnerCount: Nat,
      betAmount: Nat,
      initialAmount: Nat
    ) : Result.Result<Text, Text> {
      // 验证代币是否存在
      let tokenOpt = tokenManager.getToken(tokenLedger);
      
      switch (tokenOpt) {
        case (null) {
          return #err("代币不存在");
        };
        case (?token) {
          // 先验证下注金额
          if (not tokenManager.validateBetAmount(token, betAmount)) {
            let minBet = tokenManager.calculateMinimumBet(token);
            return #err("下注金额必须大于等于最小下注额度: " # Nat.toText(minBet));
          };
          
          // 再验证初始投入金额
          let minimumInitialAmount = winnerCount * betAmount;
          
          if (initialAmount < minimumInitialAmount) {
            return #err("初始投入金额不足，最低需要：" # Nat.toText(minimumInitialAmount) # "（人数 * 下注金额）");
          };
          
          // 创建池子ID
          poolCounter += 1;
          let poolId = Nat.toText(poolCounter);
          
          // 创建新池子
          let newPool : Types.Pool = {
            id = poolId;
            creator = creator;
            token = token;
            totalAmount = initialAmount;
            initialAmount = initialAmount;
            betAmount = betAmount;
            winnerCount = winnerCount;
            status = #Pending;
            createdAt = Time.now();
            lastBetTime = ?Time.now();
            bets = [];
          };
          
          // 存储池子
          pools.put(poolId, newPool);
          allPoolIds.add(poolId);
          
          #ok(poolId)
        };
      }
    };
    
    // 获取池子信息
    public func getPool(poolId: Text) : ?Types.Pool {
      pools.get(poolId)
    };
    
    // 获取活跃池子（支持分页）
    public func getActivePools(offset: Nat, limit: ?Nat) : [Types.Pool] {
      let activePools = Buffer.Buffer<Types.Pool>(20);
      
      // 收集所有活跃池子
      for (id in allPoolIds.vals()) {
        switch (pools.get(id)) {
          case (?pool) {
            switch (pool.status) {
              case (#Active) {
                activePools.add(pool);
              };
              case (_) {};
            };
          };
          case (_) {};
        };
      };
      
      // 处理分页逻辑
      let totalPools = activePools.size();
      
      // 如果偏移量超出总数，返回空数组
      if (offset >= totalPools) {
        return [];
      };
      
      // 确定实际limit值
      let actualLimit = switch (limit) {
        case (null) { 10 }; // 默认每页10个
        case (?l) { if (l > 10) { 10 } else { l } }; // 最多返回10个
      };
      
      // 计算结束索引
      let endIndex = Nat.min(offset + actualLimit, totalPools);
      
      // 提取指定范围的池子
      let resultBuffer = Buffer.Buffer<Types.Pool>(actualLimit);
      var currentIndex = offset;
      
      while (currentIndex < endIndex) {
        resultBuffer.add(activePools.get(currentIndex));
        currentIndex += 1;
      };
      
      Buffer.toArray(resultBuffer)
    };
    
    // 下注操作
    public func placeBet(poolId: Text, user: Text, amount: Nat) : Result.Result<(), Text> {
      // 检查池子是否存在
      switch (pools.get(poolId)) {
        case (null) {
          return #err("池子不存在");
        };
        case (?pool) {
          if (pool.status != #Active) {
            return #err("池子状态不是活跃的，无法下注");
          };
          
          // 检查池子是否应该结算（倒计时是否已结束）
          switch (pool.lastBetTime) {
            case (null) {
              return #err("池子倒计时未初始化");
            };
            case (?lastBetTime) {
              let currentTime = Time.now();
              let timeDiff = currentTime - lastBetTime;
              
              // 检查是否超过60秒
              if (timeDiff > 60_000_000_000) {
                return #err("池子倒计时已结束，无法下注");
              };
            };
          };
          
          // 验证金额是否等于池子设置的下注金额
          if (amount != pool.betAmount) {
            return #err("下注金额必须等于池子设置的下注金额: " # Nat.toText(pool.betAmount));
          };
          
          // 创建新的下注记录
          let bet : Types.Bet = {
            user = user;
            amount = amount;
            timestamp = Time.now();
          };
          
          // 更新池子信息
          let updatedBets = Array.append<Types.Bet>(pool.bets, [bet]);
          let updatedPool : Types.Pool = {
            id = pool.id;
            creator = pool.creator;
            token = pool.token;
            totalAmount = Nat.add(pool.totalAmount, amount);
            initialAmount = pool.initialAmount;
            betAmount = pool.betAmount;
            winnerCount = pool.winnerCount;
            status = pool.status;
            createdAt = pool.createdAt;
            lastBetTime = ?Time.now();
            bets = updatedBets;
          };
          
          // 保存更新
          pools.put(poolId, updatedPool);
          
          #ok(())
        };
      }
    };
    
   
    // 检查池子是否应该结算（60秒无人下注）
    public func shouldSettlePool(poolId: Text) : Bool {
      switch (pools.get(poolId)) {
        case (null) {
          return false;
        };
        case (?pool) {
          if (pool.status != #Active) {
            return false;
          };
          
          switch (pool.lastBetTime) {
            case (null) {
              return false;
            };
            case (?lastBetTime) {
              let currentTime = Time.now();
              let timeDiff = currentTime - lastBetTime;
              
              // 60秒转换为纳秒
              return timeDiff > 60_000_000_000;
            };
          };
        };
      }
    };
    
    // 结算池子
    public func settlePool(poolId: Text) : async Result.Result<(), Text> {
      // 检查池子是否存在
      switch (pools.get(poolId)) {
        case (null) {
          return #err("池子不存在");
        };
        case (?pool) {
          // 严格检查状态，只有Active状态的池子才能被结算
          if (pool.status != #Active) {
            // 如果已经在结算中或已结算完成，返回错误
            switch (pool.status) {
              case (#Settling) { 
                return #err("池子正在结算中，请等待"); 
              };
              case (#Completed) { 
                return #err("池子已经完成结算"); 
              };
              case (#Canceled) { 
                return #err("池子已取消"); 
              };
              case (_) { 
                return #err("池子状态不是活跃的，无法结算"); 
              };
            };
          };
          
          // 立即将状态更新为正在结算，防止并发结算
          let settlingPool : Types.Pool = {
            id = pool.id;
            creator = pool.creator;
            token = pool.token;
            totalAmount = pool.totalAmount;
            initialAmount = pool.initialAmount;
            betAmount = pool.betAmount;
            winnerCount = pool.winnerCount;
            status = #Settling; // 更改为结算中状态
            createdAt = pool.createdAt;
            lastBetTime = pool.lastBetTime;
            bets = pool.bets;
          };
          
          // 立即保存状态变更
          pools.put(poolId, settlingPool);
          
          if (Array.size(pool.bets) == 0) {
            // 无人下注，返还初始资金给创建者
            let result = await tokenManager.transferToken(
              pool.token.ledger,
              pool.creator,
              pool.initialAmount
            );
            
            switch (result) {
              case (#err(e)) {
                // 结算失败，恢复为活跃状态
                let activePool : Types.Pool = {
                  id = pool.id;
                  creator = pool.creator;
                  token = pool.token;
                  totalAmount = pool.totalAmount;
                  initialAmount = pool.initialAmount;
                  betAmount = pool.betAmount;
                  winnerCount = pool.winnerCount;
                  status = #Active; // 恢复为活跃状态
                  createdAt = pool.createdAt;
                  lastBetTime = pool.lastBetTime;
                  bets = pool.bets;
                };
                pools.put(poolId, activePool);
                return #err("返还初始资金失败: " # e);
              };
              case (#ok(_)) {
                // 更新池子状态为已取消
                let canceledPool : Types.Pool = {
                  id = pool.id;
                  creator = pool.creator;
                  token = pool.token;
                  totalAmount = 0;
                  initialAmount = pool.initialAmount;
                  betAmount = pool.betAmount;
                  winnerCount = pool.winnerCount;
                  status = #Canceled;
                  createdAt = pool.createdAt;
                  lastBetTime = pool.lastBetTime;
                  bets = pool.bets;
                };
                
                pools.put(poolId, canceledPool);
                return #ok(());
              };
            };
          } else {
            // 有下注，进行奖金分配
            let totalAmount = pool.totalAmount;
            
            // 获取最后N个下注（N=winnerCount）
            let betCount = Array.size(pool.bets);
            let startIndex = if (betCount > pool.winnerCount) { 
              Nat.sub(betCount, pool.winnerCount)
            } else { 
              0 
            };
            let winningBets = Array.subArray(pool.bets, startIndex, Nat.min(pool.winnerCount, betCount));
            let actualWinnerCount = Array.size(winningBets);
            
            // 1. 先计算并扣除所有网络费用
            let totalNetworkFee = pool.token.fee * (actualWinnerCount + 2); // 获奖者 + 创建者 + 开发者的网络费
            
            // 确保总金额足够支付网络费
            if (totalAmount <= totalNetworkFee) {
              // 结算失败，恢复为活跃状态
              let activePool : Types.Pool = {
                id = pool.id;
                creator = pool.creator;
                token = pool.token;
                totalAmount = pool.totalAmount;
                initialAmount = pool.initialAmount;
                betAmount = pool.betAmount;
                winnerCount = pool.winnerCount;
                status = #Active; // 恢复为活跃状态
                createdAt = pool.createdAt;
                lastBetTime = pool.lastBetTime;
                bets = pool.bets;
              };
              pools.put(poolId, activePool);
              return #err("池子总金额不足以支付所有网络费");
            };
            
            // 扣除网络费后的实际可分配金额
            let distributableAmount = Nat.sub(totalAmount, totalNetworkFee);
            
            // 2. 计算创建者、开发者和获奖者的分成
            let creatorFee = Nat.div(distributableAmount, 100); // 1%
            let developerFee = Nat.div(distributableAmount, 100); // 1%
            let winnerAmount = Nat.sub(distributableAmount, Nat.add(creatorFee, developerFee)); // 98%
            
            // 计算每位获奖者应得金额
            let amountPerWinner = Nat.div(winnerAmount, actualWinnerCount);
            
            // 执行转账
            // 1. 转给创建者
            let creatorResult = await tokenManager.transferToken(
              pool.token.ledger,
              pool.creator,
              creatorFee
            );
            
            switch (creatorResult) {
              case (#err(e)) {
                // 结算失败，恢复为活跃状态
                let activePool : Types.Pool = {
                  id = pool.id;
                  creator = pool.creator;
                  token = pool.token;
                  totalAmount = pool.totalAmount;
                  initialAmount = pool.initialAmount;
                  betAmount = pool.betAmount;
                  winnerCount = pool.winnerCount;
                  status = #Active; // 恢复为活跃状态
                  createdAt = pool.createdAt;
                  lastBetTime = pool.lastBetTime;
                  bets = pool.bets;
                };
                pools.put(poolId, activePool);
                return #err("转账给创建者失败: " # e);
              };
              case (#ok(_)) {
                // 继续处理
              };
            };
            
            // 2. 转给开发者
            let devResult = await tokenManager.transferToken(
              pool.token.ledger,
              developerAddress,
              developerFee
            );
            
            switch (devResult) {
              case (#err(e)) {
                // 结算失败，恢复为活跃状态
                let activePool : Types.Pool = {
                  id = pool.id;
                  creator = pool.creator;
                  token = pool.token;
                  totalAmount = pool.totalAmount;
                  initialAmount = pool.initialAmount;
                  betAmount = pool.betAmount;
                  winnerCount = pool.winnerCount;
                  status = #Active; // 恢复为活跃状态
                  createdAt = pool.createdAt;
                  lastBetTime = pool.lastBetTime;
                  bets = pool.bets;
                };
                pools.put(poolId, activePool);
                return #err("转账给开发者失败: " # e);
              };
              case (#ok(_)) {
                // 继续处理
              };
            };
            
            // 3. 转给所有获奖者
            var transferFailed = false;
            var failureMessage = "";
            
            for (bet in winningBets.vals()) {
              let winnerResult = await tokenManager.transferToken(
                pool.token.ledger,
                bet.user,
                amountPerWinner
              );
              
              switch (winnerResult) {
                case (#err(e)) {
                  // 如果转账失败，记录但继续处理下一个
                  transferFailed := true;
                  failureMessage := failureMessage # "转账给获奖者 " # bet.user # " 失败: " # e # "; ";
                  Debug.print("转账给获奖者 " # bet.user # " 失败: " # e);
                };
                case (#ok(_)) {
                  // 转账成功，继续处理
                };
              };
            };
            
            if (transferFailed) {
              // 虽然有失败，但我们仍然完成结算，因为部分转账已经成功
              // 可以根据需要选择不同的策略，这里选择继续完成结算
              Debug.print("部分获奖者转账失败，但结算继续: " # failureMessage);
            };
            
            // 更新池子状态为已完成
            let completedPool : Types.Pool = {
              id = pool.id;
              creator = pool.creator;
              token = pool.token;
              totalAmount = 0; // 已分配完
              initialAmount = pool.initialAmount;
              betAmount = pool.betAmount;
              winnerCount = pool.winnerCount;
              status = #Completed;
              createdAt = pool.createdAt;
              lastBetTime = pool.lastBetTime;
              bets = pool.bets;
            };
            
            pools.put(poolId, completedPool);
            return #ok(());
          };
        };
      }
    };
    
    // 激活池子（验证初始资金后）
    public func activatePool(poolId: Text) : Result.Result<(), Text> {
      switch (pools.get(poolId)) {
        case (null) {
          return #err("池子不存在");
        };
        case (?pool) {
          if (pool.status != #Pending) {
            return #err("池子状态不是待激活");
          };
          
          // 更新池子状态为激活
          let activatedPool : Types.Pool = {
            id = pool.id;
            creator = pool.creator;
            token = pool.token;
            totalAmount = pool.totalAmount;
            initialAmount = pool.initialAmount;
            betAmount = pool.betAmount;
            winnerCount = pool.winnerCount;
            status = #Active;
            createdAt = pool.createdAt;
            lastBetTime = ?Time.now(); // 重置倒计时
            bets = pool.bets;
          };
          
          pools.put(poolId, activatedPool);
          return #ok(());
        };
      }
    };
    
    // 获取所有池子
    public func getAllPools() : [Types.Pool] {
      let allPools = Buffer.Buffer<Types.Pool>(allPoolIds.size());
      for (id in allPoolIds.vals()) {
        switch (pools.get(id)) {
          case (?pool) {
            allPools.add(pool);
          };
          case (_) {};
        };
      };
      Buffer.toArray(allPools)
    };
    
    // 检查并清理所有应该结算的池子
    public func checkAndSettlePools() : async () {
      for (id in allPoolIds.vals()) {
        switch (pools.get(id)) {
          case (?pool) {
            // 只检查状态为Active的池子
            if (pool.status == #Active and shouldSettlePool(id)) {
              ignore await settlePool(id);
            };
          };
          case (_) {};
        };
      };
    };
  };
} 