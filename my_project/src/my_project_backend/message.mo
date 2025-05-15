import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Types "./types";

module {
  public class MessageManager() {
    // 仅保存最新的消息
    private var messages = Buffer.Buffer<Types.Message>(50);
    private let MAX_MESSAGES = 50; // 最多保存50条消息
    
    // 发送新消息
    public func sendMessage(sender: Text, content: Text) : () {
      let message : Types.Message = {
        sender = sender;
        content = content;
        timestamp = Time.now();
      };
      
      // 添加到消息缓冲区
      if (messages.size() >= MAX_MESSAGES) {
        // 移除最早的消息
        ignore messages.remove(0);
      };
      
      messages.add(message);
    };
    
    // 获取最新的N条消息
    public func getLatestMessages(count: Nat) : [Types.Message] {
      let size = messages.size();
      let startIndex = if (count > size) { 0 } else { Nat.sub(size, count) };
      
      let result = Buffer.Buffer<Types.Message>(count);
      var i = startIndex;
      while (i < size) {
        result.add(messages.get(i));
        i += 1;
      };
      
      Buffer.toArray(result)
    };
    
    // 检查是否有新消息（基于时间戳）
    public func hasNewMessages(since: Time.Time) : Bool {
      if (messages.size() == 0) {
        return false;
      };
      
      let latestMessage = messages.get(messages.size() - 1);
      return latestMessage.timestamp > since;
    };
  };
} 