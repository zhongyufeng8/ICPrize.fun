import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Error "mo:base/Error";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";

module {
  // 定义 ICP Ledger canister 接口
  type Operation = {
    #Transfer : {
      from : Blob;
      to : Blob;
      amount : { e8s : Nat64 };
      fee : { e8s : Nat64 };
    };
    // 可能还有其他操作类型
  };
  
  type Transaction = {
    memo : Nat64;
    icrc1_memo : ?Blob;
    operation : ?Operation;
    created_at_time : { timestamp_nanos : Nat64 };
  };
  
  type Block = {
    transaction : Transaction;
    timestamp : { timestamp_nanos : Nat64 };
    parent_hash : ?Blob;
  };
  
  type QueryBlocksResponse = {
    certificate : ?Blob;
    blocks : [Block];
    chain_length : Nat64;
    first_block_index : Nat64;
    archived_blocks : [{
      start : Nat64;
      length : Nat64;
      callback : shared query { start : Nat64; length : Nat64 } -> async {
        certificate : ?Blob;
        blocks : [Block];
        chain_length : Nat64;
        first_block_index : Nat64;
        archived_blocks : [{ start : Nat64; length : Nat64; callback : Any }];
      };
    }];
  };
  
  type Any = actor {};
  
  // 定义 ledger canister 的接口类型
  type Ledger = actor {
    query_blocks : shared query ({ start : Nat64; length : Nat64 }) -> async QueryBlocksResponse;
  };

  // 使用类型注解创建 actor 引用
  let ledger : Ledger = actor("ryjl3-tyaaa-aaaaa-aaaba-cai");
  
  // 验证ICP交易记录的函数
  public func verifyTransaction(blockIndex: Nat64) : async Text {
    try {
      // 查询区块信息，只查询一个区块
      let response = await ledger.query_blocks({
        start = blockIndex;
        length = 1;
      });
      
      // 检查是否找到了区块
      if (response.blocks.size() == 0) {
        return "交易验证失败：未找到区块 " # Nat64.toText(blockIndex);
      };
      
      let block = response.blocks[0];
      let transaction = block.transaction;
      
      // 解析交易信息
      switch (transaction.operation) {
        case (null) {
          return "交易验证失败：区块 " # Nat64.toText(blockIndex) # " 不包含操作信息";
        };
        case (?op) {
          switch (op) {
            case (#Transfer(transfer)) {
              // 将 Blob 转换为十六进制字符串以便显示
              let fromHex = blobToHex(transfer.from);
              let toHex = blobToHex(transfer.to);
              
              return "交易验证成功：\n" # 
                    "区块高度: " # Nat64.toText(blockIndex) # "\n" #
                    "发送方: " # fromHex # "\n" #
                    "接收方: " # toHex # "\n" #
                    "金额: " # Nat64.toText(transfer.amount.e8s) # " e8s (" # 
                    Nat64.toText(transfer.amount.e8s / 100000000) # "." # 
                    Nat64.toText(transfer.amount.e8s % 100000000) # " ICP)\n" #
                    "手续费: " # Nat64.toText(transfer.fee.e8s) # " e8s\n" #
                    "备注: " # Nat64.toText(transaction.memo) # "\n" #
                    "交易时间: " # Nat64.toText(block.timestamp.timestamp_nanos) # " 纳秒";
            };
          };
        };
      };
    } catch (e) {
      return "验证过程中发生错误：" # Error.message(e);
    };
  };
  
  // 辅助函数：将 Blob 转换为十六进制字符串
func blobToHex(b: Blob) : Text {
    let bytes = Blob.toArray(b);
    let hex = "0123456789abcdef";
    var result = "";
    
    for (byte in bytes.vals()) {
        let highNibble = Nat8.toNat(byte / 16);
        let lowNibble = Nat8.toNat(byte % 16);
        
        // Convert hex string to an array of characters
        let hexChars = Text.toArray(hex);
        
        // Access characters by index from the array
        result #= Text.fromChar(hexChars[highNibble]) # 
                  Text.fromChar(hexChars[lowNibble]);
    };
    
    return result;
};
}