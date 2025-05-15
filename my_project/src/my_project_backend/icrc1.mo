import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Error "mo:base/Error";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Int "mo:base/Int";

module {
  // 定义 ICRC-1 索引 canister 的接口类型
  type BlockData = {
    #Map : [(Text, BlockData)];
    #Int : Int;
    #Nat : Nat;
    #Nat64 : Nat64;
    #Blob : Blob;
    #Text : Text;
    #Array : [BlockData];
  };

  type BlocksResponse = {
    blocks : [BlockData];
    chain_length : Nat64;
  };
  
  type ICRC1Index = actor {
    get_blocks : shared query ({ start : Nat; length : Nat }) -> async BlocksResponse;
  };
  
  // 验证 ICRC-1 代币交易的函数
  public func verifyICRC1Transaction(canisterId: Text, blockIndex: Nat) : async Text {
    try {
      // 使用传入的 canister ID 创建 actor 引用
      let icrc1Index : ICRC1Index = actor(canisterId);
      
      // 查询指定区块的信息
      let response = await icrc1Index.get_blocks({
        start = blockIndex;
        length = 1;
      });
      
      // 检查是否找到了区块
      if (response.blocks.size() == 0) {
        return "交易验证失败：未找到区块 " # Nat.toText(blockIndex);
      };
      
      let block = response.blocks[0];
      
      // 解析区块信息
      switch (block) {
        case (#Map(fields)) {
          // 初始化变量
          var txType = "未知";
          var timestamp : Nat64 = 0;
          var fromPrincipal = "未知";
          var toPrincipal = "未知";
          var amount : Nat64 = 0;
          var fee : Nat64 = 0;
          var memo = "无备注";
          
          // 首先提取时间戳，它在顶层
          for ((key, value) in fields.vals()) {
            if (key == "ts") {
              switch (value) {
                case (#Nat64(ts)) { timestamp := ts; };
                case (_) {};
              };
            } else if (key == "tx") {
              // 交易数据在tx字段中
              switch (value) {
                case (#Map(txFields)) {
                  for ((txKey, txValue) in txFields.vals()) {
                    if (txKey == "op") {
                      switch (txValue) {
                        case (#Text(op)) { txType := op; };
                        case (_) {};
                      };
                    } else if (txKey == "from") {
                      switch (txValue) {
                        case (#Array(fromArray)) {
                          if (fromArray.size() > 0) {
                            switch (fromArray[0]) {
                              case (#Blob(principalBlob)) {
                                fromPrincipal := blobToHex(principalBlob);
                              };
                              case (_) {};
                            };
                          };
                        };
                        case (_) {};
                      };
                    } else if (txKey == "to") {
                      switch (txValue) {
                        case (#Array(toArray)) {
                          if (toArray.size() > 0) {
                            switch (toArray[0]) {
                              case (#Blob(principalBlob)) {
                                toPrincipal := blobToHex(principalBlob);
                              };
                              case (_) {};
                            };
                          };
                        };
                        case (_) {};
                      };
                    } else if (txKey == "amt") {
                      switch (txValue) {
                        case (#Nat64(amt)) { amount := amt; };
                        case (_) {};
                      };
                    } else if (txKey == "fee") {
                      switch (txValue) {
                        case (#Nat64(f)) { fee := f; };
                        case (_) {};
                      };
                    } else if (txKey == "memo") {
                      switch (txValue) {
                        case (#Blob(memoBlob)) { memo := blobToHex(memoBlob); };
                        case (_) {};
                      };
                    };
                  };
                };
                case (_) {};
              };
            };
          };
          
          // 构建返回结果
          var result = "ICRC-1 交易验证成功：\n" # 
                      "区块高度: " # Nat.toText(blockIndex) # "\n" #
                      "交易类型: " # txType # "\n";
          
          // 无论交易类型如何，都显示所有解析的数据
          result #= "发送方: " # fromPrincipal # "\n";
          result #= "接收方: " # toPrincipal # "\n";
          result #= "金额: " # Nat64.toText(amount) # " (代币单位)\n";
          result #= "手续费: " # Nat64.toText(fee) # "\n";
          result #= "备注: " # (if (memo == "") "无备注" else memo) # "\n" #
                    "时间戳: " # Nat64.toText(timestamp);
          
          return result;
        };
        case (_) {
          return "交易验证失败：区块格式不正确";
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
      
      // 转换十六进制字符串为字符数组
      let hexChars = Text.toArray(hex);
      
      // 通过索引从数组访问字符
      result #= Text.fromChar(hexChars[highNibble]) # 
                Text.fromChar(hexChars[lowNibble]);
    };
    
    return result;
  };
}
/*解析结果
("ICRC-1 交易验证成功：
区块高度: 2468958
交易类型: xfer
发送方: 0000000001708fc00101
接收方: 0000000000d018830101
金额: 488 (代币单位)
手续费: 10
备注: 0000000000002e2f
时间戳: 1746771366016204529")
*/