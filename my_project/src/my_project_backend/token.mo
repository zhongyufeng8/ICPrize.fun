import Result "mo:base/Result";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Error "mo:base/Error";
import Types "./types";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Bool "mo:base/Bool";

module {
  public class TokenManager() {
    // 存储已添加的代币
    private var tokens = HashMap.HashMap<Text, Types.TokenInfo>(10, Text.equal, Text.hash);
    
    // 添加新代币
    public func addToken(ledger: Text) : async Result.Result<Types.TokenInfo, Text> {
      if (Option.isSome(tokens.get(ledger))) {
        return #err("代币已经存在");
      };
      
      // 首先检查是否支持区块查询
      let supportsBlockQuery = try {
        await checkSupportsBlockQuery(ledger)
      } catch (e) {
        return #err("检查区块查询支持失败: " # Error.message(e));
      };
      
      if (not supportsBlockQuery) {
        return #err("该代币不支持区块查询，无法添加");
      };
      
      // 从主网查询代币元数据
      try {
        let symbol = await querySymbol(ledger);
        let decimals = await queryDecimals(ledger);
        let fee = await queryFee(ledger);
        let logo = await queryLogo(ledger);
        
        let tokenInfo : Types.TokenInfo = {
          ledger = ledger;
          symbol = symbol;
          decimals = decimals;
          fee = fee;
          logo = logo;
          supportsBlockQuery = supportsBlockQuery;
        };
        
        tokens.put(ledger, tokenInfo);
        #ok(tokenInfo)
      } catch (e) {
        #err("获取代币信息失败: " # Error.message(e))
      }
    };
    
    // 检查代币是否支持区块查询
    private func checkSupportsBlockQuery(ledger: Text) : async Bool {
      try {
        // 首先检查是否支持get_blocks方法
        let getBlocksActor = actor(ledger) : actor {
          get_blocks : {start: Nat; length: Nat} -> async {
            certificate: ?Blob;
            first_index: Nat;
            blocks: [Any];
            chain_length: Nat64;
            archived_blocks: [{callback: Any; start: Nat; length: Nat}];
          };
        };
        
        Debug.print("尝试调用 get_blocks 方法...");
        // 只要能调用成功就表示支持该方法
        let _ = await getBlocksActor.get_blocks({start = 1; length = 1});
        Debug.print("该代币支持get_blocks查询");
        return true;
      } catch (e) {
        // 如果get_blocks抛出错误，尝试检查是否支持ICP的query_blocks方法
        Debug.print("get_blocks 调用失败: " # Error.message(e));
        try {
          let icpActor = actor(ledger) : actor {
            query_blocks : {start: Nat64; length: Nat64} -> async {
              blocks: [Any];
              chain_length: Nat64;
              first_block_index: Nat64;
              archived_blocks: [{start: Nat64; length: Nat64; callback: Any}];
            };
          };
          
          Debug.print("尝试调用 query_blocks 方法...");
          // 只要能调用成功就表示支持该方法
          let _ = await icpActor.query_blocks({start = 1 : Nat64; length = 1 : Nat64});
          Debug.print("该代币支持query_blocks查询");
          return true;
        } catch (e) {
          Debug.print("该代币不支持区块查询: " # Error.message(e));
          return false;
        };
      }
    };
    
    // 从主网查询代币符号
    private func querySymbol(ledger: Text) : async Text {
      try {
        let ledgerActor = actor(ledger) : actor {
          icrc1_symbol : () -> async Text;
        };
        await ledgerActor.icrc1_symbol()
      } catch (e) {
        Debug.print("查询代币符号失败: " # Error.message(e));
        "UNKNOWN"
      }
    };
    
    // 从主网查询代币小数位
    private func queryDecimals(ledger: Text) : async Nat8 {
      try {
        let ledgerActor = actor(ledger) : actor {
          icrc1_decimals : () -> async Nat8;
        };
        await ledgerActor.icrc1_decimals()
      } catch (e) {
        Debug.print("查询代币小数位失败: " # Error.message(e));
        8 // 默认值
      }
    };
    
    // 从主网查询代币网络费用
    private func queryFee(ledger: Text) : async Nat {
      try {
        let ledgerActor = actor(ledger) : actor {
          icrc1_fee : () -> async Nat;
        };
        await ledgerActor.icrc1_fee()
      } catch (e) {
        Debug.print("查询代币网络费用失败: " # Error.message(e));
        10000 // 默认值
      }
    };
    
    // 从主网查询代币logo
    private func queryLogo(ledger: Text) : async ?Text {
      try {
        // 尝试使用元数据接口（需检查代币是否支持）
        let ledgerActor = actor(ledger) : actor {
          get_logo : () -> async ?Text;
        };
        await ledgerActor.get_logo()
      } catch (e) {
        Debug.print("查询代币logo失败: " # Error.message(e));
        null
      }
    };
    
    // 获取代币信息
    public func getToken(ledger: Text) : ?Types.TokenInfo {
      tokens.get(ledger)
    };
    
    // 获取所有代币
    public func getAllTokens() : [Types.TokenInfo] {
      Iter.toArray(Iter.map(tokens.vals(), func (t: Types.TokenInfo) : Types.TokenInfo { t }))
    };
    
    // 计算最小下注金额
    public func calculateMinimumBet(tokenInfo: Types.TokenInfo) : Nat {
      let base : Nat = 10;
      let power : Nat = Nat8.toNat(tokenInfo.decimals) - 4;
      let minBet : Nat = Nat.pow(base, power);
      
      if (minBet < tokenInfo.fee * 2) {
        return tokenInfo.fee * 2; // 最小下注至少是费用的两倍
      };
      
      minBet
    };
    
    // 验证下注金额是否合法
    public func validateBetAmount(tokenInfo: Types.TokenInfo, amount: Nat) : Bool {
      let minBet = calculateMinimumBet(tokenInfo);
      amount >= minBet
    };
    
    // 转账函数（实现ICRC-1标准）
    public func transferToken(ledger: Text, to: Text, amount: Nat) : async Types.TransferResult {
      // 获取代币信息
      switch (tokens.get(ledger)) {
        case (null) {
          return #err("代币不存在");
        };
        case (?token) {
          // 创建ICRC-1转账参数
          let toPrincipal = Principal.fromText(to);
          let args : Types.ICRC1TransferArgs = {
            from_subaccount = null;  // 合约没有子账户
            to = {
              owner = toPrincipal;
              subaccount = null;
            };
            amount = amount;
            fee = ?token.fee;        // 使用代币的标准手续费
            memo = null;             // 可选：添加转账用途备注
            created_at_time = null;  // 不设置时间戳，避免"交易太旧"的问题
          };
          
          // 调用ICRC-1代币合约的transfer方法
          try {
            let ledgerActor = actor(ledger) : actor {
              icrc1_transfer : (Types.ICRC1TransferArgs) -> async Types.ICRC1TransferResult;
            };
            
            let result = await ledgerActor.icrc1_transfer(args);
            
            switch (result) {
              case (#Ok(blockIndex)) {
                #ok(blockIndex)
              };
              case (#Err(error)) {
                #err(switch (error) {
                  case (#BadFee(e)) { "手续费错误，预期: " # Nat.toText(e.expected_fee) };
                  case (#BadBurn(e)) { "销毁金额错误，最小: " # Nat.toText(e.min_burn_amount) };
                  case (#InsufficientFunds(e)) { "余额不足，当前: " # Nat.toText(e.balance) };
                  case (#TooOld) { "交易太旧" };
                  case (#CreatedInFuture(e)) { "未来时间: " # Nat64.toText(e.ledger_time) };
                  case (#Duplicate(e)) { "重复交易: " # Nat.toText(e.duplicate_of) };
                  case (#TemporarilyUnavailable) { "暂时不可用" };
                  case (#GenericError(e)) { "错误: " # e.message };
                })
              };
            };
          } catch (e) {
            #err("调用代币合约失败: " # Error.message(e))
          };
        };
      }
    };

    // 查询代币余额
    public func getBalance(ledger: Text, account: Text) : async Result.Result<Nat, Text> {
      try {
        let principal = Principal.fromText(account);
        
        let ledgerActor = actor(ledger) : actor {
          icrc1_balance_of : (Types.Account) -> async Nat;
        };
        
        let balance = await ledgerActor.icrc1_balance_of({
          owner = principal;
          subaccount = null;
        });
        
        #ok(balance)
      } catch (e) {
        #err("查询余额失败: " # Error.message(e))
      }
    };

    // 查询所有代币符号
    public func getAllTokenSymbols() : async [Text] {
      Iter.toArray(Iter.map(tokens.vals(), func (t: Types.TokenInfo) : Text { t.symbol }))
    };
  };
} 