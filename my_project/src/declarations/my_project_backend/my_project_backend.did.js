export const idlFactory = ({ IDL }) => {
  const TokenInfo = IDL.Record({
    'fee' : IDL.Nat,
    'decimals' : IDL.Nat8,
    'logo' : IDL.Opt(IDL.Text),
    'ledger' : IDL.Text,
    'symbol' : IDL.Text,
  });
  const Result_2 = IDL.Variant({ 'ok' : TokenInfo, 'err' : IDL.Text });
  const Result_1 = IDL.Variant({ 'ok' : IDL.Text, 'err' : IDL.Text });
  const Time = IDL.Int;
  const PoolStatus = IDL.Variant({
    'Active' : IDL.Null,
    'Completed' : IDL.Null,
    'Canceled' : IDL.Null,
  });
  const Bet = IDL.Record({
    'user' : IDL.Text,
    'timestamp' : Time,
    'amount' : IDL.Nat,
  });
  const Pool = IDL.Record({
    'id' : IDL.Text,
    'lastBetTime' : IDL.Opt(Time),
    'status' : PoolStatus,
    'creator' : IDL.Text,
    'token' : TokenInfo,
    'betAmount' : IDL.Nat,
    'bets' : IDL.Vec(Bet),
    'createdAt' : Time,
    'totalAmount' : IDL.Nat,
    'initialAmount' : IDL.Nat,
    'winnerCount' : IDL.Nat,
  });
  const Message = IDL.Record({
    'content' : IDL.Text,
    'sender' : IDL.Text,
    'timestamp' : Time,
  });
  const Result = IDL.Variant({ 'ok' : IDL.Null, 'err' : IDL.Text });
  const TransferResult = IDL.Variant({ 'ok' : IDL.Nat, 'err' : IDL.Text });
  return IDL.Service({
    'addToken' : IDL.Func([IDL.Text], [Result_2], []),
    'createPool' : IDL.Func(
        [IDL.Text, IDL.Nat, IDL.Nat, IDL.Nat],
        [Result_1],
        [],
      ),
    'getActivePools' : IDL.Func([], [IDL.Vec(Pool)], ['query']),
    'getAllTokenSymbols' : IDL.Func([], [IDL.Vec(IDL.Text)], ['query']),
    'getAllTokens' : IDL.Func([], [IDL.Vec(TokenInfo)], ['query']),
    'getCountdown' : IDL.Func([IDL.Text], [IDL.Opt(IDL.Int)], ['query']),
    'getLatestMessages' : IDL.Func([IDL.Nat], [IDL.Vec(Message)], ['query']),
    'getMinimumBet' : IDL.Func([IDL.Text], [IDL.Opt(IDL.Nat)], ['query']),
    'getPool' : IDL.Func([IDL.Text], [IDL.Opt(Pool)], ['query']),
    'getSystemInfo' : IDL.Func([], [IDL.Text], ['query']),
    'getToken' : IDL.Func([IDL.Text], [IDL.Opt(TokenInfo)], ['query']),
    'hasNewMessages' : IDL.Func([], [IDL.Bool], ['query']),
    'healthCheck' : IDL.Func([], [IDL.Bool], ['query']),
    'placeBet' : IDL.Func([IDL.Text], [Result], []),
    'sendMessage' : IDL.Func([IDL.Text], [], []),
    'settlePool' : IDL.Func([IDL.Text], [Result], []),
    'transferToken' : IDL.Func(
        [IDL.Text, IDL.Text, IDL.Nat],
        [TransferResult],
        [],
      ),
    'updateLastMessageCheck' : IDL.Func([], [], []),
  });
};
export const init = ({ IDL }) => { return []; };
