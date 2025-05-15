# PlayerX 后端 API 文档

## 概述
本文档描述了 PlayerX 游戏平台的后端 API 接口，包括代币管理、池子管理、消息系统和转账功能。

## 基础信息
- 后端地址：`https://dvnx6-cqaaa-aaaao-qkalq-cai.ic0.app`
- 所有接口都需要用户认证（使用 Internet Computer 的身份认证）

## 代币管理接口

### 1. 添加代币
```typescript
async function addToken(ledger: string): Promise<Result<TokenInfo, string>>
```
- 参数：
  - `ledger`: 代币的账本地址
- 返回：成功返回代币信息，失败返回错误信息

### 2. 获取代币信息
```typescript
async function getToken(ledger: string): Promise<TokenInfo | null>
```
- 参数：
  - `ledger`: 代币的账本地址
- 返回：代币信息或 null

### 3. 获取所有代币
```typescript
async function getAllTokens(): Promise<TokenInfo[]>
```
- 返回：所有代币信息的数组

### 4. 获取所有代币符号
```typescript
async function getAllTokenSymbols(): Promise<string[]>
```
- 返回：所有代币符号的数组

### 5. 获取代币最小下注金额
```typescript
async function getMinimumBet(ledger: string): Promise<number | null>
```
- 参数：
  - `ledger`: 代币的账本地址
- 返回：最小下注金额或 null

## 池子管理接口

### 1. 创建池子
```typescript
async function createPool(
  tokenSymbol: string,
  winnerCount: number,
  betAmount: number,
  initialAmount: number
): Promise<Result<string, string>>
```
- 参数：
  - `tokenSymbol`: 代币符号
  - `winnerCount`: 获胜者数量
  - `betAmount`: 下注金额
  - `initialAmount`: 初始资金
- 返回：成功返回池子ID，失败返回错误信息
- 注意：池子创建后初始为 Pending 状态，需要验证初始资金后才会激活

### 2. 验证初始资金并激活池子
```typescript
async function verifyInitialFundAndActivatePool(poolId: string): Promise<Result<void, string>>
```
- 参数：
  - `poolId`: 池子ID
- 返回：成功或失败信息
- 说明：
  - 只有池子创建者可以调用此接口
  - 调用前需先转账初始资金到合约地址，并在备注中包含 `create:poolId`
  - 只有成功激活后的池子才能接受下注

### 3. 获取池子信息
```typescript
async function getPool(poolId: string): Promise<Pool | null>
```
- 参数：
  - `poolId`: 池子ID
- 返回：池子信息或 null

### 4. 获取活跃池子
```typescript
async function getActivePools(): Promise<Pool[]>
```
- 返回：所有活跃池子的数组
- 注意：只返回状态为 Active 的池子，不包括 Pending 状态的池子

### 5. 下注
```typescript
async function placeBet(poolId: string): Promise<Result<void, string>>
```
- 参数：
  - `poolId`: 池子ID
- 返回：成功或失败信息
- 说明：
  - 只能对 Active 状态的池子下注
  - 调用前需先转账下注金额到合约地址，并在备注中包含 `bet:poolId`

### 6. 获取倒计时
```typescript
async function getCountdown(poolId: string): Promise<number | null>
```
- 参数：
  - `poolId`: 池子ID
- 返回：剩余时间（纳秒）或 null
- 说明：只有 Active 状态的池子才有倒计时

### 7. 手动结算池子
```typescript
async function settlePool(poolId: string): Promise<Result<void, string>>
```
- 参数：
  - `poolId`: 池子ID
- 返回：成功或失败信息
- 说明：只有满足结算条件（60秒无人下注）的池子可以手动结算

## 消息系统接口

### 1. 发送消息
```typescript
async function sendMessage(content: string): Promise<void>
```
- 参数：
  - `content`: 消息内容

### 2. 获取最新消息
```typescript
async function getLatestMessages(count: number): Promise<Message[]>
```
- 参数：
  - `count`: 获取消息数量
- 返回：消息数组

### 3. 检查新消息
```typescript
async function hasNewMessages(): Promise<boolean>
```
- 返回：是否有新消息

### 4. 更新最后查询时间
```typescript
async function updateLastMessageCheck(): Promise<void>
```

## 转账接口

### 1. 转账
```typescript
async function transferToken(
  ledger: string,
  to: string,
  amount: number
): Promise<TransferResult>
```
- 参数：
  - `ledger`: 代币账本地址
  - `to`: 接收地址
  - `amount`: 转账金额
- 返回：转账结果

## 系统信息接口

### 1. 健康检查
```typescript
async function healthCheck(): Promise<boolean>
```
- 返回：系统是否健康

### 2. 获取系统信息
```typescript
async function getSystemInfo(): Promise<string>
```
- 返回：系统信息字符串

### 3. 获取系统周期信息
```typescript
async function getSystemCycleInfo(): Promise<{
  activePools: number;
  pendingPools: number;
  completedPools: number;
  totalBets: number;
  currentTime: number;
  avgBetAmount: number | null;
  tokenCount: number;
}>
```
- 返回：系统周期详细信息
  - `activePools`: 活跃池子数量
  - `pendingPools`: 待激活池子数量
  - `completedPools`: 已完成池子数量
  - `totalBets`: 总下注次数
  - `currentTime`: 当前系统时间
  - `avgBetAmount`: 平均下注金额（如果有下注）
  - `tokenCount`: 已注册代币数量

## 数据类型定义

### TokenInfo
```typescript
interface TokenInfo {
  ledger: string;
  symbol: string;
  decimals: number;
  fee: number;
  logo: string | null;
}
```

### Pool
```typescript
interface Pool {
  id: string;
  creator: string;
  token: TokenInfo;
  winnerCount: number;
  betAmount: number;
  initialAmount: number;
  totalAmount: number;
  status: 'Pending' | 'Active' | 'Completed' | 'Canceled';
  createdAt: number;
  lastBetTime: number | null;
  bets: Bet[];
}
```

### Bet
```typescript
interface Bet {
  user: string;
  amount: number;
  timestamp: number;
}
```

### Message
```typescript
interface Message {
  sender: string;
  content: string;
  timestamp: number;
}
```

### TransferResult
```typescript
type TransferResult = {
  ok: number; // 区块索引
} | {
  err: string; // 错误信息
}
```

## 注意事项
1. 所有接口都需要用户认证
2. 转账操作需要包含正确的备注信息：
   - 创建池子：`create:poolId`
   - 下注：`bet:poolId`
3. 池子超时时间为60秒
4. 转账金额必须精确匹配要求金额
5. 每个转账只能使用一次
6. 池子生命周期：
   - Pending（待激活）：创建后等待初始资金验证
   - Active（活跃）：初始资金已验证，可以接受下注
   - Completed（已完成）：已结算并分配奖金
   - Canceled（已取消）：无人下注，已退还初始资金
7. 只有 Active 状态的池子才会开始倒计时，每次下注会重置60秒倒计时
8. 奖金分配：98%分给获奖者，1%给创建者，1%给开发者 